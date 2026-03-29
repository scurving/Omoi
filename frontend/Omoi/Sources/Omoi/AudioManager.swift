
import Foundation
import AVFoundation
import Combine

enum PlaybackState: Equatable {
    case idle
    case playing(sessionID: UUID)
    case paused(sessionID: UUID)

    var isPlaying: Bool {
        if case .playing = self { return true }
        return false
    }

    var currentSessionID: UUID? {
        switch self {
        case .idle: return nil
        case .playing(let id), .paused(let id): return id
        }
    }
}

class AudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AudioManager()

    private var audioEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayer?
    private var audioFile: AVAudioFile?
    private var playbackTimer: Timer?

    @Published var playbackState: PlaybackState = .idle
    @Published var playbackProgress: Double = 0  // 0.0 to 1.0

    override init() {
        super.init()
        // No audio session setup needed on macOS
    }

    // MARK: - Recording

    func startRecording(completion: @escaping (Error?) -> Void) {
        // On macOS, permission is handled via Info.plist and system prompts automatically
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFileURL = documentsPath.appendingPathComponent("recording.wav")

        do {
            audioFile = try AVAudioFile(forWriting: audioFileURL, settings: recordingFormat.settings)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, _) in
                do {
                    try self?.audioFile?.write(from: buffer)
                } catch {
                    print("Error writing audio buffer: \(error.localizedDescription)")
                }
            }

            try audioEngine.start()
            completion(nil)
        } catch {
            completion(error)
        }
    }

    func stopRecording(completion: (Result<URL, Error>) -> Void) {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil

        if let url = audioFile?.url {
            audioFile = nil // Close the file
            completion(.success(url))
        } else {
            let error = NSError(domain: "AudioManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Audio file URL not found"])
            completion(.failure(error))
        }
    }

    // MARK: - TTS Playback (existing)

    func playAudio(data: Data) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.play()
        } catch {
            print("Failed to play audio: \(error.localizedDescription)")
        }
    }

    // MARK: - Recording Playback

    /// Play a saved recording by filename
    func playRecording(fileName: String, sessionID: UUID) {
        // Stop any current playback first
        stopPlayback()

        let url = StorageManager.shared.recordingURL(for: fileName)

        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ Recording file not found: \(fileName)")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            playbackState = .playing(sessionID: sessionID)
            startPlaybackTimer()
            print("▶️ Playing recording: \(fileName)")
        } catch {
            print("❌ Playback failed: \(error.localizedDescription)")
            playbackState = .idle
        }
    }

    /// Pause current playback
    func pausePlayback() {
        guard case .playing(let sessionID) = playbackState else { return }
        audioPlayer?.pause()
        playbackState = .paused(sessionID: sessionID)
        stopPlaybackTimer()
        print("⏸️ Playback paused")
    }

    /// Resume paused playback
    func resumePlayback() {
        guard case .paused(let sessionID) = playbackState else { return }
        audioPlayer?.play()
        playbackState = .playing(sessionID: sessionID)
        startPlaybackTimer()
        print("▶️ Playback resumed")
    }

    /// Stop playback completely
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        playbackState = .idle
        playbackProgress = 0
        stopPlaybackTimer()
    }

    /// Toggle play/pause for a session
    func togglePlayback(fileName: String, sessionID: UUID) {
        switch playbackState {
        case .idle:
            playRecording(fileName: fileName, sessionID: sessionID)
        case .playing(let currentID):
            if currentID == sessionID {
                pausePlayback()
            } else {
                // Playing different session, switch to this one
                playRecording(fileName: fileName, sessionID: sessionID)
            }
        case .paused(let currentID):
            if currentID == sessionID {
                resumePlayback()
            } else {
                // Paused on different session, switch to this one
                playRecording(fileName: fileName, sessionID: sessionID)
            }
        }
    }

    /// Seek to a position (0.0 to 1.0)
    func seek(to progress: Double) {
        guard let player = audioPlayer else { return }
        let clampedProgress = max(0, min(1, progress))
        player.currentTime = player.duration * clampedProgress
        playbackProgress = clampedProgress
    }

    // MARK: - Playback Timer

    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let player = self.audioPlayer, player.duration > 0 else { return }
            DispatchQueue.main.async {
                self.playbackProgress = player.currentTime / player.duration
            }
        }
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.stopPlayback()
            print("⏹️ Playback finished")
        }
    }
}
