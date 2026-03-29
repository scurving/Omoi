
import SwiftUI
import KeyboardShortcuts

// MARK: - Omoi Main Content View

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: ContentViewModel
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab Selector - brutalist style
            HStack(spacing: 0) {
                tabButton("RECORD", icon: "mic.fill", tag: 0)
                tabButton("STATS", icon: "chart.bar.fill", tag: 1)
                tabButton("HISTORY", icon: "clock.fill", tag: 2)
                tabButton("RETRO", icon: "brain.head.profile", tag: 3)
                tabButton("PIPELINES", icon: "slider.horizontal.3", tag: 4)
            }
            .background(Color.omoiDarkGray)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(Color.omoiGray),
                alignment: .bottom
            )

            // Content based on selected tab
            Group {
                switch selectedTab {
                case 0:
                    RecordView(viewModel: viewModel)
                case 1:
                    DashboardView(statsManager: viewModel.stats)
                case 2:
                    HistoryView(statsManager: viewModel.stats)
                case 3:
                    RetroView(statsManager: viewModel.stats)
                case 4:
                    PipelinesView(statsManager: viewModel.stats)
                default:
                    RecordView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Footer - brutalist
            HStack {
                Text("v\(Bundle.main.appVersionString)")
                    .font(OmoiFont.mono(size: 10))
                    .foregroundStyle(Color.omoiMuted)

                BackendStatusIndicator()

                Spacer()

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text("QUIT")
                        .font(OmoiFont.label(size: 10))
                        .foregroundStyle(Color.omoiOrange)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.omoiDarkGray)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(Color.omoiGray),
                alignment: .top
            )
        }
        .omoiBackground()
        .frame(minWidth: 500, maxWidth: .infinity, minHeight: 630, maxHeight: .infinity)
        .onAppear {
            viewModel.setupShortcutObserver()
            viewModel.setupPermissionObservers()
        }
        .onChange(of: viewModel.transcriptionState) { newState in
            appState.transcriptionState = newState
            // Show HUD for non-idle states
            switch newState {
            case .processing, .completed, .failed:
                HUDController.shared.show(state: newState)
            default:
                break
            }
        }
        .alert("Auto-Paste Permission Required", isPresented: $viewModel.showAccessibilityAlert) {
            Button("Open Settings") {
                AccessibilityPermissions.openAccessibilitySettings()
                viewModel.showPermissionInstructionSheet = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Omoi needs Accessibility permission to paste transcriptions automatically. You'll be taken to System Settings where you can enable it.")
        }
        .sheet(isPresented: $viewModel.showPermissionInstructionSheet) {
            PermissionInstructionSheet(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private func tabButton(_ title: String, icon: String, tag: Int) -> some View {
        Button(action: { selectedTab = tag }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(OmoiFont.label(size: 9))
            }
            .foregroundStyle(selectedTab == tag ? Color.omoiTeal : Color.omoiMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            // Use near-invisible background for non-selected tabs to ensure full hit area
            // (Color.clear doesn't register clicks with .buttonStyle(.plain))
            .background(selectedTab == tag ? Color.omoiGray : Color.black.opacity(0.001))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Omoi Record View

struct RecordView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var audioLevel: CGFloat = 0.0
    @State private var recordingDuration: TimeInterval = 0
    @State private var processingTimer: Timer?
    @State private var justCopied = false

    /// When true, uses compact layout for menu bar
    var isCompact: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Logo area (hidden in compact mode)
            if !isCompact {
                VStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundStyle(viewModel.isRecording ? Color.omoiOrange : Color.omoiTeal)

                    Text("OMOI")
                        .font(OmoiFont.brand(size: 20))
                        .foregroundStyle(Color.omoiWhite)
                }
                .padding(.top, 24)
                .padding(.bottom, 16)
            }

            // Status message
            statusMessageView
                .padding(.vertical, isCompact ? 8 : 16)

            // Record button - brutalist
            Button(action: {
                viewModel.manualToggleRecording()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 16))
                    Text(viewModel.isRecording ? "STOP" : "RECORD")
                        .font(OmoiFont.label(size: 14))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(viewModel.isRecording ? Color.omoiOrange : Color.omoiTeal)
                .foregroundColor(Color.omoiBlack)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, isCompact ? 12 : 20)

            // Audio level indicator (recording, full mode only)
            if viewModel.isRecording && !isCompact {
                audioLevelIndicator
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
            }

            // Text output area
            if !isCompact {
                VStack(alignment: .leading, spacing: 8) {
                    Text("OUTPUT")
                        .font(OmoiFont.label(size: 10))
                        .foregroundStyle(Color.omoiMuted)

                    TextEditor(text: $viewModel.transcribedText)
                        .font(OmoiFont.body(size: 13))
                        .scrollContentBackground(.hidden)
                        .background(Color.omoiGray)
                        .foregroundStyle(Color.omoiWhite)
                        .frame(height: 120)
                }
                .padding(20)
            } else {
                // Compact preview
                if !viewModel.transcribedText.isEmpty {
                    Text(viewModel.transcribedText)
                        .font(OmoiFont.body(size: 12))
                        .foregroundStyle(Color.omoiOffWhite)
                        .lineLimit(2)
                        .padding(12)
                        .background(Color.omoiGray)
                }
            }

            Spacer()

            // Bottom controls
            if !isCompact {
                VStack(spacing: 12) {
                    // Shortcut row
                    HStack {
                        Text("SHORTCUT")
                            .font(OmoiFont.label(size: 10))
                            .foregroundStyle(Color.omoiMuted)
                        Text(ShortcutFormatter.format(KeyboardShortcuts.getShortcut(for: .toggleRecord)))
                            .font(OmoiFont.mono(size: 11))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.omoiGray)
                            .foregroundStyle(Color.omoiTeal)
                        Button("CHANGE") {
                            openWindow(id: "settings")
                        }
                        .font(OmoiFont.label(size: 10))
                        .foregroundStyle(Color.omoiMuted)
                        .buttonStyle(.plain)
                        Spacer()
                    }

                    // Action row
                    HStack(spacing: 16) {
                        Toggle(isOn: Binding(
                            get: { viewModel.autoPasteEnabled },
                            set: { newValue in
                                if newValue && viewModel.accessibilityPermissionState == .denied {
                                    viewModel.showAccessibilityAlert = true
                                } else {
                                    viewModel.autoPasteEnabled = newValue
                                }
                            }
                        )) {
                            Text("AUTO-PASTE")
                                .font(OmoiFont.label(size: 10))
                                .foregroundStyle(Color.omoiMuted)
                        }
                        .toggleStyle(.switch)

                        Spacer()

                        Button(action: { viewModel.synthesizeText() }) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(viewModel.transcribedText.isEmpty ? Color.omoiGray : Color.omoiLightGray)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.transcribedText.isEmpty)

                        Button(action: {
                            viewModel.copyToClipboard()
                            withAnimation(.easeOut(duration: 0.3)) {
                                justCopied = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    justCopied = false
                                }
                            }
                        }) {
                            Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 14))
                                .foregroundStyle(justCopied ? Color.omoiGreen : (viewModel.transcribedText.isEmpty ? Color.omoiGray : Color.omoiLightGray))
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.transcribedText.isEmpty)
                    }
                }
                .padding(20)
                .background(Color.omoiDarkGray)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color.omoiGray),
                    alignment: .top
                )
            } else {
                // Compact copy button
                Button(action: {
                    viewModel.copyToClipboard()
                    justCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        justCopied = false
                    }
                }) {
                    Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(justCopied ? Color.omoiGreen : Color.omoiLightGray)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.transcribedText.isEmpty)
                .padding(12)
            }

            // Error message (full mode only)
            if !isCompact, let errorMessage = viewModel.errorMessage {
                HStack {
                    Text(errorMessage.uppercased())
                        .font(OmoiFont.label(size: 10))
                        .foregroundStyle(Color.omoiOrange)
                    Spacer()
                }
                .padding(12)
                .background(Color.omoiOrange.opacity(0.1))
            }
        }
        .background(Color.omoiBlack)
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            if viewModel.isRecording {
                audioLevel = CGFloat.random(in: 0.3...0.9)
            } else {
                audioLevel = 0
            }
        }
    }

    // MARK: - Status Message View
    @ViewBuilder
    private var statusMessageView: some View {
        switch viewModel.transcriptionState {
        case .recording:
            VStack(spacing: 4) {
                Text("LISTENING")
                    .font(OmoiFont.label(size: 12))
                    .foregroundStyle(Color.omoiOrange)
                Text("Keep talking...")
                    .font(OmoiFont.body(size: 11))
                    .foregroundStyle(Color.omoiMuted)
            }

        case .processing:
            VStack(spacing: 8) {
                Text("PROCESSING")
                    .font(OmoiFont.label(size: 12))
                    .foregroundStyle(Color.omoiTeal)
                ProgressView()
                    .scaleEffect(0.7)
            }

        case .completed:
            VStack(spacing: 4) {
                Text("READY")
                    .font(OmoiFont.label(size: 12))
                    .foregroundStyle(Color.omoiGreen)
                if viewModel.autoPasteEnabled {
                    Text("Pasted")
                        .font(OmoiFont.body(size: 11))
                        .foregroundStyle(Color.omoiMuted)
                }
            }

        case .failed(let reason):
            VStack(spacing: 4) {
                Text("FAILED")
                    .font(OmoiFont.label(size: 12))
                    .foregroundStyle(Color.omoiOrange)
                Text(reason)
                    .font(OmoiFont.body(size: 10))
                    .foregroundStyle(Color.omoiMuted)
            }

        case .idle, .pasting:
            Text("READY TO CAPTURE")
                .font(OmoiFont.label(size: 11))
                .foregroundStyle(Color.omoiMuted)
        }
    }

    // MARK: - Audio Level Indicator
    @ViewBuilder
    private var audioLevelIndicator: some View {
        HStack(spacing: 2) {
            ForEach(0..<8, id: \.self) { index in
                Rectangle()
                    .fill(audioLevel > CGFloat(index) * 0.125 ? Color.omoiOrange : Color.omoiGray)
                    .frame(height: 4)
            }
        }
    }
}

// MARK: - Permission Instruction Sheet
struct PermissionInstructionSheet: View {
    var viewModel: ContentViewModel?
    @Environment(\.dismiss) var dismiss
    @State private var permissionGranted = false
    @State private var showTroubleshooting = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("Enable Accessibility Access")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }

            if permissionGranted {
                // Success state
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Permission Granted!")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Auto-paste is now enabled. You can close this window.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxHeight: .infinity)
                
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    // Steps
                    VStack(alignment: .leading, spacing: 16) {
                        InstructionStep(
                            number: "1",
                            title: "System Settings will open",
                            subtitle: "We'll take you directly to Privacy & Security > Accessibility."
                        )
                        
                        InstructionStep(
                            number: "2",
                            title: "Find Omoi in the list",
                            subtitle: "Look for the app name and icon."
                        )
                        
                        InstructionStep(
                            number: "3",
                            title: "Toggle the switch ON",
                            subtitle: "You may need to enter your system password to confirm."
                        )
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Troubleshooting section
                    if showTroubleshooting {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Already enabled but still not working?", systemImage: "exclamationmark.triangle.fill")
                                .font(.headline)
                                .foregroundColor(.orange)
                            
                            Text("After rebuilding the app, macOS may silently disable the permission. Try this:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 8) {
                                    Text("1.")
                                        .fontWeight(.bold)
                                    Text("Toggle Omoi OFF in System Settings")
                                }
                                HStack(alignment: .top, spacing: 8) {
                                    Text("2.")
                                        .fontWeight(.bold)
                                    Text("Toggle it back ON")
                                }
                                HStack(alignment: .top, spacing: 8) {
                                    Text("3.")
                                        .fontWeight(.bold)
                                    Text("Click 'Check Again' below")
                                }
                            }
                            .font(.caption)
                            .padding(12)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.05))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                        )
                    }
                    
                    // Can't Find Section
                    if !AccessibilityPermissions.isRunningAsAppBundle {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Running as Raw Binary", systemImage: "exclamationmark.triangle.fill")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            Text("You are running a raw 'Unix Executable File', which macOS often blocks from Accessibility permissions.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                
                            Text("Fix: Run './build_app.sh' to create a proper .app bundle.")
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(8)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .padding()
                        .background(Color.red.opacity(0.05))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
            
            Spacer()
            
            // Action buttons
            if !permissionGranted {
                VStack(spacing: 12) {
                    Button(action: {
                        // Re-check permission and force refresh in ViewModel
                        let hasPermission = AccessibilityPermissions.hasAccessibilityPermission()
                        print("🔐 [PermissionSheet] Check Again pressed")
                        print("   - Permission status: \(hasPermission)")

                        if hasPermission {
                            permissionGranted = true
                            // Force update the viewModel's permission state (if available)
                            viewModel?.setupPermissionObservers()
                            print("   ✅ Permission granted - updated ViewModel")
                        } else {
                            showTroubleshooting = true
                            print("   ❌ Still no permission")
                        }
                    }) {
                        Text("Check Again")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    if !showTroubleshooting {
                        Button("I'm having trouble") {
                            showTroubleshooting = true
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            } else {
                Button(action: { dismiss() }) {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(24)
        .frame(width: 500, height: 650)
    }
}

struct InstructionStep: View {
    let number: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 24, height: 24)
                Text(number)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// Backend status indicator
struct BackendStatusIndicator: View {
    @ObservedObject var backendManager = BackendManager.shared

    var body: some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(statusColor)
                .frame(width: 4, height: 4)

            Text(statusText.uppercased())
                .font(OmoiFont.mono(size: 9))
                .foregroundStyle(Color.omoiMuted)

            // Show RESTART button when backend has failed
            if case .failed = backendManager.status {
                Button(action: { backendManager.restartBackend() }) {
                    Text("RESTART")
                        .font(OmoiFont.mono(size: 9))
                        .foregroundStyle(Color.omoiTeal)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var statusColor: Color {
        switch backendManager.status {
        case .running:
            return Color.omoiGreen
        case .starting:
            return Color.omoiOrange
        case .stopped, .failed:
            return Color.omoiOrange
        }
    }

    private var statusText: String {
        switch backendManager.status {
        case .running:
            return "Ready"
        case .starting:
            return "Starting"
        case .stopped:
            return "Stopped"
        case .failed:
            return "Failed"
        }
    }
}
