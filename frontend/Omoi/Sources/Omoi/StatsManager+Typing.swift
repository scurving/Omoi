import Foundation

// MARK: - Typing Stats

extension StatsManager {

    /// Reference to the typing storage for aggregated stats
    var typingStorage: TypingStorage {
        EncryptedStorageManager.shared.typingStorage
    }

    /// All typing sessions for the unified timeline
    var typingSessions: [TypingSession] {
        typingStorage.sessions
    }

    /// Typed words per day for the last 7 days (estimated from keystrokes)
    var typedWordsPerDay: [(date: Date, words: Int)] {
        typingStorage.dailyTypedWords(lastDays: 7)
    }

    /// Typed WPM per day for the last 7 days
    var typedWpmPerDay: [(date: Date, wpm: Double)] {
        let calendar = Calendar.current
        let now = Date()
        var result: [Date: (words: Int, duration: TimeInterval)] = [:]

        for i in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -i, to: now) else { continue }
            result[calendar.startOfDay(for: day)] = (0, 0)
        }

        let typingSessions = typingStorage.sessions
        for session in typingSessions {
            let dayStart = calendar.startOfDay(for: session.timestamp)
            if var existing = result[dayStart] {
                existing.words += session.wordCount
                existing.duration += session.duration
                result[dayStart] = existing
            }
        }

        return result.compactMap { date, data -> (date: Date, wpm: Double)? in
            guard data.duration > 0.1 else { return nil }
            let wpm = Double(data.words) / (data.duration / 60.0)
            return wpm.isFinite ? (date: date, wpm: wpm) : nil
        }.sorted { $0.date < $1.date }
    }

    /// Average WPM per keyboard source (built-in, NuPhy, external)
    var wpmByKeyboard: [(keyboard: KeyboardSource, avgWpm: Double)] {
        let byKeyboard = typingStorage.wpmByKeyboard()
        return byKeyboard.map { (keyboard: $0.key, avgWpm: $0.value) }
            .sorted { $0.avgWpm > $1.avgWpm }
    }

    /// Per-app typing stats (total typed words and avg WPM per app)
    var typingByApp: [(appName: String, keystrokes: Int, estimatedWords: Int, avgWpm: Double)] {
        let typingSessions = typingStorage.sessions
        let grouped = Dictionary(grouping: typingSessions) { $0.appName }
        return grouped.compactMap { appName, sessions -> (appName: String, keystrokes: Int, estimatedWords: Int, avgWpm: Double)? in
            let totalKeys     = sessions.reduce(0) { $0 + $1.keystrokeCount }
            let totalWords    = sessions.reduce(0) { $0 + $1.wordCount }
            let totalDuration = sessions.reduce(0.0) { $0 + $1.duration }
            guard totalDuration > 0.1 else { return nil }
            let avgWpm = Double(totalWords) / (totalDuration / 60.0)
            return (appName: appName, keystrokes: totalKeys, estimatedWords: totalWords, avgWpm: avgWpm.isFinite ? avgWpm : 0)
        }.sorted { $0.estimatedWords > $1.estimatedWords }
    }

    /// Daily input mode ratio: (voice words, typed words) as percentages
    var inputModeRatio: [(date: Date, voicePercent: Double, typedPercent: Double)] {
        let calendar = Calendar.current
        let now = Date()
        var result: [Date: (voice: Int, typed: Int)] = [:]

        for i in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -i, to: now) else { continue }
            result[calendar.startOfDay(for: day)] = (0, 0)
        }

        // Voice words
        for session in sessions {
            let dayStart = calendar.startOfDay(for: session.timestamp)
            if var existing = result[dayStart] {
                existing.voice += session.wordCount
                result[dayStart] = existing
            }
        }

        // Typed words
        let typedDaily = typingStorage.dailyTypedWords(lastDays: 7)
        for entry in typedDaily {
            if var existing = result[entry.date] {
                existing.typed = entry.words
                result[entry.date] = existing
            }
        }

        return result.map { date, data -> (date: Date, voicePercent: Double, typedPercent: Double) in
            let total = data.voice + data.typed
            if total == 0 {
                return (date: date, voicePercent: 0, typedPercent: 0)
            }
            return (date: date,
                    voicePercent: Double(data.voice) / Double(total) * 100,
                    typedPercent: Double(data.typed) / Double(total) * 100)
        }.sorted { $0.date < $1.date }
    }

    /// Combined words per day (voice + typed) for stacked charts
    var combinedWordsPerDay: [(date: Date, voiceWords: Int, typedWords: Int)] {
        let calendar = Calendar.current
        let now = Date()
        var result: [Date: (voice: Int, typed: Int)] = [:]

        for i in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -i, to: now) else { continue }
            result[calendar.startOfDay(for: day)] = (0, 0)
        }

        for session in sessions {
            let dayStart = calendar.startOfDay(for: session.timestamp)
            if var existing = result[dayStart] {
                existing.voice += session.wordCount
                result[dayStart] = existing
            }
        }

        for entry in typedWordsPerDay {
            if var existing = result[entry.date] {
                existing.typed = entry.words
                result[entry.date] = existing
            }
        }

        return result
            .map { (date: $0.key, voiceWords: $0.value.voice, typedWords: $0.value.typed) }
            .sorted { $0.date < $1.date }
    }

    /// Combined WPM trend per day: voice WPM + typed WPM (by keyboard)
    var combinedWpmTrend: [(date: Date, voiceWpm: Double, typedBuiltinWpm: Double, typedNuphyWpm: Double)] {
        let calendar = Calendar.current
        let now = Date()
        var result: [Date: (voice: (words: Int, duration: TimeInterval), builtin: (words: Int, duration: TimeInterval), nuphy: (words: Int, duration: TimeInterval))] = [:]

        for i in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: -i, to: now) else { continue }
            result[calendar.startOfDay(for: day)] = (
                voice: (0, 0),
                builtin: (0, 0),
                nuphy: (0, 0)
            )
        }

        // Voice sessions
        for session in sessions {
            let dayStart = calendar.startOfDay(for: session.timestamp)
            if var existing = result[dayStart] {
                existing.voice.words += session.wordCount
                existing.voice.duration += session.effectiveDuration
                result[dayStart] = existing
            }
        }

        // Typing sessions
        for session in typingStorage.sessions {
            let dayStart = calendar.startOfDay(for: session.timestamp)
            if var existing = result[dayStart] {
                switch session.keyboard {
                case .builtin:
                    existing.builtin.words += session.wordCount
                    existing.builtin.duration += session.duration
                case .nuphy:
                    existing.nuphy.words += session.wordCount
                    existing.nuphy.duration += session.duration
                case .external:
                    // External treated same as builtin for chart purposes
                    existing.builtin.words += session.wordCount
                    existing.builtin.duration += session.duration
                }
                result[dayStart] = existing
            }
        }

        return result.compactMap { date, data -> (date: Date, voiceWpm: Double, typedBuiltinWpm: Double, typedNuphyWpm: Double)? in
            let voiceWpm    = data.voice.duration > 0.1   ? Double(data.voice.words)   / (data.voice.duration / 60.0)   : 0
            let builtinWpm  = data.builtin.duration > 0.1 ? Double(data.builtin.words) / (data.builtin.duration / 60.0) : 0
            let nuphyWpm    = data.nuphy.duration > 0.1   ? Double(data.nuphy.words)   / (data.nuphy.duration / 60.0)   : 0
            return (date: date,
                    voiceWpm: voiceWpm.isFinite ? voiceWpm : 0,
                    typedBuiltinWpm: builtinWpm.isFinite ? builtinWpm : 0,
                    typedNuphyWpm: nuphyWpm.isFinite ? nuphyWpm : 0)
        }.sorted { $0.date < $1.date }
    }

    /// Today's typed word count
    var todayTypedWords: Int {
        typingStorage.todayTypedWords
    }

    /// Average typed WPM across all typing sessions
    var averageTypedWpm: Double {
        typingStorage.averageTypedWpm
    }

    /// Combined total words today (voice + typed)
    var totalWordsToday: Int {
        todayWords() + todayTypedWords
    }

    /// Combined average WPM today (voice + typed, weighted)
    var combinedAverageWpmToday: Double {
        let validVoice = sessions.filter { $0.effectiveDuration > 0.1 }
        let totalVoiceWords = validVoice.reduce(0) { $0 + $1.wordCount }
        let totalVoiceDuration = validVoice.reduce(0.0) { $0 + $1.effectiveDuration }
        let voiceWpm = totalVoiceDuration > 0 ? Double(totalVoiceWords) / (totalVoiceDuration / 60.0) : 0

        // Typed WPM today
        let typedToday = typingStorage.sessions.filter {
            Calendar.current.isDate($0.timestamp, inSameDayAs: Date())
        }
        let totalTypedWords = typedToday.reduce(0) { $0 + $1.wordCount }
        let totalTypedDuration = typedToday.reduce(0.0) { $0 + $1.duration }
        let typedWpm = totalTypedDuration > 0 ? Double(totalTypedWords) / (totalTypedDuration / 60.0) : 0

        // Combined weighted average
        let totalWords = totalVoiceWords + totalTypedWords
        guard totalWords > 0 else { return 0 }
        let combined = (voiceWpm * Double(totalVoiceWords) + typedWpm * Double(totalTypedWords)) / Double(totalWords)
        return combined.isFinite ? combined : 0
    }
}
