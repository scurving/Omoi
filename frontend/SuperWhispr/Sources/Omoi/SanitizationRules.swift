import Foundation

struct SanitizationRules: Codable {
    var enabled: Bool = false
    var instructions: String = ""
    var version: Int = 1
    var lastModified: Date = Date()
    var autoSanitizeBeforePaste: Bool = false
    var activePresetId: UUID? = nil

    enum CodingKeys: String, CodingKey {
        case enabled
        case instructions
        case version
        case lastModified
        case autoSanitizeBeforePaste
        case activePresetId
    }

    init(
        enabled: Bool = false,
        instructions: String = "",
        version: Int = 1,
        lastModified: Date = Date(),
        autoSanitizeBeforePaste: Bool = false,
        activePresetId: UUID? = nil
    ) {
        self.enabled = enabled
        self.instructions = instructions
        self.version = version
        self.lastModified = lastModified
        self.autoSanitizeBeforePaste = autoSanitizeBeforePaste
        self.activePresetId = activePresetId
    }

    // MARK: - Codable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        instructions = try container.decodeIfPresent(String.self, forKey: .instructions) ?? ""
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date()
        autoSanitizeBeforePaste = try container.decodeIfPresent(Bool.self, forKey: .autoSanitizeBeforePaste) ?? false
        activePresetId = try container.decodeIfPresent(UUID.self, forKey: .activePresetId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(instructions, forKey: .instructions)
        try container.encode(version, forKey: .version)
        try container.encode(lastModified, forKey: .lastModified)
        try container.encode(autoSanitizeBeforePaste, forKey: .autoSanitizeBeforePaste)
        try container.encodeIfPresent(activePresetId, forKey: .activePresetId)
    }
}
