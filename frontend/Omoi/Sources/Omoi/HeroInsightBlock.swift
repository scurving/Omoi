import SwiftUI

// MARK: - Hero Insight Block Extension

extension DashboardView {

    @ViewBuilder
    var heroInsightBlock: some View {
        VStack(spacing: 0) {
            // Presence Score
            VStack(spacing: 8) {
                Text("P R E S E N C E   S C O R E")
                    .font(OmoiFont.label(size: 11))
                    .foregroundStyle(Color.omoiMuted)
                    .kerning(2)

                Text(formatNumber(filteredVoiceWords() + filteredTypedWords()))
                    .font(.system(size: 64, weight: .light, design: .rounded))
                    .foregroundStyle(Color.omoiWhite)

                Text(presenceSubtitle())
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color.omoiMuted)
            }
            .padding(.top, 40)
            .padding(.bottom, 24)

            // Time range tabs
            HStack(spacing: 24) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Button(action: { selectedTimeRange = range }) {
                        VStack(spacing: 4) {
                            Text(range.rawValue)
                                .font(OmoiFont.label(size: 12))
                                .foregroundStyle(selectedTimeRange == range ? Color.omoiWhite : Color.omoiMuted)
                            Rectangle()
                                .fill(selectedTimeRange == range ? Color.omoiOrange : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 24)

            // Divider
            Rectangle()
                .fill(Color.omoiGray.opacity(0.3))
                .frame(height: 1)
                .padding(.horizontal, 40)

            // 2x2 stat grid
            HStack(alignment: .top, spacing: 0) {
                // Left column
                VStack(alignment: .leading, spacing: 24) {
                    presenceStat(label: "V O C A L   F L O W", value: formatNumber(filteredVoiceWords()), color: Color.omoiOrange)
                    presenceStat(label: "C A D E N C E", value: "\(Int(filteredVoiceWpm()))", unit: "WPM", color: Color.omoiOrange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right column
                VStack(alignment: .leading, spacing: 24) {
                    presenceStat(label: "T A C T I L E   F O C U S", value: formatNumber(filteredTypedWords()), color: Color.omoiTeal)
                    presenceStat(label: "P R E C I S I O N", value: "\(Int(filteredTypedWpm()))", unit: "WPM", color: Color.omoiTeal)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
        }
        .background(Color.omoiDarkGray)
    }

    @ViewBuilder
    func presenceStat(label: String, value: String, unit: String? = nil, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(OmoiFont.label(size: 9))
                .foregroundStyle(Color.omoiMuted)
                .kerning(1.5)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .light, design: .rounded))
                    .foregroundStyle(Color.omoiWhite)
                if let unit = unit {
                    Text(unit)
                        .font(OmoiFont.label(size: 10))
                        .foregroundStyle(Color.omoiMuted)
                }
            }

            Rectangle()
                .fill(color)
                .frame(height: 2)
                .frame(maxWidth: 100)
        }
    }

    func filteredVoiceWpm() -> Double {
        let sessions = filteredVoiceSessions.filter { $0.effectiveDuration > 0.1 }
        guard !sessions.isEmpty else { return 0 }
        let totalWords = sessions.reduce(0) { $0 + $1.wordCount }
        let totalDuration = sessions.reduce(0.0) { $0 + $1.effectiveDuration }
        guard totalDuration > 0 else { return 0 }
        let wpm = Double(totalWords) / (totalDuration / 60.0)
        return wpm.isFinite ? wpm : 0
    }

    func filteredTypedWpm() -> Double {
        let sessions = filteredTypingSessions.filter { $0.duration > 0.1 }
        guard !sessions.isEmpty else { return 0 }
        let totalWords = sessions.reduce(0) { $0 + $1.wordCount }
        let totalDuration = sessions.reduce(0.0) { $0 + $1.duration }
        guard totalDuration > 0 else { return 0 }
        let wpm = Double(totalWords) / (totalDuration / 60.0)
        return wpm.isFinite ? wpm : 0
    }

    func filteredVoiceWords() -> Int {
        filteredVoiceSessions.reduce(0) { $0 + $1.wordCount }
    }

    func filteredTypedWords() -> Int {
        let storage = EncryptedStorageManager.shared.typingStorage
        switch selectedTimeRange {
        case .today:
            return storage.dailyTypedWords(lastDays: 1).first?.words ?? 0
        case .week:
            return storage.dailyTypedWords(lastDays: 7).reduce(0) { $0 + $1.words }
        case .allTime:
            return storage.dailyTypedWords(lastDays: 365).reduce(0) { $0 + $1.words }
        }
    }

    func presenceSubtitle() -> String {
        let total = filteredVoiceWords() + filteredTypedWords()
        if total == 0 { return "Awaiting your first words" }
        let voice = filteredVoiceWords()
        let typed = filteredTypedWords()
        if voice > typed * 2 { return "Vocal flow dominant today" }
        if typed > voice * 2 { return "Deep tactile focus today" }
        return "Harmonious output achieved today"
    }
}
