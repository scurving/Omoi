import SwiftUI
import Charts

// MARK: - Omoi Dashboard
// Brutalist design: sharp edges, high contrast, monospace stats

struct DashboardView: View {
    enum TimeRange: String, CaseIterable {
        case today = "Today"
        case week = "Week"
        case allTime = "Cycle"
    }

    @ObservedObject var statsManager: StatsManager
    @State var selectedDate: Date? = nil
    @State var showingDetailModal = false
    @State var showingClearAlert = false
    @State var showingExportSheet = false
    @State var selectedTagFilter: String? = nil
    @State var selectedTimeRange: TimeRange = .today
    @State var hoveredHour: Int? = nil
    @State var hoveredDay: Date? = nil
    @State var hoveredMonth: Date? = nil
    @State var llmInsights: [String] = []
    @State var isLoadingInsights = false

    var body: some View {
        VStack(spacing: 0) {
            // Quick Actions Toolbar
            if !statsManager.sessions.isEmpty {
                quickActionsToolbar
            }

            // Tag filter chips
            if !statsManager.allTags.isEmpty {
                tagFilterBar
            }

            ScrollView {
                VStack(spacing: 0) {
                    // Show empty state if no sessions
                    if statsManager.sessions.isEmpty {
                        emptyStateView
                    }

                    // Only show stats if we have data
                    if !statsManager.sessions.isEmpty {
                        statsContent
                    }
                }
            }
        }
        .omoiBackground()
        .sheet(isPresented: $showingDetailModal) {
            if let date = selectedDate {
                SessionDetailModal(
                    statsManager: statsManager,
                    date: date,
                    isPresented: $showingDetailModal
                )
            }
        }
        .alert("Clear All History?", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                statsManager.clearHistory()
            }
        } message: {
            Text("This will permanently delete all \(statsManager.sessions.count) sessions. This action cannot be undone.")
        }
    }

    @ViewBuilder
    var statsContent: some View {
        VStack(spacing: 1) {
            // Hero insight block (includes time range tabs)
            heroInsightBlock

            // Activity visualization (adapts to time range)
            switch selectedTimeRange {
            case .today:
                activityHeatmap
            case .week:
                weeklyHeatmap
            case .allTime:
                monthlyHeatmap
            }

            // Peak Hour Block
            if let peak = filteredPeakHour {
                peakHourCard(hour: peak.hour, words: peak.words)
            }

            // App Stats Breakdown (words + WPM per app)
            if !allAppStats.isEmpty {
                appWPMSection
            }

            // LLM Insights
            insightsBlock
        }
        .onAppear {
            if llmInsights.isEmpty {
                generateInsights()
            }
        }
    }

    // MARK: - Tag Filter Bar
    @ViewBuilder
    var tagFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 1) {
                // All button
                TagChip(
                    title: "ALL",
                    isSelected: selectedTagFilter == nil,
                    action: { selectedTagFilter = nil }
                )

                // Tag chips
                ForEach(statsManager.allTags, id: \.self) { tag in
                    TagChip(
                        title: tag.uppercased(),
                        isSelected: selectedTagFilter == tag,
                        action: { selectedTagFilter = tag }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.omoiDarkGray)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.omoiGray),
            alignment: .bottom
        )
    }

    // MARK: - Quick Actions Toolbar
    @ViewBuilder
    var quickActionsToolbar: some View {
        HStack(spacing: 16) {
            Text("OMOI")
                .font(OmoiFont.brand(size: 18))
                .foregroundStyle(Color.omoiWhite)

            Spacer()

            // Export
            Button(action: { exportData() }) {
                Text("EXPORT")
                    .font(OmoiFont.label(size: 11))
                    .foregroundStyle(Color.omoiLightGray)
            }
            .buttonStyle(.plain)

            // Clear
            Button(action: { showingClearAlert = true }) {
                Text("CLEAR")
                    .font(OmoiFont.label(size: 11))
                    .foregroundStyle(Color.omoiOrange)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.omoiDarkGray)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.omoiGray),
            alignment: .bottom
        )
    }

    // MARK: - Empty State View
    @ViewBuilder
    var emptyStateView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                // Brutalist waveform icon
                Image(systemName: "waveform")
                    .font(.system(size: 64, weight: .ultraLight))
                    .foregroundStyle(Color.omoiTeal)

                // Main message
                VStack(spacing: 8) {
                    Text("READY")
                        .font(OmoiFont.stat)
                        .foregroundStyle(Color.omoiWhite)

                    Text("Start recording to see your data")
                        .font(OmoiFont.body(size: 14))
                        .foregroundStyle(Color.omoiMuted)
                }

                // Shortcut display
                HStack(spacing: 8) {
                    KeyCapView(symbol: "⌘")
                    KeyCapView(symbol: "⇧")
                    KeyCapView(symbol: "R")
                }
            }

            Spacer()

            // Sample preview - brutalist blocks
            VStack(spacing: 1) {
                HStack(spacing: 1) {
                    SampleStatCard(title: "WORDS", value: "—")
                    SampleStatCard(title: "WPM", value: "—")
                }
            }
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Weekly Narrative Block
    // MARK: - Peak Hour Block
    @ViewBuilder
    func peakHourCard(hour: Int, words: Int) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PEAK HOUR")
                    .font(OmoiFont.label(size: 11))
                    .foregroundStyle(Color.omoiMuted)

                Text(peakHourDescription(hour: hour))
                    .font(OmoiFont.body(size: 12))
                    .foregroundStyle(Color.omoiLightGray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatHour(hour))
                    .font(OmoiFont.stat)
                    .foregroundStyle(Color.omoiTeal)

                Text("\(formatNumber(words)) words")
                    .font(OmoiFont.mono(size: 12))
                    .foregroundStyle(Color.omoiMuted)
            }
        }
        .padding(20)
        .background(Color.omoiDarkGray)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.omoiGray),
            alignment: .top
        )
    }

    // MARK: - App Stats Breakdown Section
    @ViewBuilder
    var appWPMSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text("BY APP")
                    .font(OmoiFont.label(size: 11))
                    .foregroundStyle(Color.omoiMuted)

                Spacer()

                // Legend
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Circle().fill(Color.omoiOrange).frame(width: 6, height: 6)
                        Text("VOICE").font(OmoiFont.label(size: 8)).foregroundStyle(Color.omoiMuted)
                    }
                    HStack(spacing: 3) {
                        Circle().fill(Color.omoiTeal).frame(width: 6, height: 6)
                        Text("TYPED").font(OmoiFont.label(size: 8)).foregroundStyle(Color.omoiMuted)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.omoiDarkGray)

            // App rows with voice + typed breakdown
            ForEach(Array(allAppStats.prefix(5).enumerated()), id: \.offset) { index, appData in
                HStack(spacing: 12) {
                    // Rank indicator
                    Text("\(index + 1)")
                        .font(OmoiFont.mono(size: 14))
                        .foregroundStyle(index == 0 ? Color.omoiTeal : Color.omoiMuted)
                        .frame(width: 20)

                    // App name
                    Text(appData.appName)
                        .font(OmoiFont.body(size: 14))
                        .foregroundStyle(Color.omoiOffWhite)
                        .lineLimit(1)

                    Spacer()

                    // Voice words
                    HStack(spacing: 4) {
                        Text(formatWordCount(appData.voiceWords))
                            .font(OmoiFont.mono(size: 14))
                            .foregroundStyle(Color.omoiOrange)
                    }
                    .frame(width: 55, alignment: .trailing)

                    // Typed words
                    HStack(spacing: 4) {
                        Text(formatWordCount(appData.typedWords))
                            .font(OmoiFont.mono(size: 14))
                            .foregroundStyle(Color.omoiTeal)
                    }
                    .frame(width: 55, alignment: .trailing)

                    // Total / WPM
                    HStack(spacing: 4) {
                        Text("\(Int(appData.avgWpm))")
                            .font(OmoiFont.mono(size: 16))
                            .foregroundStyle(Color.omoiOffWhite)
                        Text("WPM")
                            .font(OmoiFont.label(size: 9))
                            .foregroundStyle(Color.omoiMuted)
                    }
                    .frame(width: 70, alignment: .trailing)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.omoiDarkGray)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color.omoiGray),
                    alignment: .top
                )
            }
        }
    }

    // MARK: - Filtered Sessions

    var filteredVoiceSessions: [TranscriptionSession] {
        switch selectedTimeRange {
        case .today:
            return statsManager.sessions.filter { Calendar.current.isDateInToday($0.timestamp) }
        case .week:
            guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else {
                return statsManager.sessions
            }
            return statsManager.sessions.filter { $0.timestamp >= weekAgo }
        case .allTime:
            return statsManager.sessions
        }
    }

    var filteredTypingSessions: [TypingSession] {
        switch selectedTimeRange {
        case .today:
            return statsManager.typingSessions.filter { Calendar.current.isDateInToday($0.timestamp) }
        case .week:
            guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else {
                return statsManager.typingSessions
            }
            return statsManager.typingSessions.filter { $0.timestamp >= weekAgo }
        case .allTime:
            return statsManager.typingSessions
        }
    }

    var filteredPeakHour: (hour: Int, words: Int)? {
        let calendar = Calendar.current
        var hourlyWords: [Int: Int] = [:]

        for session in filteredVoiceSessions {
            let hour = calendar.component(.hour, from: session.timestamp)
            hourlyWords[hour, default: 0] += session.wordCount
        }

        for session in filteredTypingSessions {
            let hour = calendar.component(.hour, from: session.timestamp)
            hourlyWords[hour, default: 0] += session.wordCount
        }

        guard let peak = hourlyWords.max(by: { $0.value < $1.value }) else { return nil }
        return (hour: peak.key, words: peak.value)
    }

    /// Combined voice + typed stats per app
    var allAppStats: [(appName: String, voiceWords: Int, typedWords: Int, avgWpm: Double)] {
        // Voice stats by app
        let voiceGroups = Dictionary(grouping: filteredVoiceSessions) { $0.targetAppName ?? "Unknown" }
        var voiceByApp: [String: (words: Int, duration: TimeInterval)] = [:]
        for (app, sessions) in voiceGroups {
            let words = sessions.reduce(0) { $0 + $1.wordCount }
            let duration = sessions.reduce(0.0) { $0 + $1.effectiveDuration }
            voiceByApp[app] = (words, duration)
        }

        // Typed stats by app
        let typedGroups = Dictionary(grouping: filteredTypingSessions) { $0.appName }
        var typedByApp: [String: (words: Int, duration: TimeInterval)] = [:]
        for (app, sessions) in typedGroups {
            let words = sessions.reduce(0) { $0 + $1.wordCount }
            let duration = sessions.reduce(0.0) { $0 + $1.duration }
            typedByApp[app] = (words, duration)
        }

        // Merge all apps
        var allApps = Set(voiceByApp.keys)
        allApps.formUnion(typedByApp.keys)

        return allApps.compactMap { appName -> (appName: String, voiceWords: Int, typedWords: Int, avgWpm: Double)? in
            let v = voiceByApp[appName] ?? (0, 0)
            let t = typedByApp[appName] ?? (0, 0)
            let totalWords = v.words + t.words
            let totalDuration = v.duration + t.duration
            guard totalDuration > 0.1 else { return nil }
            let avgWpm = Double(totalWords) / (totalDuration / 60.0)
            return (appName: appName, voiceWords: v.words, typedWords: t.words,
                    avgWpm: avgWpm.isFinite ? avgWpm : 0)
        }.sorted { $0.voiceWords + $0.typedWords > $1.voiceWords + $1.typedWords }
    }

    func formatWordCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
        return "\(count)"
    }

    // MARK: - Helper: Stat Card with Split (Brutalist)
    @ViewBuilder
    func statCardWithSplit(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String,
        trend: String?,
        trendText: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row with trend
            HStack {
                Text(title)
                    .font(OmoiFont.label(size: 11))
                    .foregroundStyle(Color.omoiMuted)

                Spacer()

                if let trend = trend {
                    Image(systemName: trend)
                        .font(.system(size: 10))
                        .foregroundStyle(trend == "arrow.up.right" ? Color.omoiGreen : Color.omoiOrange)
                }
            }

            // Value - big monospace
            Text(value)
                .font(OmoiFont.stat)
                .foregroundStyle(Color.omoiWhite)

            // Subtitle (voice / typed split)
            if let subtitle = subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(OmoiFont.caption)
                    .foregroundStyle(Color.omoiMuted)
                    .lineLimit(1)
            }

            // Trend text if present
            if let trendText = trendText {
                Text(trendText)
                    .font(OmoiFont.caption)
                    .foregroundStyle(Color.omoiMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.omoiDarkGray)
    }

    // MARK: - Helper: Stat Card with Trend (Brutalist)
    @ViewBuilder
    func statCardWithTrend(
        title: String,
        value: String,
        icon: String,
        trend: String?,
        trendText: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(OmoiFont.label(size: 11))
                    .foregroundStyle(Color.omoiMuted)

                Spacer()

                if let trend = trend {
                    Image(systemName: trend)
                        .font(.system(size: 10))
                        .foregroundStyle(trend == "arrow.up.right" ? Color.omoiGreen : Color.omoiOrange)
                }
            }

            Text(value)
                .font(OmoiFont.stat)
                .foregroundStyle(Color.omoiWhite)

            if let trendText = trendText {
                Text(trendText)
                    .font(OmoiFont.caption)
                    .foregroundStyle(Color.omoiMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.omoiDarkGray)
    }

    func trendForTotalWords() -> String? {
        let thisWeek = thisWeekWords()
        let lastWeek = lastWeekWords()

        guard lastWeek > 0 else { return nil }
        return thisWeek >= lastWeek ? "arrow.up.right" : "arrow.down.right"
    }

    func trendTextForTotalWords() -> String? {
        let thisWeek = thisWeekWords()
        let lastWeek = lastWeekWords()

        guard lastWeek > 0 else { return nil }
        let change = abs(Int((Double(thisWeek - lastWeek) / Double(lastWeek)) * 100))
        return "\(change)% \(thisWeek >= lastWeek ? "up" : "down")"
    }

    func weekTrend() -> String? {
        let thisWeek = thisWeekWords()
        let lastWeek = lastWeekWords()

        guard lastWeek > 0 else { return nil }
        return thisWeek >= lastWeek ? "arrow.up.right" : "arrow.down.right"
    }

    func weekTrendText() -> String? {
        let thisWeek = thisWeekWords()
        let lastWeek = lastWeekWords()

        guard lastWeek > 0 else { return nil }
        let change = abs(Int((Double(thisWeek - lastWeek) / Double(lastWeek)) * 100))
        return "vs last week"
    }

    // MARK: - Utilities

    func thisWeekWords() -> Int {
        thisWeekVoiceWords() + thisWeekTypedWords()
    }

    func thisWeekVoiceWords() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        return statsManager.sessions
            .filter { $0.timestamp >= weekAgo }
            .reduce(0) { $0 + $1.wordCount }
    }

    func thisWeekTypedWords() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        return statsManager.typingSessions
            .filter { $0.timestamp >= weekAgo }
            .reduce(0) { $0 + $1.wordCount }
    }

    func lastWeekWords() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now) ?? now

        return statsManager.sessions
            .filter { $0.timestamp >= twoWeeksAgo && $0.timestamp < weekAgo }
            .reduce(0) { $0 + $1.wordCount }
    }

    func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000.0)
        }
        return "\(number)"
    }

    func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    func formatHour(_ hour: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(displayHour) \(period)"
    }

    func peakHourDescription(hour: Int) -> String {
        let timeOfDay: String
        switch hour {
        case 5..<12:
            timeOfDay = "morning"
        case 12..<17:
            timeOfDay = "afternoon"
        case 17..<21:
            timeOfDay = "evening"
        default:
            timeOfDay = "late night"
        }
        return "Most productive in the \(timeOfDay)"
    }

    func rankIcon(for index: Int) -> String {
        switch index {
        case 0: return "medal.fill"
        case 1: return "crown.fill"
        case 2: return "star.fill"
        default: return "app.fill"
        }
    }

    func rankColor(for index: Int) -> Color {
        switch index {
        case 0: return Color.yellow
        case 1: return Color.orange
        case 2: return Color.omoiPurple
        default: return Color.omoiTeal
        }
    }

    func weekComparisonInsight() -> String {
        let thisWeekTotal = statsManager.weekOverWeekComparison.reduce(0) { $0 + $1.thisWeek }
        let lastWeekTotal = statsManager.weekOverWeekComparison.reduce(0) { $0 + $1.lastWeek }

        guard lastWeekTotal > 0 else {
            return "Building your first full week of data"
        }

        let change = thisWeekTotal - lastWeekTotal
        let percentChange = Int((Double(change) / Double(lastWeekTotal)) * 100)

        if change > 0 {
            return "Up \(abs(percentChange))% from last week"
        } else if change < 0 {
            return "Down \(abs(percentChange))% from last week"
        } else {
            return "Consistent week-over-week"
        }
    }

    func exportData() {
        let csvContent = generateCSV()
        let savePanel = NSSavePanel()
        savePanel.title = "Export Analytics"
        savePanel.nameFieldStringValue = "omoi-analytics-\(Date().timeIntervalSince1970).csv"
        savePanel.allowedContentTypes = [.commaSeparatedText]

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try csvContent.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Export failed: \(error)")
                }
            }
        }
    }

    func generateCSV() -> String {
        var csv = "Date,Time,App,Words,Duration,WPM,Text\n"

        for session in statsManager.sessions.sorted(by: { $0.timestamp > $1.timestamp }) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"

            let date = dateFormatter.string(from: session.timestamp)
            let time = timeFormatter.string(from: session.timestamp)
            let app = session.targetAppName ?? "Unknown"
            let words = session.wordCount
            let duration = String(format: "%.2f", session.duration)
            let wpm = session.duration > 0 ? Int(Double(session.wordCount) / (session.duration / 60.0)) : 0
            let text = session.text.replacingOccurrences(of: "\"", with: "\"\"")

            csv += "\(date),\(time),\(app),\(words),\(duration),\(wpm),\"\(text)\"\n"
        }

        return csv
    }
}

// MARK: - Empty State Components

struct KeyCapView: View {
    let symbol: String

    var body: some View {
        Text(symbol)
            .font(OmoiFont.mono(size: 16))
            .foregroundStyle(Color.omoiWhite)
            .frame(width: 32, height: 32)
            .background(Color.omoiGray)
            .overlay(
                Rectangle()
                    .stroke(Color.omoiMuted, lineWidth: 1)
            )
    }
}

struct SampleStatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(OmoiFont.label(size: 11))
                .foregroundStyle(Color.omoiMuted)

            Text(value)
                .font(OmoiFont.stat)
                .foregroundStyle(Color.omoiGray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.omoiDarkGray)
    }
}

// MARK: - Session Detail Modal

struct SessionDetailModal: View {
    @ObservedObject var statsManager: StatsManager
    let date: Date
    @Binding var isPresented: Bool

    var sessionsForDate: [TranscriptionSession] {
        let calendar = Calendar.current
        return statsManager.sessions.filter { session in
            calendar.isDate(session.timestamp, inSameDayAs: date)
        }.sorted { $0.timestamp > $1.timestamp }
    }

    var totalWords: Int {
        sessionsForDate.reduce(0) { $0 + $1.wordCount }
    }

    var avgWPM: Double {
        let validSessions = sessionsForDate.filter { $0.duration > 0 }
        guard !validSessions.isEmpty else { return 0 }
        let totalWPM = validSessions.reduce(0.0) { sum, session in
            sum + (Double(session.wordCount) / (session.duration / 60.0))
        }
        return totalWPM / Double(validSessions.count)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Summary row - brutalist
                    HStack(spacing: 1) {
                        SummaryCard(label: "WORDS", value: "\(totalWords)")
                        SummaryCard(label: "AVG WPM", value: "\(Int(avgWPM))")
                        SummaryCard(label: "SESSIONS", value: "\(sessionsForDate.count)")
                    }
                    .background(Color.omoiGray)

                    // Sessions header
                    Text("SESSIONS")
                        .font(OmoiFont.label(size: 11))
                        .foregroundStyle(Color.omoiMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.omoiDarkGray)
                        .overlay(
                            Rectangle()
                                .frame(height: 1)
                                .foregroundStyle(Color.omoiGray),
                            alignment: .top
                        )

                    // Sessions list
                    ForEach(sessionsForDate) { session in
                        SessionRowView(session: session, statsManager: statsManager)
                    }
                }
            }
            .omoiBackground()
            .navigationTitle(formatDateFull(date))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("DONE") {
                        isPresented = false
                    }
                    .foregroundStyle(Color.omoiTeal)
                }
            }
        }
    }

    func formatDateFull(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct SummaryCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(OmoiFont.statSmall)
                .foregroundStyle(Color.omoiWhite)

            Text(label)
                .font(OmoiFont.label(size: 10))
                .foregroundStyle(Color.omoiMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.omoiDarkGray)
    }
}

struct SessionRowView: View {
    let session: TranscriptionSession
    @ObservedObject var statsManager: StatsManager
    @State private var showingTagEditor = false

    var wpm: Int {
        guard session.duration > 0 else { return 0 }
        return Int(Double(session.wordCount) / (session.duration / 60.0))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatTime(session.timestamp))
                        .font(OmoiFont.mono(size: 12))
                        .foregroundStyle(Color.omoiMuted)

                    if let appName = session.targetAppName {
                        Text(appName)
                            .font(OmoiFont.label(size: 11))
                            .foregroundStyle(Color.omoiTeal)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(session.wordCount)")
                        .font(OmoiFont.mono(size: 18))
                        .foregroundStyle(Color.omoiWhite)

                    Text("\(wpm) WPM")
                        .font(OmoiFont.mono(size: 11))
                        .foregroundStyle(Color.omoiMuted)
                }
            }

            Text(session.text)
                .font(OmoiFont.body(size: 13))
                .foregroundStyle(Color.omoiOffWhite)
                .lineLimit(3)

            // Tags - brutalist style
            if !session.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(session.tags, id: \.self) { tag in
                        Text(tag.uppercased())
                            .font(OmoiFont.label(size: 9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.omoiTeal.opacity(0.2))
                            .foregroundStyle(Color.omoiTeal)
                    }
                }
            }

            // Add tag button
            Button(action: { showingTagEditor.toggle() }) {
                Text(session.tags.isEmpty ? "+ TAG" : "EDIT TAGS")
                    .font(OmoiFont.label(size: 10))
                    .foregroundStyle(Color.omoiMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.omoiDarkGray)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.omoiGray),
            alignment: .top
        )
        .popover(isPresented: $showingTagEditor) {
            TagEditorView(session: session, statsManager: statsManager)
        }
    }

    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Tag Components

struct TagChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(OmoiFont.label(size: 10))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.omoiTeal : Color.omoiGray)
                .foregroundStyle(isSelected ? Color.omoiBlack : Color.omoiLightGray)
        }
        .buttonStyle(.plain)
    }
}

struct TagEditorView: View {
    let session: TranscriptionSession
    @ObservedObject var statsManager: StatsManager
    @State private var newTag = ""
    @State private var smartSuggestions: [String] = []
    @State private var isLoadingSuggestions = false
    @State private var suggestionsError = false

    private let manualSuggestions = ["work", "personal", "meeting", "draft", "idea", "important"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TAGS")
                .font(OmoiFont.heading(size: 16))
                .foregroundStyle(Color.omoiWhite)

            // Current tags
            if !session.tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CURRENT")
                        .font(OmoiFont.label(size: 10))
                        .foregroundStyle(Color.omoiMuted)

                    FlowLayout(spacing: 4) {
                        ForEach(session.tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag.uppercased())
                                    .font(OmoiFont.label(size: 10))
                                Button(action: { statsManager.removeTag(tag, from: session.id) }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.omoiTeal)
                            .foregroundStyle(Color.omoiBlack)
                        }
                    }
                }
            }

            // Smart suggestions (LLM-powered)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text(isLoadingSuggestions ? "GENERATING..." : "SUGGESTED")
                        .font(OmoiFont.label(size: 10))
                        .foregroundStyle(Color.omoiMuted)

                    if suggestionsError {
                        Text("(UNAVAILABLE)")
                            .font(OmoiFont.label(size: 9))
                            .foregroundStyle(Color.omoiGray)
                    }
                }

                if !smartSuggestions.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(smartSuggestions, id: \.self) { tag in
                            Button(action: { statsManager.addTag(tag, to: session.id) }) {
                                Text(tag.uppercased())
                                    .font(OmoiFont.label(size: 10))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.omoiGray)
                                    .foregroundStyle(Color.omoiTealLight)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Manual suggestions
            VStack(alignment: .leading, spacing: 8) {
                Text("QUICK ADD")
                    .font(OmoiFont.label(size: 10))
                    .foregroundStyle(Color.omoiMuted)

                FlowLayout(spacing: 4) {
                    ForEach(manualSuggestions.filter { !session.tags.contains($0) && !smartSuggestions.contains($0) }, id: \.self) { tag in
                        Button(action: { statsManager.addTag(tag, to: session.id) }) {
                            Text("+ \(tag.uppercased())")
                                .font(OmoiFont.label(size: 10))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.omoiGray)
                                .foregroundStyle(Color.omoiLightGray)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Custom tag input
            HStack(spacing: 8) {
                TextField("Custom tag", text: $newTag)
                    .font(OmoiFont.body(size: 13))
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.omoiGray)
                    .foregroundStyle(Color.omoiWhite)

                Button(action: {
                    guard !newTag.isEmpty else { return }
                    statsManager.addTag(newTag.lowercased(), to: session.id)
                    newTag = ""
                }) {
                    Text("ADD")
                        .font(OmoiFont.label(size: 11))
                        .foregroundStyle(newTag.isEmpty ? Color.omoiGray : Color.omoiBlack)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(newTag.isEmpty ? Color.omoiGray : Color.omoiTeal)
                }
                .buttonStyle(.plain)
                .disabled(newTag.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(Color.omoiDarkGray)
        .task {
            isLoadingSuggestions = true
            do {
                let suggestions = await statsManager.suggestTagsWithLLM(for: session)
                if suggestions.isEmpty {
                    smartSuggestions = statsManager.suggestTagsFallback(for: session)
                } else {
                    smartSuggestions = suggestions
                }
            } catch {
                suggestionsError = true
                smartSuggestions = statsManager.suggestTagsFallback(for: session)
            }
            isLoadingSuggestions = false
        }
    }
}

// MARK: - Goal Components

struct GoalCard: View {
    let goal: UserGoal
    @ObservedObject var statsManager: StatsManager
    let onEdit: () -> Void
    var onDelete: (() -> Void)? = nil

    var progress: (current: Int, percentage: Double) {
        statsManager.currentProgress(for: goal)
    }

    var progressColor: Color {
        let pct = progress.percentage
        if pct >= 0.75 { return Color.omoiGreen }
        if pct >= 0.5 { return Color.omoiOrange }
        return Color.omoiOrange.opacity(0.6)
    }

    var statusText: String {
        let pct = progress.percentage
        if pct >= 1.0 { return "COMPLETE" }
        if pct >= 0.75 { return "ON TRACK" }
        return "BEHIND"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.type.rawValue.uppercased())
                        .font(OmoiFont.label(size: 11))
                        .foregroundStyle(Color.omoiWhite)

                    Text(goal.period.rawValue.uppercased())
                        .font(OmoiFont.label(size: 10))
                        .foregroundStyle(Color.omoiMuted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("\(progress.current)")
                            .font(OmoiFont.mono(size: 18))
                            .foregroundStyle(Color.omoiWhite)
                        Text("/")
                            .font(OmoiFont.mono(size: 14))
                            .foregroundStyle(Color.omoiMuted)
                        Text("\(goal.target)")
                            .font(OmoiFont.mono(size: 14))
                            .foregroundStyle(Color.omoiMuted)
                    }

                    Text(statusText)
                        .font(OmoiFont.label(size: 9))
                        .foregroundStyle(progressColor)
                }
            }

            // Progress bar - brutalist flat
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.omoiGray)

                    Rectangle()
                        .fill(progressColor)
                        .frame(width: geometry.size.width * min(progress.percentage, 1.0))
                }
            }
            .frame(height: 4)

            // Bottom row
            HStack {
                Text("\(Int(progress.percentage * 100))%")
                    .font(OmoiFont.mono(size: 12))
                    .foregroundStyle(Color.omoiMuted)

                Spacer()

                Button(action: onEdit) {
                    Text("EDIT")
                        .font(OmoiFont.label(size: 10))
                        .foregroundStyle(Color.omoiMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.omoiDarkGray)
        .overlay(
            Rectangle()
                .frame(width: 2)
                .foregroundStyle(progressColor),
            alignment: .leading
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.omoiGray),
            alignment: .top
        )
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit Goal", systemImage: "pencil")
            }

            if let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Goal", systemImage: "trash")
                }
            }
        }
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize
        var positions: [CGPoint]

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var positions: [CGPoint] = []
            var size: CGSize = .zero
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let subviewSize = subview.sizeThatFits(.unspecified)

                if currentX + subviewSize.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += subviewSize.width + spacing
                lineHeight = max(lineHeight, subviewSize.height)
                size.width = max(size.width, currentX - spacing)
            }

            size.height = currentY + lineHeight
            self.size = size
            self.positions = positions
        }
    }
}
