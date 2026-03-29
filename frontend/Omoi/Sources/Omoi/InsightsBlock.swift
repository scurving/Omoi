import SwiftUI

// MARK: - Insights Block Extension

extension DashboardView {

    var insightsBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with regenerate button
            HStack {
                Text("INSIGHTS")
                    .font(OmoiFont.label(size: 11))
                    .foregroundStyle(Color.omoiMuted)

                Spacer()

                Button(action: { generateInsights() }) {
                    HStack(spacing: 4) {
                        if isLoadingInsights {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10))
                        }
                        Text(isLoadingInsights ? "THINKING" : "REGENERATE")
                            .font(OmoiFont.label(size: 10))
                    }
                    .foregroundStyle(Color.omoiTeal)
                }
                .buttonStyle(.plain)
                .disabled(isLoadingInsights)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.omoiDarkGray)

            // Insight bullets
            if llmInsights.isEmpty && !isLoadingInsights {
                Text("Tap regenerate to get AI-powered insights about your patterns.")
                    .font(OmoiFont.body(size: 12))
                    .foregroundStyle(Color.omoiMuted)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.omoiDarkGray)
            } else {
                ForEach(Array(llmInsights.enumerated()), id: \.offset) { index, insight in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(bulletColor(for: index))
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        Text(insight)
                            .font(OmoiFont.body(size: 12))
                            .foregroundStyle(Color.omoiOffWhite)
                            .lineLimit(3)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.omoiDarkGray)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(Color.omoiGray.opacity(0.3)),
                        alignment: .top
                    )
                }
            }
        }
    }

    func bulletColor(for index: Int) -> Color {
        let colors: [Color] = [.omoiTeal, .omoiOrange, .omoiPurple, .omoiGreen]
        return colors[index % colors.count]
    }

    func generateInsights() {
        isLoadingInsights = true

        Task {
            let voiceWords = thisWeekVoiceWords()
            let typedWords = thisWeekTypedWords()
            let totalWords = voiceWords + typedWords
            let topApps = allAppStats.prefix(5).map { "\($0.appName): \($0.voiceWords + $0.typedWords) words" }.joined(separator: ", ")
            let kbStats = statsManager.wpmByKeyboard.map { "\($0.keyboard.displayName) at \(Int($0.avgWpm)) WPM" }.joined(separator: ", ")
            let voiceWpm = statsManager.averageWPM
            let lastWeek = lastWeekWords()
            let weekChange = lastWeek > 0 ? Int((Double(thisWeekWords() - lastWeek) / Double(lastWeek)) * 100) : 0

            let prompt = """
            You are a concise productivity analyst. Given this week's data, produce exactly 4 bullet points. Each bullet is ONE sentence, max 20 words. No emojis. Be specific with numbers, apps, keyboards, or patterns.

            Cover: 1) Volume pattern 2) Speed observation 3) App focus 4) Trend or anomaly

            DATA:
            This week: \(totalWords) words (\(voiceWords) voice, \(typedWords) typed)
            Week-over-week: \(weekChange > 0 ? "+" : "")\(weekChange)% vs last week (\(lastWeek) words)
            Voice WPM: \(Int(voiceWpm))
            \(kbStats.isEmpty ? "No keyboard data yet" : "Keyboards: " + kbStats)
            Top apps: \(topApps.isEmpty ? "No app data yet" : topApps)
            Peak hour: \(filteredPeakHour.map { formatHour($0.hour) } ?? "unknown")

            Return ONLY 4 lines, one per bullet. No numbering, no dashes, no prefixes.
            """

            llmInsights = await OllamaService.shared.generateInsightBullets(context: prompt)
            isLoadingInsights = false
        }
    }
}
