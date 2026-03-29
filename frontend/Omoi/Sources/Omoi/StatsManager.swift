import Foundation
import Combine

@MainActor
class StatsManager: ObservableObject {
    static let shared = StatsManager()

    @Published var sessions: [TranscriptionSession] = []
    @Published var goals: [UserGoal] = []

    private let sessionsKey = "Omoi.Sessions"
    private let goalsKey = "Omoi.Goals"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var typingObserver: Any?

    private init() {
        loadSessions()
        loadGoals()

        // Refresh UI when typing data changes
        typingObserver = NotificationCenter.default.addObserver(
            forName: .typingDataChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    // MARK: - Persistence

    // Using StorageManager (JSON in Documents) instead of UserDefaults
    private let storage = StorageManager.shared

    func saveSessions() {
        storage.saveSessions(sessions)
    }

    private func loadSessions() {
        sessions = storage.loadSessions()
    }

    func addSession(_ session: TranscriptionSession) {
        sessions.insert(session, at: 0)
        saveSessions()
    }

    func clearHistory() {
        sessions.removeAll()
        saveSessions()
    }

    func updateSessionSanitized(_ sessionID: UUID, sanitizedText: String) {
        if let index = sessions.firstIndex(where: { $0.id == sessionID }) {
            sessions[index].sanitizedText = sanitizedText
            saveSessions()
        }
    }

    func clearAllSanitizedText() {
        sessions = sessions.map { session in
            var updated = session
            updated.sanitizedText = nil
            return updated
        }
        saveSessions()
    }

    /// Retrieve all sessions for a specific date
    func sessions(for date: Date) -> [TranscriptionSession] {
        let calendar = Calendar.current
        return sessions.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
            .sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Retrospectives Persistence

    func saveRetrospective(_ text: String, for date: Date) {
        StorageManager.shared.saveRetrospective(text, for: date)
    }

    func loadRetrospective(for date: Date) -> String? {
        return StorageManager.shared.loadRetrospective(for: date)
    }

    // MARK: - Transformation Management

    func addTransformationResult(_ sessionID: UUID, result: TransformationResult) {
        if let index = sessions.firstIndex(where: { $0.id == sessionID }) {
            if sessions[index].transformations == nil {
                sessions[index].transformations = SessionTransformations()
            }
            sessions[index].transformations?.addResult(result)
            saveSessions()
        }
    }

    func selectTransformationResult(_ sessionID: UUID, resultId: UUID?) {
        if let index = sessions.firstIndex(where: { $0.id == sessionID }) {
            sessions[index].transformations?.selectResult(resultId)
            saveSessions()
        }
    }

    func clearSessionTransformations(_ sessionID: UUID) {
        if let index = sessions.firstIndex(where: { $0.id == sessionID }) {
            sessions[index].transformations = nil
            saveSessions()
        }
    }

    // MARK: - Goal Management

    func loadGoals() {
        goals = storage.loadGoals()
    }

    func saveGoals() {
        storage.saveGoals(goals)
    }

    func addGoal(_ goal: UserGoal) {
        goals.append(goal)
        saveGoals()
    }

    func updateGoal(_ goal: UserGoal) {
        if let index = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[index] = goal
            saveGoals()
        }
    }

    func deleteGoal(_ goalID: UUID) {
        goals.removeAll { $0.id == goalID }
        saveGoals()
    }

    func currentProgress(for goal: UserGoal) -> (current: Int, percentage: Double) {
        let current: Int

        switch (goal.type, goal.period) {
        case (.wordCount, .daily):
            current = todayWords()
        case (.wordCount, .weekly):
            current = thisWeekWords()
        case (.sessionCount, .daily):
            current = todaySessions()
        case (.sessionCount, .weekly):
            current = thisWeekSessions()
        case (.streak, _):
            current = currentStreak
        }

        let percentage = goal.target > 0 ? Double(current) / Double(goal.target) : 0
        return (current: current, percentage: min(percentage, 1.5)) // Cap at 150% for display
    }

    func todayWords() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return sessions.filter { calendar.isDate($0.timestamp, inSameDayAs: today) }
            .reduce(0) { $0 + $1.wordCount }
    }

    private func todaySessions() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return sessions.filter { calendar.isDate($0.timestamp, inSameDayAs: today) }.count
    }

    private func thisWeekSessions() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        return sessions.filter { $0.timestamp >= weekAgo }.count
    }

    private func thisWeekWords() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        return sessions.filter { $0.timestamp >= weekAgo }
            .reduce(0) { $0 + $1.wordCount }
    }

    // MARK: - Tag Management

    func addTag(_ tag: String, to sessionID: UUID) {
        if let index = sessions.firstIndex(where: { $0.id == sessionID }) {
            var updated = sessions[index]
            if !updated.tags.contains(tag) {
                updated.tags.append(tag)
                sessions[index] = updated
                saveSessions()
            }
        }
    }

    func removeTag(_ tag: String, from sessionID: UUID) {
        if let index = sessions.firstIndex(where: { $0.id == sessionID }) {
            var updated = sessions[index]
            updated.tags.removeAll { $0 == tag }
            sessions[index] = updated
            saveSessions()
        }
    }

    var allTags: [String] {
        let tagSet = Set(sessions.flatMap { $0.tags })
        return Array(tagSet).sorted()
    }

    // MARK: - Computed Metrics

    var totalWords: Int {
        sessions.reduce(0) { $0 + $1.wordCount }
    }

    var averageWPM: Double {
        let validSessions = sessions.filter { $0.effectiveDuration > 0.1 }
        guard !validSessions.isEmpty else { return 0 }
        let totalWPM = validSessions.reduce(0.0) { sum, session in
            let wpm = Double(session.wordCount) / (session.effectiveDuration / 60.0)
            return sum + (wpm.isFinite ? wpm : 0)
        }
        let result = totalWPM / Double(validSessions.count)
        return result.isFinite ? result : 0
    }

    var statsByApp: [(appName: String, totalWords: Int, avgWPM: Double, sessionCount: Int)] {
        let appGroups = Dictionary(grouping: sessions.filter { $0.targetAppName != nil }) { session in
            session.targetAppName!
        }

        return appGroups.compactMap { (appName, sessions) -> (appName: String, totalWords: Int, avgWPM: Double, sessionCount: Int)? in
            guard !sessions.isEmpty else { return nil }

            let totalWords = sessions.reduce(0) { $0 + $1.wordCount }
            let validSessions = sessions.filter { $0.effectiveDuration > 0.1 }

            let avgWPM: Double
            if !validSessions.isEmpty {
                let totalWPM = validSessions.reduce(0.0) { sum, session in
                    let wpm = Double(session.wordCount) / (session.effectiveDuration / 60.0)
                    return sum + (wpm.isFinite ? wpm : 0)
                }
                avgWPM = totalWPM / Double(validSessions.count)
            } else {
                avgWPM = 0
            }

            return (appName: appName, totalWords: totalWords, avgWPM: avgWPM.isFinite ? avgWPM : 0, sessionCount: sessions.count)
        }
        .sorted { $0.totalWords > $1.totalWords }
    }
}
