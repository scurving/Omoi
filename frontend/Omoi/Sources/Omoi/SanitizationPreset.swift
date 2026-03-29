import Foundation

struct SanitizationPreset: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var instructions: String
    var isBuiltIn: Bool
    let createdAt: Date

    init(id: UUID = UUID(), name: String, instructions: String, isBuiltIn: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.instructions = instructions
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
    }

    static let defaultPresets: [SanitizationPreset] = [
        SanitizationPreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Fix Grammar",
            instructions: "Fix any spelling mistakes, grammar errors, and punctuation issues. Do not change the meaning or add/remove content. Keep the same tone and style.",
            isBuiltIn: true
        ),
        SanitizationPreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Remove PII",
            instructions: "Remove all personally identifiable information including: email addresses, phone numbers, physical addresses, social security numbers, and full names. Replace them with [REDACTED].",
            isBuiltIn: true
        ),
        SanitizationPreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "Professional Tone",
            instructions: "Rewrite in a professional, business-appropriate tone. Fix grammar and spelling. Remove filler words and casual language.",
            isBuiltIn: true
        )
    ]
}
