import Cocoa
import SwiftUI

class HUDController {
    static let shared = HUDController()

    private var hudPanel: NSPanel?
    private var dismissTimer: Timer?

    func show(state: TranscriptionState) {
        DispatchQueue.main.async {
            self.dismiss()  // Dismiss any existing HUD first

            let hudView = HUDView(state: state)
            let hostingController = NSHostingController(rootView: hudView)

            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
                styleMask: [.nonactivatingPanel, .hudWindow],
                backing: .buffered,
                defer: false
            )

            panel.contentViewController = hostingController
            panel.isFloatingPanel = true
            panel.level = .statusBar
            panel.backgroundColor = NSColor.clear
            panel.isOpaque = false

            // Position near menu bar, top-right area
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                panel.setFrameOrigin(NSPoint(
                    x: screenFrame.maxX - panel.frame.width - 20,
                    y: screenFrame.maxY - panel.frame.height - 10
                ))
            }

            panel.orderFront(nil)
            self.hudPanel = panel

            // Auto-dismiss after 2-3 seconds depending on state
            let dismissDelay: TimeInterval = {
                switch state {
                case .processing:
                    return 0  // Don't auto-dismiss for processing, wait for completion
                case .completed:
                    return 2.0
                case .failed:
                    return 3.0
                default:
                    return 0
                }
            }()

            if dismissDelay > 0 {
                self.dismissTimer = Timer.scheduledTimer(withTimeInterval: dismissDelay, repeats: false) { [weak self] _ in
                    self?.dismiss()
                }
            }
        }
    }

    func dismiss() {
        DispatchQueue.main.async {
            self.dismissTimer?.invalidate()
            self.dismissTimer = nil

            self.hudPanel?.orderOut(nil)
            self.hudPanel = nil
        }
    }

    deinit {
        dismiss()
    }
}

// MARK: - HUD View
struct HUDView: View {
    let state: TranscriptionState

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.white)

            Text(message)
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(16)
        .background(Color.black.opacity(0.85))
        .cornerRadius(12)
        .frame(width: 120, height: 100)
    }

    private var icon: String {
        switch state {
        case .recording:
            return "waveform"
        case .processing:
            return "arrow.triangle.2.circlepath"
        case .pasting:
            return "doc.on.clipboard"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        default:
            return "mic"
        }
    }

    private var message: String {
        switch state {
        case .recording:
            return "Recording..."
        case .processing:
            return "Transcribing..."
        case .pasting:
            return "Pasting..."
        case .completed:
            return "Done!"
        case .failed:
            return "Failed"
        default:
            return ""
        }
    }
}
