import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Recording interface (reuse RecordView in compact mode for menu bar)
            RecordView(viewModel: viewModel, isCompact: true)
                .frame(height: 180)

            Divider()

            // Recent transcriptions
            RecentTranscriptionsView(statsManager: viewModel.stats)
                .frame(height: 150)

            Divider()

            // Footer
            HStack {
                Text("v\(Bundle.main.appVersionString)")
                    .font(.caption)
                    .foregroundStyle(Color.omoiMuted)
                Spacer()
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Label("Quit", systemImage: "power")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.omoiOrange)
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .background(Color.omoiBlack)
        .frame(width: 400, height: 500)
        .onAppear {
            viewModel.setupShortcutObserver()
            viewModel.setupPermissionObservers()
        }
        .onChange(of: viewModel.transcriptionState) { newState in
            appState.transcriptionState = newState
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
            Text("Omoi needs Accessibility permission to paste transcriptions automatically.")
        }
        .sheet(isPresented: $viewModel.showPermissionInstructionSheet) {
            PermissionInstructionSheet(viewModel: viewModel)
        }
    }
}
