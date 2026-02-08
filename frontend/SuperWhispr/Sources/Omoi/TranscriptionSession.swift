import Foundation

struct TranscriptionSession: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let text: String
    let wordCount: Int
    let duration: TimeInterval
    let speechDuration: TimeInterval?  // Actual speech time from Whisper (excludes silence)
    let targetAppBundleID: String?
    let targetAppName: String?
    var sanitizedText: String?
    var metadata: Metadata?
    var tags: [String]
    var audioFileName: String?  // For audio playback feature
    var transformations: SessionTransformations?  // Multiple transformation results

    struct Metadata: Codable {
        let windowTitle: String?
        let model: String? // e.g. "whisper-base"
        let processingTime: TimeInterval?
        let intent: String? // user's original command/intent (future)
    }

    /// Effective duration for WPM calculation (prefers speechDuration over total duration)
    var effectiveDuration: TimeInterval {
        speechDuration ?? duration
    }

    /// Whether this session has a saved audio recording
    var hasAudio: Bool {
        audioFileName != nil
    }

    init(id: UUID = UUID(), timestamp: Date = Date(), text: String, duration: TimeInterval, speechDuration: TimeInterval? = nil, targetAppBundleID: String?, targetAppName: String?, sanitizedText: String? = nil, metadata: Metadata? = nil, tags: [String] = [], audioFileName: String? = nil, transformations: SessionTransformations? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.wordCount = text.split(separator: " ").count
        self.duration = duration
        self.speechDuration = speechDuration
        self.targetAppBundleID = targetAppBundleID
        self.targetAppName = targetAppName
        self.sanitizedText = sanitizedText
        self.metadata = metadata
        self.tags = tags
        self.audioFileName = audioFileName
        self.transformations = transformations
    }
}
