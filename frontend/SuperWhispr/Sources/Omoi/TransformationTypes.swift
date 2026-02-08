import Foundation

// MARK: - Transformation Mode

enum TransformationMode: String, Codable {
    case parallel    // Each preset runs on original text independently
    case sequential  // Each preset chains on previous result
}

// MARK: - Transformation Result

struct TransformationResult: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let presetIds: [UUID]
    let presetNames: [String]
    let mode: TransformationMode
    let timestamp: Date

    /// Display label for tabs (e.g., "Grammar" or "Grammar → PII")
    var displayLabel: String {
        if mode == .sequential && presetNames.count > 1 {
            return presetNames.joined(separator: " → ")
        }
        return presetNames.first ?? "Unknown"
    }

    init(
        id: UUID = UUID(),
        text: String,
        presetIds: [UUID],
        presetNames: [String],
        mode: TransformationMode,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.presetIds = presetIds
        self.presetNames = presetNames
        self.mode = mode
        self.timestamp = timestamp
    }
}

// MARK: - Session Transformations Container

struct SessionTransformations: Codable, Equatable {
    var results: [TransformationResult]
    var selectedResultId: UUID?
    var lastUpdated: Date

    init(results: [TransformationResult] = [], selectedResultId: UUID? = nil) {
        self.results = results
        self.selectedResultId = selectedResultId
        self.lastUpdated = Date()
    }

    mutating func addResult(_ result: TransformationResult) {
        results.append(result)
        selectedResultId = result.id
        lastUpdated = Date()
    }

    mutating func selectResult(_ id: UUID?) {
        selectedResultId = id
        lastUpdated = Date()
    }

    var selectedResult: TransformationResult? {
        guard let id = selectedResultId else { return nil }
        return results.first { $0.id == id }
    }

    /// Text to copy based on selection (nil = use original)
    var selectedText: String? {
        selectedResult?.text
    }
}

// MARK: - Saved Pipeline

struct SavedPipeline: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var presetIds: [UUID]
    var mode: TransformationMode
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        presetIds: [UUID],
        mode: TransformationMode,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.presetIds = presetIds
        self.mode = mode
        self.createdAt = createdAt
    }
}
