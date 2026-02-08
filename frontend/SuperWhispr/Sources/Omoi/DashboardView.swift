import SwiftUI
import Charts

// MARK: - Omoi Dashboard
// Brutalist design: sharp edges, high contrast, monospace stats

struct DashboardView: View {
    @ObservedObject var statsManager: StatsManager
    @State private var selectedChartMetric: ChartMetric = .words
    @State private var selectedDate: Date? = nil
    @State private var showingDetailModal = false
    @State private var showingClearAlert = false
    @State private var showingExportSheet = false
    @State private var showTrendLine = true
    @State private var selectedTagFilter: String? = nil
    @State private var showingGoalSetup = false

    enum ChartMetric: String, CaseIterable {
        case words = "Words"
        case wpm = "WPM"
    }

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
                    } else {
                        // Weekly Narrative Block
                        weeklyNarrativeCard
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
        .sheet(isPresented: $showingGoalSetup) {
            GoalSetupSheet(statsManager: statsManager, isPresented: $showingGoalSetup)
        }
    }

    @ViewBuilder
    private var statsContent: some View {
        VStack(spacing: 1) {
            // Goals Section (full-width brutalist block)
            goalsProgressSection

            // Current Streak Highlight (if active)
            if statsManager.currentStreak > 0 {
                currentStreakCard
            }

            // Stats Grid - 2x2 with 1px gaps
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 1),
                GridItem(.flexible(), spacing: 1)
            ], spacing: 1) {
                statCardWithTrend(
                    title: "WORDS",
                    value: formatNumber(statsManager.totalWords),
                    icon: AppIcons.Dashboard.words,
                    trend: trendForTotalWords(),
                    trendText: trendTextForTotalWords()
                )

                statCardWithTrend(
                    title: "AVG WPM",
                    value: "\(Int(statsManager.averageWPM))",
                    icon: AppIcons.Dashboard.speed,
                    trend: nil,
                    trendText: nil
                )

                statCardWithTrend(
                    title: "APPS",
                    value: "\(statsManager.topApps.count)",
                    icon: AppIcons.Dashboard.apps,
                    trend: nil,
                    trendText: statsManager.topApps.first.map { $0.name }
                )

                statCardWithTrend(
                    title: "THIS WEEK",
                    value: formatNumber(thisWeekWords()),
                    icon: AppIcons.Dashboard.chart,
                    trend: weekTrend(),
                    trendText: weekTrendText()
                )
            }
            .background(Color.omoiGray)

            // Peak Hour Block
            if let peak = statsManager.peakProductivityHour {
                peakHourCard(hour: peak.hour, words: peak.words)
            }

            // Chart Section
            if !statsManager.wordsPerDay.isEmpty || !statsManager.wpmPerDay.isEmpty {
                chartSection
            }

            // App Stats Breakdown (words + WPM per app)
            if !statsManager.statsByApp.isEmpty {
                appWPMSection
            }

            // Week Comparison
            if !statsManager.weekOverWeekComparison.isEmpty {
                weekComparisonSection
            }

            // Insights
            if !statsManager.performanceInsights.isEmpty {
                performanceInsightsSection
            }
        }
    }

    // MARK: - Tag Filter Bar
    @ViewBuilder
    private var tagFilterBar: some View {
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
    private var quickActionsToolbar: some View {
        HStack(spacing: 16) {
            Text("OMOI")
                .font(OmoiFont.brand(size: 18))
                .foregroundStyle(Color.omoiWhite)

            Spacer()

            // Goals
            Button(action: { showingGoalSetup = true }) {
                Text("GOALS")
                    .font(OmoiFont.label(size: 11))
                    .foregroundStyle(Color.omoiTeal)
            }
            .buttonStyle(.plain)

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
    private var emptyStateView: some View {
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
    @ViewBuilder
    private var weeklyNarrativeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(weeklyNarrativeTitle())
                .font(OmoiFont.heading(size: 24))
                .foregroundStyle(Color.omoiWhite)

            Text(weeklyNarrativeSubtitle())
                .font(OmoiFont.body(size: 14))
                .foregroundStyle(Color.omoiMuted)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.omoiDarkGray)
        .overlay(
            Rectangle()
                .stroke(Color.omoiTeal, lineWidth: 2),
            alignment: .leading
        )
    }

    // MARK: - Peak Hour Block
    @ViewBuilder
    private func peakHourCard(hour: Int, words: Int) -> some View {
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

    // MARK: - Current Streak Block
    @ViewBuilder
    private var currentStreakCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("STREAK")
                    .font(OmoiFont.label(size: 11))
                    .foregroundStyle(Color.omoiMuted)

                // Progress bar - brutalist style
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.omoiGray)
                        Rectangle()
                            .fill(Color.omoiOrange)
                            .frame(width: geometry.size.width * min(Double(statsManager.currentStreak) / 30.0, 1.0))
                    }
                }
                .frame(height: 4)
            }

            Spacer()

            Text("\(statsManager.currentStreak)")
                .font(OmoiFont.stat)
                .foregroundStyle(Color.omoiOrange)

            Text("DAYS")
                .font(OmoiFont.label(size: 11))
                .foregroundStyle(Color.omoiMuted)
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
    private var appWPMSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Text("BY APP")
                .font(OmoiFont.label(size: 11))
                .foregroundStyle(Color.omoiMuted)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.omoiDarkGray)

            // App rows with both words and WPM
            ForEach(Array(statsManager.statsByApp.prefix(5).enumerated()), id: \.offset) { index, appData in
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

                    // Total words
                    HStack(spacing: 4) {
                        Text(formatWordCount(appData.totalWords))
                            .font(OmoiFont.mono(size: 16))
                            .foregroundStyle(Color.omoiTeal)
                        Text("WORDS")
                            .font(OmoiFont.label(size: 9))
                            .foregroundStyle(Color.omoiMuted)
                    }
                    .frame(width: 100, alignment: .trailing)

                    // Average WPM
                    HStack(spacing: 4) {
                        Text("\(Int(appData.avgWPM))")
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

    private func formatWordCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
        return "\(count)"
    }

    // MARK: - Goals Progress Section
    @ViewBuilder
    private var goalsProgressSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text("GOALS")
                    .font(OmoiFont.label(size: 11))
                    .foregroundStyle(Color.omoiMuted)

                Spacer()

                if statsManager.goals.filter({ $0.isActive }).count < 3 {
                    Button(action: { showingGoalSetup = true }) {
                        Text("+ ADD")
                            .font(OmoiFont.label(size: 11))
                            .foregroundStyle(Color.omoiTeal)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.omoiDarkGray)

            if statsManager.goals.filter({ $0.isActive }).isEmpty {
                // Empty state - brutalist
                VStack(spacing: 12) {
                    Text("—")
                        .font(OmoiFont.stat)
                        .foregroundStyle(Color.omoiGray)

                    Text("Set goals to track progress")
                        .font(OmoiFont.body(size: 12))
                        .foregroundStyle(Color.omoiMuted)

                    Button(action: { showingGoalSetup = true }) {
                        Text("CREATE GOAL")
                            .font(OmoiFont.label(size: 11))
                            .foregroundStyle(Color.omoiBlack)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.omoiTeal)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color.omoiDarkGray)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color.omoiGray),
                    alignment: .top
                )
            } else {
                ForEach(statsManager.goals.filter { $0.isActive }) { goal in
                    GoalCard(goal: goal, statsManager: statsManager, onEdit: {
                        showingGoalSetup = true
                    }, onDelete: {
                        statsManager.deleteGoal(goal.id)
                    })
                }
            }
        }
    }

    // MARK: - Performance Insights Section
    @ViewBuilder
    private var performanceInsightsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Text("INSIGHTS")
                .font(OmoiFont.label(size: 11))
                .foregroundStyle(Color.omoiMuted)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.omoiDarkGray)

            ForEach(statsManager.performanceInsights) { insight in
                InsightCard(insight: insight)
            }
        }
    }

    // MARK: - Week Comparison Section
    @ViewBuilder
    private var weekComparisonSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Text("WEEK vs WEEK")
                .font(OmoiFont.label(size: 11))
                .foregroundStyle(Color.omoiMuted)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.omoiDarkGray)

            Chart {
                ForEach(statsManager.weekOverWeekComparison, id: \.day) { data in
                    BarMark(
                        x: .value("Day", data.day),
                        y: .value("Words", data.thisWeek),
                        width: 8
                    )
                    .position(by: .value("Week", "This Week"))
                    .foregroundStyle(Color.omoiTeal)

                    BarMark(
                        x: .value("Day", data.day),
                        y: .value("Words", data.lastWeek),
                        width: 8
                    )
                    .position(by: .value("Week", "Last Week"))
                    .foregroundStyle(Color.omoiGray)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(Color.omoiMuted)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                        .foregroundStyle(Color.omoiGray.opacity(0.5))
                    AxisValueLabel()
                        .foregroundStyle(Color.omoiMuted)
                }
            }
            .frame(height: 160)
            .padding(20)
            .background(Color.omoiDarkGray)

            // Comparison insight
            Text(weekComparisonInsight())
                .font(OmoiFont.body(size: 12))
                .foregroundStyle(Color.omoiMuted)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.omoiDarkGray)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color.omoiGray),
                    alignment: .top
                )
        }
    }

    // MARK: - Chart Section
    @ViewBuilder
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header with controls
            HStack {
                Text("PACE")
                    .font(OmoiFont.label(size: 11))
                    .foregroundStyle(Color.omoiMuted)

                Spacer()

                // Trend toggle
                Button(action: { showTrendLine.toggle() }) {
                    Text("TREND")
                        .font(OmoiFont.label(size: 10))
                        .foregroundStyle(showTrendLine ? Color.omoiOrange : Color.omoiGray)
                }
                .buttonStyle(.plain)

                // Metric picker - brutalist style
                HStack(spacing: 0) {
                    ForEach(ChartMetric.allCases, id: \.self) { metric in
                        Button(action: { selectedChartMetric = metric }) {
                            Text(metric.rawValue.uppercased())
                                .font(OmoiFont.label(size: 10))
                                .foregroundStyle(selectedChartMetric == metric ? Color.omoiBlack : Color.omoiMuted)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedChartMetric == metric ? Color.omoiTeal : Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.omoiGray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.omoiDarkGray)

            // Chart
            Chart {
                if selectedChartMetric == .words {
                    ForEach(Array(statsManager.wordsPerDay.enumerated()), id: \.offset) { index, data in
                        BarMark(
                            x: .value("Day", dayLabel(for: data.date)),
                            y: .value("Words", data.words)
                        )
                        .foregroundStyle(data.words > 1000 ? Color.omoiTeal : Color.omoiTeal.opacity(0.6))
                    }

                    // Trend line overlay
                    if showTrendLine && !statsManager.wordsMovingAverage.isEmpty {
                        ForEach(Array(statsManager.wordsMovingAverage.enumerated()), id: \.offset) { index, data in
                            LineMark(
                                x: .value("Day", dayLabel(for: data.date)),
                                y: .value("Trend", data.average)
                            )
                            .foregroundStyle(Color.omoiOrange)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }
                } else {
                    ForEach(Array(statsManager.wpmPerDay.enumerated()), id: \.offset) { index, data in
                        BarMark(
                            x: .value("Day", dayLabel(for: data.date)),
                            y: .value("WPM", data.wpm)
                        )
                        .foregroundStyle(data.wpm > 150 ? Color.omoiTeal : Color.omoiTeal.opacity(0.6))
                    }

                    // Trend line overlay
                    if showTrendLine && !statsManager.wpmMovingAverage.isEmpty {
                        ForEach(Array(statsManager.wpmMovingAverage.enumerated()), id: \.offset) { index, data in
                            LineMark(
                                x: .value("Day", dayLabel(for: data.date)),
                                y: .value("Trend", data.average)
                            )
                            .foregroundStyle(Color.omoiOrange)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(Color.omoiMuted)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                        .foregroundStyle(Color.omoiGray.opacity(0.5))
                    AxisValueLabel()
                        .foregroundStyle(Color.omoiMuted)
                }
            }
            .frame(height: 180)
            .chartAngleSelection(value: $selectedDate)
            .onChange(of: selectedDate) { oldValue, newValue in
                if newValue != nil {
                    showingDetailModal = true
                }
            }
            .padding(20)
            .background(Color.omoiDarkGray)

            // Chart insight
            Text(chartInsight())
                .font(OmoiFont.body(size: 12))
                .foregroundStyle(Color.omoiMuted)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.omoiDarkGray)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color.omoiGray),
                    alignment: .top
                )
        }
    }

    // MARK: - Helper: Stat Card with Trend (Brutalist)
    @ViewBuilder
    private func statCardWithTrend(
        title: String,
        value: String,
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

    // MARK: - Premium Copy & Narrative Logic

    private func weeklyNarrativeTitle() -> String {
        let thisWeek = thisWeekWords()
        let lastWeek = lastWeekWords()

        if thisWeek == 0 {
            return "Ready to capture"
        }

        if thisWeek > lastWeek && lastWeek > 0 {
            let percentIncrease = Int((Double(thisWeek - lastWeek) / Double(lastWeek)) * 100)
            return "You're on fire! 📈"
        }

        return "Great progress"
    }

    private func weeklyNarrativeSubtitle() -> String {
        let thisWeek = thisWeekWords()
        let lastWeek = lastWeekWords()
        let appCount = statsManager.topApps.count

        if thisWeek == 0 {
            return "Start recording to see your story unfold."
        }

        // Base message - always concise
        let baseMessage = "\(formatNumber(thisWeek)) words across \(appCount) app\(appCount == 1 ? "" : "s") this week"

        // Add trend if available (keep it short)
        if thisWeek > lastWeek && lastWeek > 0 {
            let percentIncrease = Int((Double(thisWeek - lastWeek) / Double(lastWeek)) * 100)
            return "\(baseMessage). Up \(percentIncrease)% from last week!"
        }

        return baseMessage + "."
    }

    private func trendForTotalWords() -> String? {
        let thisWeek = thisWeekWords()
        let lastWeek = lastWeekWords()

        guard lastWeek > 0 else { return nil }
        return thisWeek >= lastWeek ? "arrow.up.right" : "arrow.down.right"
    }

    private func trendTextForTotalWords() -> String? {
        let thisWeek = thisWeekWords()
        let lastWeek = lastWeekWords()

        guard lastWeek > 0 else { return nil }
        let change = abs(Int((Double(thisWeek - lastWeek) / Double(lastWeek)) * 100))
        return "\(change)% \(thisWeek >= lastWeek ? "up" : "down")"
    }

    private func weekTrend() -> String? {
        let thisWeek = thisWeekWords()
        let lastWeek = lastWeekWords()

        guard lastWeek > 0 else { return nil }
        return thisWeek >= lastWeek ? "arrow.up.right" : "arrow.down.right"
    }

    private func weekTrendText() -> String? {
        let thisWeek = thisWeekWords()
        let lastWeek = lastWeekWords()

        guard lastWeek > 0 else { return nil }
        let change = abs(Int((Double(thisWeek - lastWeek) / Double(lastWeek)) * 100))
        return "vs last week"
    }

    private func chartInsight() -> String {
        if selectedChartMetric == .words {
            guard let maxDay = statsManager.wordsPerDay.max(by: { $0.words < $1.words }) else {
                return "Start recording to see your pace."
            }
            let dayName = dayLabel(for: maxDay.date)
            return "Best day: \(maxDay.words) words on \(dayName)"
        } else {
            guard let maxDay = statsManager.wpmPerDay.max(by: { $0.wpm < $1.wpm }) else {
                return "Start recording to see your pace."
            }
            let dayName = dayLabel(for: maxDay.date)
            return "Fastest pace: \(Int(maxDay.wpm)) WPM on \(dayName)"
        }
    }

    // MARK: - Utilities

    private func thisWeekWords() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        return statsManager.sessions
            .filter { $0.timestamp >= weekAgo }
            .reduce(0) { $0 + $1.wordCount }
    }

    private func lastWeekWords() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now) ?? now

        return statsManager.sessions
            .filter { $0.timestamp >= twoWeeksAgo && $0.timestamp < weekAgo }
            .reduce(0) { $0 + $1.wordCount }
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000.0)
        }
        return "\(number)"
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func formatHour(_ hour: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(displayHour) \(period)"
    }

    private func peakHourDescription(hour: Int) -> String {
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

    private func rankIcon(for index: Int) -> String {
        switch index {
        case 0: return "medal.fill"
        case 1: return "crown.fill"
        case 2: return "star.fill"
        default: return "app.fill"
        }
    }

    private func rankColor(for index: Int) -> Color {
        switch index {
        case 0: return Color.yellow
        case 1: return Color.orange
        case 2: return Color.flowPurple
        default: return Color.flowBlue
        }
    }

    private func weekComparisonInsight() -> String {
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

    private func exportData() {
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

    private func generateCSV() -> String {
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

    private var sessionsForDate: [TranscriptionSession] {
        let calendar = Calendar.current
        return statsManager.sessions.filter { session in
            calendar.isDate(session.timestamp, inSameDayAs: date)
        }.sorted { $0.timestamp > $1.timestamp }
    }

    private var totalWords: Int {
        sessionsForDate.reduce(0) { $0 + $1.wordCount }
    }

    private var avgWPM: Double {
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

    private func formatDateFull(_ date: Date) -> String {
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

    private var wpm: Int {
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

    private func formatTime(_ date: Date) -> String {
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

    private var progress: (current: Int, percentage: Double) {
        statsManager.currentProgress(for: goal)
    }

    private var progressColor: Color {
        let pct = progress.percentage
        if pct >= 0.75 { return Color.omoiGreen }
        if pct >= 0.5 { return Color.omoiOrange }
        return Color.omoiOrange.opacity(0.6)
    }

    private var statusText: String {
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

struct InsightCard: View {
    let insight: PerformanceInsight

    private var accentColor: Color {
        switch insight.type {
        case .timing: return Color.omoiTeal
        case .speed: return Color.omoiTealLight
        case .habit: return Color.omoiGreen
        case .milestone: return Color.omoiOrange
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon block
            Rectangle()
                .fill(accentColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title.uppercased())
                    .font(OmoiFont.label(size: 11))
                    .foregroundStyle(Color.omoiWhite)

                Text(insight.message)
                    .font(OmoiFont.body(size: 12))
                    .foregroundStyle(Color.omoiMuted)
                    .lineLimit(3)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.omoiDarkGray)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.omoiGray),
            alignment: .top
        )
    }
}

struct GoalSetupSheet: View {
    @ObservedObject var statsManager: StatsManager
    @Binding var isPresented: Bool

    @State private var selectedType: UserGoal.GoalType = .wordCount
    @State private var selectedPeriod: UserGoal.GoalPeriod = .daily
    @State private var targetValue: String = "1000"
    @State private var editingGoal: UserGoal?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("NEW GOAL")
                    .font(OmoiFont.heading(size: 18))
                    .foregroundStyle(Color.omoiWhite)

                Spacer()

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.omoiMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color.omoiDarkGray)

            // Goal Type
            VStack(alignment: .leading, spacing: 8) {
                Text("TYPE")
                    .font(OmoiFont.label(size: 10))
                    .foregroundStyle(Color.omoiMuted)

                HStack(spacing: 1) {
                    ForEach(UserGoal.GoalType.allCases, id: \.self) { type in
                        Button(action: { selectedType = type }) {
                            Text(type.rawValue.uppercased())
                                .font(OmoiFont.label(size: 10))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selectedType == type ? Color.omoiTeal : Color.omoiGray)
                                .foregroundStyle(selectedType == type ? Color.omoiBlack : Color.omoiLightGray)
                        }
                        .buttonStyle(.plain)
                    }
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

            // Period
            VStack(alignment: .leading, spacing: 8) {
                Text("PERIOD")
                    .font(OmoiFont.label(size: 10))
                    .foregroundStyle(Color.omoiMuted)

                HStack(spacing: 1) {
                    ForEach(UserGoal.GoalPeriod.allCases, id: \.self) { period in
                        Button(action: { selectedPeriod = period }) {
                            Text(period.rawValue.uppercased())
                                .font(OmoiFont.label(size: 10))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selectedPeriod == period ? Color.omoiTeal : Color.omoiGray)
                                .foregroundStyle(selectedPeriod == period ? Color.omoiBlack : Color.omoiLightGray)
                        }
                        .buttonStyle(.plain)
                    }
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

            // Target
            VStack(alignment: .leading, spacing: 8) {
                Text("TARGET")
                    .font(OmoiFont.label(size: 10))
                    .foregroundStyle(Color.omoiMuted)

                HStack(spacing: 12) {
                    TextField("", text: $targetValue)
                        .font(OmoiFont.stat)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Color.omoiWhite)
                        .frame(width: 120)

                    Text(targetUnit.uppercased())
                        .font(OmoiFont.label(size: 11))
                        .foregroundStyle(Color.omoiMuted)

                    Spacer()
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

            Spacer()

            // Actions
            HStack(spacing: 12) {
                Button(action: { isPresented = false }) {
                    Text("CANCEL")
                        .font(OmoiFont.label(size: 12))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.omoiGray)
                        .foregroundStyle(Color.omoiLightGray)
                }
                .buttonStyle(.plain)

                Button(action: { saveGoal() }) {
                    Text("SAVE")
                        .font(OmoiFont.label(size: 12))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(targetValue.isEmpty || Int(targetValue) == nil ? Color.omoiGray : Color.omoiTeal)
                        .foregroundStyle(targetValue.isEmpty || Int(targetValue) == nil ? Color.omoiMuted : Color.omoiBlack)
                }
                .buttonStyle(.plain)
                .disabled(targetValue.isEmpty || Int(targetValue) == nil)
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
        .background(Color.omoiBlack)
        .frame(width: 400, height: 420)
    }

    private var targetUnit: String {
        switch selectedType {
        case .wordCount: return "words"
        case .sessionCount: return "sessions"
        case .streak: return "days"
        }
    }

    private func saveGoal() {
        guard let target = Int(targetValue) else { return }

        let newGoal = UserGoal(
            type: selectedType,
            target: target,
            period: selectedPeriod
        )

        statsManager.addGoal(newGoal)
        isPresented = false
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
