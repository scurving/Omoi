import Foundation

struct UserGoal: Codable, Identifiable, Equatable {
    let id: UUID
    var type: GoalType
    var target: Int
    var period: GoalPeriod
    var isActive: Bool
    let createdAt: Date

    init(id: UUID = UUID(), type: GoalType, target: Int, period: GoalPeriod, isActive: Bool = true, createdAt: Date = Date()) {
        self.id = id
        self.type = type
        self.target = target
        self.period = period
        self.isActive = isActive
        self.createdAt = createdAt
    }

    enum GoalType: String, Codable, CaseIterable {
        case wordCount = "Word Count"
        case sessionCount = "Sessions"
        case streak = "Daily Streak"
    }

    enum GoalPeriod: String, Codable, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
    }
}
