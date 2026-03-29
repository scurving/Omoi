import SwiftUI

// MARK: - Permission State Enum
enum PermissionState: Equatable {
    case unknown
    case granted
    case denied
    case needsRecheck
}

// MARK: - Transcription State Enum
enum TranscriptionState: Equatable {
    case idle
    case recording
    case processing    // API call in progress
    case pasting       // Auto-paste executing
    case completed     // Transient success state
    case failed(String) // Transient error state
}

// MARK: - Shared App State
class AppState: ObservableObject {
    @Published var transcriptionState: TranscriptionState = .idle

    var menuBarIcon: String {
        switch transcriptionState {
        case .idle:
            return "mic.fill"
        case .recording:
            return "waveform"
        case .processing:
            return "arrow.triangle.2.circlepath"
        case .pasting:
            return "doc.on.clipboard.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
}
