import Foundation

// MARK: - TypingSession (discrete burst — unified timeline)

struct TypingSession: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let appBundleID: String
    let appName: String
    let windowTitle: String?
    let keystrokeCount: Int
    let keyboard: KeyboardSource

    /// Actual word count: counted from space/return key presses
    let wordCount: Int

    /// Duration of the typing burst (from first to last keystroke)
    let duration: TimeInterval

    /// Estimated WPM: words / (duration / 60.0)
    var wpm: Double {
        guard duration > 0 else { return 0 }
        return Double(wordCount) / (duration / 60.0)
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        appBundleID: String,
        appName: String,
        windowTitle: String? = nil,
        keystrokeCount: Int,
        wordCount: Int,
        keyboard: KeyboardSource,
        duration: TimeInterval
    ) {
        self.id = id
        self.timestamp = timestamp
        self.appBundleID = appBundleID
        self.appName = appName
        self.windowTitle = windowTitle
        self.keystrokeCount = keystrokeCount
        self.wordCount = wordCount
        self.keyboard = keyboard
        self.duration = duration
    }
}

// MARK: - KeyboardSource

enum KeyboardSource: String, Codable, CaseIterable {
    case builtin   // Apple internal keyboard
    case nuphy     // Product name contains "NuPhy"
    case external  // Any other external keyboard

    var displayName: String {
        switch self {
        case .builtin:  return "Built-in"
        case .nuphy:    return "NuPhy"
        case .external: return "External"
        }
    }

    var iconName: String {
        switch self {
        case .builtin:  return "keyboard"
        case .nuphy:    return "keyboard.fill"
        case .external: return "externaldrive.badge.plus"
        }
    }
}

// MARK: - HourlyAggregate (rolled-up stats — feeds dashboard)

struct HourlyAggregate: Codable {
    /// Floor of the hour (e.g. 2026-03-28 14:00:00)
    let hour: Date

    /// Per-app typing stats keyed by bundle ID
    var byApp: [String: AppTypingStats]

    /// Per-keyboard keystroke counts
    var byKeyboard: [KeyboardSource: Int]

    /// Total keystrokes for this hour
    var totalKeystrokes: Int

    init(hour: Date) {
        self.hour = hour
        self.byApp = [:]
        self.byKeyboard = [:]
        self.totalKeystrokes = 0
    }

    mutating func add(accumulator: ActiveTypingAccumulator) {
        let bundleID = accumulator.appBundleID

        // Update per-app stats
        var appStats = byApp[bundleID] ?? AppTypingStats()
        appStats.keystrokes += accumulator.keystrokeCount
        appStats.estimatedWords += accumulator.wordCount
        appStats.activeDuration += accumulator.duration
        byApp[bundleID] = appStats

        // Update per-keyboard
        byKeyboard[accumulator.keyboard, default: 0] += accumulator.keystrokeCount

        // Update total
        totalKeystrokes += accumulator.keystrokeCount
    }
}

// MARK: - AppTypingStats

struct AppTypingStats: Codable {
    var keystrokes: Int
    var estimatedWords: Int
    var activeDuration: TimeInterval

    init() {
        self.keystrokes = 0
        self.estimatedWords = 0
        self.activeDuration = 0
    }
}

// MARK: - ActiveTypingAccumulator (in-memory state)

/// In-memory accumulator for the current active typing session.
/// Finalized when: inactivity > 30s, app switch, or keyboard switch.
struct ActiveTypingAccumulator {
    let appBundleID: String
    let appName: String
    var windowTitle: String
    var keystrokeCount: Int
    var wordDelimiterCount: Int
    var startTime: Date
    var lastKeystrokeTime: Date
    var keyboard: KeyboardSource

    /// Word delimiter keycodes: space, return, enter (numpad)
    private static let wordDelimiterKeycodes: Set<Int64> = [49, 36, 76]

    /// Duration from first to last keystroke
    var duration: TimeInterval {
        lastKeystrokeTime.timeIntervalSince(startTime)
    }

    /// Actual word count based on space/return presses.
    /// Add 1 because the last word before a pause has no trailing delimiter.
    var wordCount: Int {
        keystrokeCount > 0 ? wordDelimiterCount + 1 : 0
    }

    init(
        appBundleID: String,
        appName: String,
        windowTitle: String,
        keyboard: KeyboardSource
    ) {
        self.appBundleID = appBundleID
        self.appName = appName
        self.windowTitle = windowTitle
        self.keystrokeCount = 0
        self.wordDelimiterCount = 0
        self.startTime = Date()
        self.lastKeystrokeTime = Date()
        self.keyboard = keyboard
    }

    mutating func recordKeystroke(keycode: Int64, windowTitle: String) {
        keystrokeCount += 1
        if Self.wordDelimiterKeycodes.contains(keycode) {
            wordDelimiterCount += 1
        }
        lastKeystrokeTime = Date()
        self.windowTitle = windowTitle
    }

    /// Returns true if this session has been idle for more than `threshold` seconds
    func isIdle(threshold: TimeInterval = 30) -> Bool {
        Date().timeIntervalSince(lastKeystrokeTime) > threshold
    }

    /// Returns true if sustained typing duration >= threshold (eligible for timeline burst)
    func meetsBurstThreshold(threshold: TimeInterval = 30) -> Bool {
        duration >= threshold
    }

    func toTypingSession() -> TypingSession {
        TypingSession(
            appBundleID: appBundleID,
            appName: appName,
            windowTitle: windowTitle.isEmpty ? nil : windowTitle,
            keystrokeCount: keystrokeCount,
            wordCount: wordCount,
            keyboard: keyboard,
            duration: duration
        )
    }
}

// MARK: - Typing Storage Container

/// Top-level container for encrypted typing data persistence
struct TypingStorage: Codable {
    /// Discrete typing bursts (>= 30s sustained typing)
    var sessions: [TypingSession]

    /// Hourly aggregates keyed by hour-floor date
    var hourlyAggregates: [Date: HourlyAggregate]

    init() {
        self.sessions = []
        self.hourlyAggregates = [:]
    }

    /// Returns the HourlyAggregate for a given date, creating one if absent
    mutating func aggregate(for date: Date, createIfAbsent: Bool = true) -> HourlyAggregate? {
        let calendar = Calendar.current
        let hourFloor = calendar.dateInterval(of: .hour, for: date)?.start ?? date

        if let existing = hourlyAggregates[hourFloor] {
            return existing
        }
        if createIfAbsent {
            let new = HourlyAggregate(hour: hourFloor)
            hourlyAggregates[hourFloor] = new
            return new
        }
        return nil
    }

    mutating func addSession(_ session: TypingSession) {
        // Only add to sessions array for the timeline.
        // Hourly aggregate is already updated by rollAccumulatorIntoHour()
        // which is called first in KeystrokeMonitor.finalizeAccumulator().
        sessions.insert(session, at: 0)
    }

    mutating func rollAccumulatorIntoHour(_ accumulator: ActiveTypingAccumulator, hour: Date) {
        let calendar = Calendar.current
        let hourFloor = calendar.dateInterval(of: .hour, for: hour)?.start ?? hour

        if var agg = hourlyAggregates[hourFloor] {
            agg.add(accumulator: accumulator)
            hourlyAggregates[hourFloor] = agg
        } else {
            var new = HourlyAggregate(hour: hourFloor)
            new.add(accumulator: accumulator)
            hourlyAggregates[hourFloor] = new
        }
    }

    // MARK: - Aggregation Queries

    /// Sessions within a date range
    func sessions(from startDate: Date, to endDate: Date) -> [TypingSession] {
        sessions.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }

    /// Sessions for a specific day
    func sessions(for date: Date) -> [TypingSession] {
        let calendar = Calendar.current
        return sessions.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
    }

    /// Aggregates for the last N days
    func aggregates(lastDays n: Int) -> [HourlyAggregate] {
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -n, to: now) else {
            return []
        }
        let startHour = calendar.dateInterval(of: .hour, for: startDate)?.start ?? startDate
        let endHour   = calendar.dateInterval(of: .hour, for: now)?.start ?? now

        return hourlyAggregates
            .filter { $0.key >= startHour && $0.key <= endHour }
            .map { $0.value }
            .sorted { $0.hour < $1.hour }
    }

    /// Daily totals from aggregates
    func dailyTypedWords(lastDays n: Int) -> [(date: Date, words: Int)] {
        let calendar = Calendar.current
        let now = Date()

        var result: [Date: Int] = [:]

        for i in 0..<n {
            guard let day = calendar.date(byAdding: .day, value: -i, to: now) else { continue }
            let dayStart = calendar.startOfDay(for: day)
            result[dayStart] = 0
        }

        for agg in aggregates(lastDays: n) {
            let dayStart = calendar.startOfDay(for: agg.hour)
            if result[dayStart] != nil {
                let aggWords = agg.byApp.values.reduce(0) { $0 + $1.estimatedWords }
                result[dayStart]! += aggWords
            }
        }

        return result
            .map { (date: $0.key, words: $0.value) }
            .sorted { $0.date < $1.date }
    }

    /// Average WPM per keyboard source
    func wpmByKeyboard() -> [KeyboardSource: Double] {
        var totals: [KeyboardSource: (words: Int, duration: TimeInterval)] = [:]

        for session in sessions {
            let existing = totals[session.keyboard] ?? (0, 0)
            totals[session.keyboard] = (
                existing.words + session.wordCount,
                existing.duration + session.duration
            )
        }

        return totals.mapValues { total in
            guard total.duration > 0 else { return 0 }
            return Double(total.words) / (total.duration / 60.0)
        }
    }

    /// Total typed words today
    var todayTypedWords: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return sessions
            .filter { calendar.isDate($0.timestamp, inSameDayAs: today) }
            .reduce(0) { $0 + $1.wordCount }
    }

    /// Average WPM across all typing sessions
    var averageTypedWpm: Double {
        let valid = sessions.filter { $0.duration > 0.1 }
        guard !valid.isEmpty else { return 0 }
        let total = valid.reduce(0.0) { $0 + $1.wpm }
        return total / Double(valid.count)
    }
}
