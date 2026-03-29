import Foundation

// MARK: - Aggregation & Query

extension StatsManager {

    // MARK: - Session Queries

    /// Retrieve all sessions for a specific date (chronological order)
    func sessionsForDate(_ date: Date) -> [TranscriptionSession] {
        let calendar = Calendar.current
        return sessions.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
            .sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Word / WPM Per Day

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

    // MARK: - App Stats

    var wpmByApp: [(appName: String, avgWPM: Double, sessionCount: Int)] {
        let appGroups = Dictionary(
            grouping: sessions.filter { $0.targetAppName != nil && $0.effectiveDuration > 0.1 }
        ) { session in session.targetAppName! }

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

    var topApps: [(name: String, count: Int)] {
        let appCounts = Dictionary(grouping: sessions.compactMap { $0.targetAppName }, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(5)
        return appCounts.map { (name: $0.key, count: $0.value) }
    }

    // MARK: - Peak Hour

    var peakProductivityHour: (hour: Int, words: Int)? {
        guard !sessions.isEmpty else { return nil }
        let calendar = Calendar.current
        let hourGroups = Dictionary(grouping: sessions) { session in
            calendar.component(.hour, from: session.timestamp)
        }
        let hourTotals = hourGroups.mapValues { sessions in
            sessions.reduce(0) { $0 + $1.wordCount }
        }
        guard let peak = hourTotals.max(by: { $0.value < $1.value }) else { return nil }
        return (hour: peak.key, words: peak.value)
    }

    // MARK: - Week-over-Week

    var weekOverWeekComparison: [(day: String, thisWeek: Int, lastWeek: Int)] {
        let calendar = Calendar.current
        let now = Date()
        let thisWeekDates = (0..<7).compactMap { offset -> Date? in
            calendar.date(byAdding: .day, value: -offset, to: now)
        }.reversed()

        return thisWeekDates.map { date in
            let thisWeekWords = sessions.filter { session in
                calendar.isDate(session.timestamp, inSameDayAs: date)
            }.reduce(0) { $0 + $1.wordCount }

            guard let lastWeekDate = calendar.date(byAdding: .day, value: -7, to: date) else {
                return (day: dayOfWeek(date), thisWeek: thisWeekWords, lastWeek: 0)
            }

            let lastWeekWords = sessions.filter { session in
                calendar.isDate(session.timestamp, inSameDayAs: lastWeekDate)
            }.reduce(0) { $0 + $1.wordCount }

            return (day: dayOfWeek(date), thisWeek: thisWeekWords, lastWeek: lastWeekWords)
        }
    }

    // MARK: - Streak

    var currentStreak: Int {
        guard !sessions.isEmpty else { return 0 }
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        let todaySessions = sessions.filter { calendar.isDate($0.timestamp, inSameDayAs: Date()) }
        if todaySessions.isEmpty {
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }

        while true {
            let daySessions = sessions.filter { calendar.isDate($0.timestamp, inSameDayAs: checkDate) }
            if daySessions.isEmpty { break }
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDay
        }
        return streak
    }

    // MARK: - Moving Averages

    var wordsMovingAverage: [(date: Date, average: Double)] {
        let data = wordsPerDay
        guard data.count >= 3 else { return [] }
        return data.enumerated().compactMap { index, item in
            let windowStart = max(0, index - 3)
            let windowEnd   = min(data.count - 1, index + 3)
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
            let windowEnd   = min(data.count - 1, index + 3)
            let window = data[windowStart...windowEnd]
            let average = window.reduce(0.0) { $0 + $1.wpm } / Double(window.count)
            return (date: item.date, average: average)
        }
    }

    // MARK: - Helpers

    func calculateVariance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        guard mean != 0 else { return 0 }
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        let variance = squaredDiffs.reduce(0, +) / Double(values.count)
        let result = variance / (mean * mean) // coefficient of variation
        return result.isFinite ? result : 0
    }

    func rollingAverage(_ values: [Double], window: Int = 7) -> [Double] {
        guard values.count >= window else { return values }
        return values.enumerated().map { index, _ in
            let start = max(0, index - window + 1)
            let slice = values[start...index]
            return slice.reduce(0, +) / Double(slice.count)
        }
    }

    func timeOfDayLabel(for hour: Int) -> String {
        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default: return "late night"
        }
    }

    private func dayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}
