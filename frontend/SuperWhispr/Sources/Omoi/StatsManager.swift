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

    private init() {
        loadSessions()
        loadGoals()
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

    private func todayWords() -> Int {
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

    // MARK: - Tag Suggestions

    /// Generate tag suggestions using LLM (async)
    func suggestTagsWithLLM(for session: TranscriptionSession) async -> [String] {
        let llmSuggestions = await OllamaService.shared.generateTags(
            for: session.text,
            app: session.targetAppName,
            existingTags: allTags,
            sessionID: session.id
        )

        // Filter out tags already on session
        return llmSuggestions.filter { !session.tags.contains($0) }
    }

    /// Fallback: Static keyword-based tag suggestions (when LLM unavailable)
    func suggestTagsFallback(for session: TranscriptionSession) -> [String] {
        var suggestions: [String] = []
        let text = session.text.lowercased()

        // App-based suggestions
        if let app = session.targetAppName?.lowercased() {
            if ["slack", "teams", "zoom", "discord"].contains(app) {
                suggestions.append("meeting")
            }
            if ["mail", "outlook"].contains(app) {
                suggestions.append("email")
            }
            if ["notes", "bear", "notion"].contains(app) {
                suggestions.append("draft")
            }
        }

        // Content-based keyword matching
        let workKeywords = ["meeting", "project", "deadline", "client", "team", "schedule", "task"]
        let personalKeywords = ["remind me", "groceries", "appointment", "personal", "family"]
        let ideaKeywords = ["idea", "think about", "maybe we could", "what if"]

        if workKeywords.contains(where: { text.contains($0) }) {
            suggestions.append("work")
        }
        if personalKeywords.contains(where: { text.contains($0) }) {
            suggestions.append("personal")
        }
        if ideaKeywords.contains(where: { text.contains($0) }) {
            suggestions.append("idea")
        }

        // Question detection
        if text.contains("?") {
            suggestions.append("question")
        }

        // Action items
        if text.contains("todo") || text.contains("to do") || text.contains("need to") {
            suggestions.append("action")
        }

        // Important markers
        if text.contains("important") || text.contains("urgent") || text.contains("asap") {
            suggestions.append("important")
        }

        // Remove duplicates and existing tags
        return Array(Set(suggestions)).filter { !session.tags.contains($0) }
    }

    // Performance insights generation
    var performanceInsights: [PerformanceInsight] {
        var insights: [PerformanceInsight] = []

        // Peak hour insight
        if let peak = peakProductivityHour {
            let timeOfDay = timeOfDayLabel(for: peak.hour)
            insights.append(PerformanceInsight(
                icon: "clock.fill",
                title: "Peak Time",
                message: "You capture most words in the \(timeOfDay). Schedule important work then.",
                type: .timing
            ))
        }

        // Fastest app insight
        if let fastestApp = wpmByApp.first, wpmByApp.count >= 2 {
            let slowestApp = wpmByApp.last!
            if slowestApp.avgWPM > 0 {
                let diffValue = ((fastestApp.avgWPM - slowestApp.avgWPM) / slowestApp.avgWPM) * 100
                let diff = diffValue.isFinite ? Int(diffValue) : 0
                insights.append(PerformanceInsight(
                    icon: "speedometer",
                    title: "Context Matters",
                    message: "You speak \(diff)% faster in \(fastestApp.appName) than \(slowestApp.appName).",
                    type: .speed
                ))
            }
        }

        // Consistency insight
        let recentWeek = weekOverWeekComparison
        if !recentWeek.isEmpty {
            let variance = calculateVariance(recentWeek.map { Double($0.thisWeek) })
            if variance < 0.2 {
                insights.append(PerformanceInsight(
                    icon: "chart.line.flattrend.xyaxis",
                    title: "Consistent Rhythm",
                    message: "Your daily word count is very consistent. Great habit formation!",
                    type: .habit
                ))
            }
        }

        // Streak milestone
        if currentStreak >= 7 {
            insights.append(PerformanceInsight(
                icon: "flame.fill",
                title: "Streak Master",
                message: "\(currentStreak)-day streak! You're building a strong daily practice.",
                type: .milestone
            ))
        }

        return insights
    }

    private func timeOfDayLabel(for hour: Int) -> String {
        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default: return "late night"
        }
    }

    private func calculateVariance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        guard mean != 0 else { return 0 }
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        let variance = squaredDiffs.reduce(0, +) / Double(values.count)
        let result = variance / (mean * mean) // coefficient of variation
        return result.isFinite ? result : 0
    }

    // MARK: - Computed Metrics

    var totalWords: Int {
        sessions.reduce(0) { $0 + $1.wordCount }
    }
    
    var averageWPM: Double {
        let validSessions = sessions.filter { $0.effectiveDuration > 0.1 }  // At least 0.1 seconds
        guard !validSessions.isEmpty else { return 0 }
        let totalWPM = validSessions.reduce(0.0) { sum, session in
            let wpm = Double(session.wordCount) / (session.effectiveDuration / 60.0)
            return sum + (wpm.isFinite ? wpm : 0)
        }
        let result = totalWPM / Double(validSessions.count)
        return result.isFinite ? result : 0
    }
    
    var currentStreak: Int {
        guard !sessions.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())
        
        // Check if today has any sessions
        let todaySessions = sessions.filter { calendar.isDate($0.timestamp, inSameDayAs: Date()) }
        if todaySessions.isEmpty {
            // If no sessions today, start checking from yesterday
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        
        // Count consecutive days with sessions
        while true {
            let daySessions = sessions.filter { calendar.isDate($0.timestamp, inSameDayAs: checkDate) }
            if daySessions.isEmpty {
                break
            }
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDay
        }
        
        return streak
    }
    
    var topApps: [(name: String, count: Int)] {
        let appCounts = Dictionary(grouping: sessions.compactMap { $0.targetAppName }, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(5)
        
        return appCounts.map { (name: $0.key, count: $0.value) }
    }
    
    var wordsPerDay: [(date: Date, words: Int)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.timestamp)
        }

        return grouped.map { (date: $0.key, words: $0.value.reduce(0) { $0 + $1.wordCount }) }
            .sorted { $0.date > $1.date }
            .prefix(7)
            .reversed()
            .map { $0 }
    }

    var wpmPerDay: [(date: Date, wpm: Double)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.timestamp)
        }

        return grouped.compactMap { (date, sessions) -> (date: Date, wpm: Double)? in
            let validSessions = sessions.filter { $0.effectiveDuration > 0.1 }
            guard !validSessions.isEmpty else { return nil }

            let totalWPM = validSessions.reduce(0.0) { sum, session in
                let wpm = Double(session.wordCount) / (session.effectiveDuration / 60.0)
                return sum + (wpm.isFinite ? wpm : 0)
            }
            let avgWPM = totalWPM / Double(validSessions.count)

            return avgWPM.isFinite ? (date: date, wpm: avgWPM) : nil
        }
        .sorted { $0.date > $1.date }
        .prefix(7)
        .reversed()
        .map { $0 }
    }

    var peakProductivityHour: (hour: Int, words: Int)? {
        guard !sessions.isEmpty else { return nil }

        let calendar = Calendar.current
        let hourGroups = Dictionary(grouping: sessions) { session in
            calendar.component(.hour, from: session.timestamp)
        }

        let hourTotals = hourGroups.mapValues { sessions in
            sessions.reduce(0) { $0 + $1.wordCount }
        }

        guard let peak = hourTotals.max(by: { $0.value < $1.value }) else {
            return nil
        }

        return (hour: peak.key, words: peak.value)
    }

    var wpmByApp: [(appName: String, avgWPM: Double, sessionCount: Int)] {
        let appGroups = Dictionary(grouping: sessions.filter { $0.targetAppName != nil && $0.effectiveDuration > 0.1 }) { session in
            session.targetAppName!
        }

        return appGroups.compactMap { (appName, sessions) -> (appName: String, avgWPM: Double, sessionCount: Int)? in
            guard !sessions.isEmpty else { return nil }

            let totalWPM = sessions.reduce(0.0) { sum, session in
                let wpm = Double(session.wordCount) / (session.effectiveDuration / 60.0)
                return sum + (wpm.isFinite ? wpm : 0)
            }
            let avgWPM = totalWPM / Double(sessions.count)

            return avgWPM.isFinite ? (appName: appName, avgWPM: avgWPM, sessionCount: sessions.count) : nil
        }
        .sorted { $0.avgWPM > $1.avgWPM }
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

    // Week-over-week comparison data
    var weekOverWeekComparison: [(day: String, thisWeek: Int, lastWeek: Int)] {
        let calendar = Calendar.current
        let now = Date()

        // Get last 7 days (this week)
        let thisWeekDates = (0..<7).compactMap { offset -> Date? in
            calendar.date(byAdding: .day, value: -offset, to: now)
        }.reversed()

        return thisWeekDates.map { date in
            let thisWeekWords = sessions.filter { session in
                calendar.isDate(session.timestamp, inSameDayAs: date)
            }.reduce(0) { $0 + $1.wordCount }

            // Get corresponding day from last week
            guard let lastWeekDate = calendar.date(byAdding: .day, value: -7, to: date) else {
                return (day: dayOfWeek(date), thisWeek: thisWeekWords, lastWeek: 0)
            }

            let lastWeekWords = sessions.filter { session in
                calendar.isDate(session.timestamp, inSameDayAs: lastWeekDate)
            }.reduce(0) { $0 + $1.wordCount }

            return (day: dayOfWeek(date), thisWeek: thisWeekWords, lastWeek: lastWeekWords)
        }
    }

    private func dayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    // Moving averages for trend visualization
    var wordsMovingAverage: [(date: Date, average: Double)] {
        let data = wordsPerDay
        guard data.count >= 3 else { return [] }

        return data.enumerated().compactMap { index, item in
            let windowStart = max(0, index - 3)
            let windowEnd = min(data.count - 1, index + 3)
            let window = data[windowStart...windowEnd]

            let average = Double(window.reduce(0) { $0 + $1.words }) / Double(window.count)
            return (date: item.date, average: average)
        }
    }

    var wpmMovingAverage: [(date: Date, average: Double)] {
        let data = wpmPerDay
        guard data.count >= 3 else { return [] }

        return data.enumerated().compactMap { index, item in
            let windowStart = max(0, index - 3)
            let windowEnd = min(data.count - 1, index + 3)
            let window = data[windowStart...windowEnd]

            let average = window.reduce(0.0) { $0 + $1.wpm } / Double(window.count)
            return (date: item.date, average: average)
        }
    }
}

// MARK: - Performance Insight Model

struct PerformanceInsight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let message: String
    let type: InsightType

    enum InsightType {
        case timing, speed, habit, milestone
    }
}
