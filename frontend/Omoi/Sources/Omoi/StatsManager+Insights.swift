import Foundation

// MARK: - Performance Insights

extension StatsManager {

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

        // Fastest app insight (voice)
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

        // Keyboard comparison insight (typed)
        if wpmByKeyboard.count >= 2 {
            let sorted = wpmByKeyboard.sorted { $0.avgWpm > $1.avgWpm }
            if let fastest = sorted.first, let slowest = sorted.last, slowest.avgWpm > 0 {
                let diff = ((fastest.avgWpm - slowest.avgWpm) / slowest.avgWpm) * 100
                if diff.isFinite && abs(diff) > 10 {
                    insights.append(PerformanceInsight(
                        icon: "keyboard.fill",
                        title: "Keyboard Comparison",
                        message: "You type \(Int(abs(diff)))% \(diff > 0 ? "faster" : "slower") on \(fastest.keyboard.displayName) than \(slowest.keyboard.displayName).",
                        type: .speed
                    ))
                }
            }
        }

        // Mode ratio insight
        if let todayRatio = inputModeRatio.last, (todayRatio.voicePercent + todayRatio.typedPercent) > 0 {
            let dominant = todayRatio.voicePercent > todayRatio.typedPercent ? "voice" : "typed"
            let dominantPercent = max(todayRatio.voicePercent, todayRatio.typedPercent)
            if dominantPercent > 60 {
                insights.append(PerformanceInsight(
                    icon: "arrow.left.arrow.right",
                    title: "Mode Shift",
                    message: "Today was \(Int(dominantPercent))% \(dominant). Your input mix varies day to day.",
                    type: .habit
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

        return insights
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

        if text.contains("?") {
            suggestions.append("question")
        }
        if text.contains("todo") || text.contains("to do") || text.contains("need to") {
            suggestions.append("action")
        }
        if text.contains("important") || text.contains("urgent") || text.contains("asap") {
            suggestions.append("important")
        }

        return Array(Set(suggestions)).filter { !session.tags.contains($0) }
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
