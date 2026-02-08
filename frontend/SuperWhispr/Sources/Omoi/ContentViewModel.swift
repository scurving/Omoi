
import SwiftUI
import AVFoundation
import Combine

@MainActor
class ContentViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var errorMessage: String?
    @Published var autoPasteEnabled = true
    @Published var transcriptionState: TranscriptionState = .idle
    @Published var accessibilityPermissionState: PermissionState = .unknown
    @Published var showAccessibilityAlert = false
    @Published var showPermissionInstructionSheet = false

    // MARK: - Settings
    @AppStorage("saveRecordingsForPlayback") var saveRecordingsForPlayback = true

    // MARK: - Private Properties
    private let audioManager = AudioManager()
    private let apiService = APIService()
    private let pasteManager = PasteManager.shared
    private let statsManager = StatsManager.shared
    private let sanitizationManager = SanitizationManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var shortcutObserver: Any?
    private var permissionCheckObserver: Any?
    private var recordingStartTime: Date?
    private var lastRecordingURL: URL?

    // MARK: - Public Access
    var stats: StatsManager {
        return statsManager
    }

    // MARK: - Public Methods
    func manualToggleRecording() {
        print("🎤 Manual toggle recording button pressed")
        print("   Current state: \(isRecording ? "Recording" : "Idle")")
        toggleRecording()
        print("   New state: \(isRecording ? "Recording" : "Idle")")
    }

    // MARK: - Setup
    func setupShortcutObserver() {
        // Avoid adding multiple observers
        if shortcutObserver == nil {
            shortcutObserver = NotificationCenter.default.addObserver(forName: .toggleRecord, object: nil, queue: .main) { [weak self] _ in
                self?.toggleRecording()
            }
        }
    }

    func setupPermissionObservers() {
        // Check initial permission state
        updatePermissionState()

        // Listen for paste permission denial notifications
        if permissionCheckObserver == nil {
            permissionCheckObserver = NotificationCenter.default.addObserver(forName: .pastePermissionDenied, object: nil, queue: .main) { [weak self] notification in
                let reason = notification.userInfo?["reason"] as? String ?? "unknown"

                if reason == "accessibility_denied" {
                    self?.accessibilityPermissionState = .denied
                    self?.showAccessibilityAlert = true
                    self?.transcriptionState = .failed("Accessibility permission not granted")
                    print("🔐 Accessibility permission denied, showing alert")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self?.transcriptionState = .idle
                    }
                }
            }
        }

        // Listen for paste success notifications
        NotificationCenter.default.addObserver(
            forName: .pasteSuccess,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.transcriptionState = .completed
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self?.transcriptionState = .idle
            }
        }
    }

    private func updatePermissionState() {
        let hasPermission = AccessibilityPermissions.hasAccessibilityPermission()

        // Development mode workaround: If running from .app bundle directly (not installed)
        // and permissions keep getting revoked, assume granted to avoid constant nagging
        let isDevelopmentBuild = !FileManager.default.fileExists(atPath: "/Applications/Omoi.app")

        if isDevelopmentBuild && !hasPermission {
            print("🔐 Permission state: denied (development build - ad-hoc signature issue)")
            print("   ⚠️ Auto-paste will be disabled. Toggle is available but may require re-enabling after rebuilds.")
        } else {
            print("🔐 Permission state updated: \(hasPermission ? "granted" : "denied")")
        }

        accessibilityPermissionState = hasPermission ? .granted : .denied
    }

    deinit {
        if let observer = shortcutObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = permissionCheckObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Core Logic
    private func toggleRecording() {
        isRecording.toggle()
        if isRecording {
            startRecording()
        } else {
            stopRecording()
        }
    }

    private func startRecording() {
        print("▶️  Starting recording...")
        errorMessage = nil
        recordingStartTime = Date()
        transcriptionState = .recording

        // Capture the active app before we potentially take focus
        pasteManager.captureCurrentApp()
        print("   Captured app: \(pasteManager.getLastAppName())")

        audioManager.startRecording { [weak self] error in
            if let error = error {
                print("❌ Recording failed: \(error.localizedDescription)")
                self?.errorMessage = "Failed to start recording: \(error.localizedDescription)"
                self?.isRecording = false
                self?.recordingStartTime = nil
                self?.transcriptionState = .idle
            } else {
                print("✅ Audio recording started successfully")
            }
        }
    }

    private func stopRecording() {
        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        print("⏹️  Stopping recording...")
        print("   Duration: \(String(format: "%.2f", duration))s")
        recordingStartTime = nil
        transcriptionState = .processing

        audioManager.stopRecording { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let audioURL):
                print("✅ Audio file saved: \(audioURL.path)")
                print("   Sending to transcription API...")
                self.lastRecordingURL = audioURL
                self.transcribeAudio(url: audioURL, duration: duration)
            case .failure(let error):
                print("❌ Recording failed: \(error.localizedDescription)")
                self.errorMessage = "Recording failed: \(error.localizedDescription)"
                self.transcriptionState = .failed(error.localizedDescription)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.transcriptionState = .idle
                }
            }
        }
    }

    // MARK: - API Communication
    private func transcribeAudio(url: URL, duration: TimeInterval) {
        print("🌐 Transcribing audio...")
        apiService.transcribeAudio(fileURL: url)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    print("❌ Transcription failed: \(error.localizedDescription)")
                    self?.errorMessage = "Transcription failed: \(error.localizedDescription)"
                    self?.transcriptionState = .failed(error.localizedDescription)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self?.transcriptionState = .idle
                    }
                }
            }, receiveValue: { [weak self] transcriptionResponse in
                guard let self = self else { return }
                print("✅ Transcription received: \(transcriptionResponse.transcription)")
                print("   Word count: \(transcriptionResponse.transcription.components(separatedBy: .whitespaces).count)")

                self.transcribedText = transcriptionResponse.transcription

                // Save to history
                let metadata = TranscriptionSession.Metadata(
                    windowTitle: self.pasteManager.getFrontmostWindowTitle(),
                    model: "whisper-base",
                    processingTime: Date().timeIntervalSince(self.recordingStartTime ?? Date()), // Approximate
                    intent: nil
                )

                // Save recording if enabled
                let sessionID = UUID()
                var audioFileName: String? = nil
                if self.saveRecordingsForPlayback, let recordingURL = self.lastRecordingURL {
                    if let audioData = try? Data(contentsOf: recordingURL) {
                        audioFileName = StorageManager.shared.saveRecording(data: audioData, for: sessionID)
                    }
                }
                self.lastRecordingURL = nil

                let session = TranscriptionSession(
                    id: sessionID,
                    text: transcriptionResponse.transcription,
                    duration: duration,
                    speechDuration: transcriptionResponse.speech_duration,
                    targetAppBundleID: self.pasteManager.getLastAppBundleID(),
                    targetAppName: self.pasteManager.getLastAppName(),
                    metadata: metadata,
                    audioFileName: audioFileName
                )
                self.statsManager.addSession(session)
                print("📊 Session saved to history\(audioFileName != nil ? " (with audio)" : "")")

                // Auto-paste if enabled
                if self.autoPasteEnabled {
                    if self.sanitizationManager.rules.enabled &&
                       self.sanitizationManager.rules.autoSanitizeBeforePaste &&
                       !self.sanitizationManager.rules.instructions.isEmpty {
                        // Sanitize first, then paste
                        print("📋 Auto-sanitize enabled, sanitizing before paste...")
                        self.transcriptionState = .processing
                        Task {
                            do {
                                let sanitized = try await self.apiService.sanitizeText(
                                    text: transcriptionResponse.transcription,
                                    instructions: self.sanitizationManager.rules.instructions
                                )
                                await MainActor.run {
                                    print("📋 Sanitized, pasting to \(self.pasteManager.getLastAppName())")
                                    self.transcriptionState = .pasting
                                    self.pasteManager.paste(text: sanitized)
                                }
                            } catch {
                                print("❌ Auto-sanitization failed: \(error.localizedDescription), falling back to original")
                                await MainActor.run {
                                    self.transcriptionState = .pasting
                                    self.pasteManager.paste(text: transcriptionResponse.transcription)
                                }
                            }
                        }
                    } else {
                        print("📋 Auto-paste enabled, pasting to \(self.pasteManager.getLastAppName())")
                        self.transcriptionState = .pasting
                        self.pasteManager.paste(text: transcriptionResponse.transcription)
                    }
                } else {
                    print("📋 Auto-paste disabled, skipping paste")
                    self.transcriptionState = .completed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.transcriptionState = .idle
                    }
                }
            })
            .store(in: &cancellables)
    }

    func synthesizeText() {
        guard !transcribedText.isEmpty else { return }
        
        apiService.synthesizeText(text: transcribedText)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = "Synthesis failed: \(error.localizedDescription)"
                }
            }, receiveValue: { [weak self] data in
                self?.audioManager.playAudio(data: data)
            })
            .store(in: &cancellables)
    }

    // MARK: - Utility Functions
    func copyToClipboard() {
        if sanitizationManager.rules.enabled && !sanitizationManager.rules.instructions.isEmpty {
            // Fetch sanitized version
            Task {
                do {
                    let sanitized = try await apiService.sanitizeText(
                        text: transcribedText,
                        instructions: sanitizationManager.rules.instructions
                    )
                    await MainActor.run {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(sanitized, forType: .string)
                    }
                } catch {
                    print("❌ Sanitization failed: \(error.localizedDescription)")
                    // Fall back to original text
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(transcribedText, forType: .string)
                }
            }
        } else {
            // Copy original text
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(transcribedText, forType: .string)
        }
    }
}
