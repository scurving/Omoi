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
    @State private var selectedDate: Date? = nil
    @State private var showingDetailModal = false
    @State private var showingClearAlert = false
    @State private var showingExportSheet = false
    @State private var selectedTagFilter: String? = nil
    @State private var selectedTimeRange: TimeRange = .today
    @State private var hoveredHour: Int? = nil
    @State private var hoveredDay: Date? = nil
    @State private var hoveredMonth: Date? = nil
    @State private var llmInsights: [String] = []
    @State private var isLoadingInsights = false

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
    private var statsContent: some View {
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

    // MARK: - Hero Insight Block

    @ViewBuilder
    private var heroInsightBlock: some View {
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
                    presenceStat(label: "C A D E N C E", value: "\(Int(statsManager.averageWPM))", unit: "WPM", color: Color.omoiOrange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right column
                VStack(alignment: .leading, spacing: 24) {
                    presenceStat(label: "T A C T I L E   F O C U S", value: formatNumber(filteredTypedWords()), color: Color.omoiTeal)
                    presenceStat(label: "P R E C I S I O N", value: "\(Int(typedAverageWpm()))", unit: "WPM", color: Color.omoiTeal)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
        }
        .background(Color.omoiDarkGray)
    }

    @ViewBuilder
    private func presenceStat(label: String, value: String, unit: String? = nil, color: Color) -> some View {
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

    private func typedAverageWpm() -> Double {
        let kbWpm = statsManager.wpmByKeyboard
        guard !kbWpm.isEmpty else { return 0 }
        return kbWpm.reduce(0.0) { $0 + $1.avgWpm } / Double(kbWpm.count)
    }

    private func filteredVoiceWords() -> Int {
        filteredVoiceSessions.reduce(0) { $0 + $1.wordCount }
    }

    private func filteredTypedWords() -> Int {
        filteredTypingSessions.reduce(0) { $0 + $1.wordCount }
    }

    private func presenceSubtitle() -> String {
        let total = filteredVoiceWords() + filteredTypedWords()
        if total == 0 { return "Awaiting your first words" }
        let voice = filteredVoiceWords()
        let typed = filteredTypedWords()
        if voice > typed * 2 { return "Vocal flow dominant today" }
        if typed > voice * 2 { return "Deep tactile focus today" }
        return "Harmonious output achieved today"
    }

    // MARK: - Activity Heatmap

    struct HourData {
        let voiceIntensity: Double
        let typedIntensity: Double
    }

    private var activityHeatmap: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("E N E R G Y   F L O W")
                    .font(OmoiFont.label(size: 9))
                    .foregroundStyle(Color.omoiMuted)
                    .kerning(1.5)
                Spacer()
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.omoiTeal).frame(width: 6, height: 6)
                        Text("TYPED").font(OmoiFont.label(size: 8)).foregroundStyle(Color.omoiMuted)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color.omoiOrange).frame(width: 6, height: 6)
                        Text("VOICE").font(OmoiFont.label(size: 8)).foregroundStyle(Color.omoiMuted)
                    }
                }
            }
            .padding(.horizontal, 20)

            HStack(spacing: 2) {
                ForEach(6..<24, id: \.self) { hour in
                    let data = hourlyData(for: hour)
                    VStack(spacing: 1) {
                        Rectangle()
                            .fill(Color.omoiOrange.opacity(data.voiceIntensity))
                            .frame(height: 24)
                        Rectangle()
                            .fill(Color.omoiTeal.opacity(data.typedIntensity))
                            .frame(height: 24)
                    }
                    .frame(maxWidth: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(hoveredHour == hour ? Color.omoiTeal : Color.clear, lineWidth: 1)
                    )
                    .onContinuousHover { phase in
                        switch phase {
                        case .active: hoveredHour = hour
                        case .ended: hoveredHour = nil
                        }
                    }
                    .popover(isPresented: Binding(
                        get: { hoveredHour == hour },
                        set: { if !$0 { hoveredHour = nil } }
                    ), arrowEdge: .bottom) {
                        heatmapTooltip(for: hour)
                    }
                }
            }
            .padding(.horizontal, 20)

            // Hour labels (every 3 hours)
            HStack(spacing: 0) {
                ForEach(6..<24, id: \.self) { hour in
                    Text(hour % 3 == 0 ? "\(hour > 12 ? hour - 12 : hour)\(hour >= 12 ? "p" : "a")" : "")
                        .font(OmoiFont.mono(size: 8))
                        .foregroundStyle(Color.omoiMuted)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(Color.omoiDarkGray)
    }

    private func hourlyData(for hour: Int) -> HourData {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Voice: count words from sessions in this hour today
        let voiceWords = statsManager.sessions
            .filter { session in
                let sessionHour = calendar.component(.hour, from: session.timestamp)
                return calendar.isDateInToday(session.timestamp) && sessionHour == hour
            }
            .reduce(0) { $0 + $1.wordCount }

        // Typed: get from hourly aggregates
        let typedWords: Int
        if let hourDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today),
           let hourFloor = calendar.dateInterval(of: .hour, for: hourDate)?.start {
            let agg = EncryptedStorageManager.shared.typingStorage.hourlyAggregates[hourFloor]
            typedWords = agg?.byApp.values.reduce(0) { $0 + $1.estimatedWords } ?? 0
        } else {
            typedWords = 0
        }

        let maxWordsPerHour = 200.0
        return HourData(
            voiceIntensity: min(Double(voiceWords) / maxWordsPerHour, 1.0),
            typedIntensity: min(Double(typedWords) / maxWordsPerHour, 1.0)
        )
    }

    // MARK: - Weekly Heatmap (7 days)

    private var weeklyHeatmap: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days: [(date: Date, label: String)] = (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let label = calendar.isDateInToday(date) ? "Today" : date.formatted(.dateTime.weekday(.abbreviated))
            return (date: date, label: label)
        }

        let maxWords = max(days.map { dailyWords(for: $0.date).voice + dailyWords(for: $0.date).typed }.max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 8) {
            Text("THIS WEEK")
                .font(OmoiFont.label(size: 11))
                .foregroundStyle(Color.omoiMuted)
                .padding(.horizontal, 20)

            HStack(spacing: 3) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    let data = dailyWords(for: day.date)
                    let voiceI = Double(data.voice) / Double(maxWords)
                    let typedI = Double(data.typed) / Double(maxWords)

                    VStack(spacing: 1) {
                        Rectangle()
                            .fill(Color.omoiOrange.opacity(max(voiceI, 0.05)))
                            .frame(height: 24)
                        Rectangle()
                            .fill(Color.omoiTeal.opacity(max(typedI, 0.05)))
                            .frame(height: 24)
                    }
                    .frame(maxWidth: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(hoveredDay == day.date ? Color.omoiTeal : Color.clear, lineWidth: 1)
                    )
                    .onContinuousHover { phase in
                        switch phase {
                        case .active: hoveredDay = day.date
                        case .ended: hoveredDay = nil
                        }
                    }
                    .popover(isPresented: Binding(
                        get: { hoveredDay == day.date },
                        set: { if !$0 { hoveredDay = nil } }
                    ), arrowEdge: .bottom) {
                        dayTooltip(for: day.date)
                    }
                }
            }
            .padding(.horizontal, 20)

            HStack(spacing: 3) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    Text(day.label.prefix(3).uppercased())
                        .font(OmoiFont.mono(size: 8))
                        .foregroundStyle(Color.omoiMuted)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(Color.omoiDarkGray)
    }

    private func dailyWords(for date: Date) -> (voice: Int, typed: Int) {
        let calendar = Calendar.current
        let voice = statsManager.sessions
            .filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
            .reduce(0) { $0 + $1.wordCount }
        let typed = statsManager.typingSessions
            .filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
            .reduce(0) { $0 + $1.wordCount }
        return (voice, typed)
    }

    // MARK: - Monthly Heatmap (12 months)

    private var monthlyHeatmap: some View {
        let calendar = Calendar.current
        let now = Date()
        let months: [(date: Date, label: String)] = (0..<12).reversed().compactMap { offset in
            guard let rawDate = calendar.date(byAdding: .month, value: -offset, to: now),
                  let monthStart = calendar.dateInterval(of: .month, for: rawDate)?.start else { return nil }
            return (date: monthStart, label: rawDate.formatted(.dateTime.month(.abbreviated)))
        }

        let maxWords = max(months.map { monthlyWords(for: $0.date).voice + monthlyWords(for: $0.date).typed }.max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 8) {
            Text("ALL TIME")
                .font(OmoiFont.label(size: 11))
                .foregroundStyle(Color.omoiMuted)
                .padding(.horizontal, 20)

            HStack(spacing: 3) {
                ForEach(Array(months.enumerated()), id: \.offset) { _, month in
                    let data = monthlyWords(for: month.date)
                    let voiceI = Double(data.voice) / Double(maxWords)
                    let typedI = Double(data.typed) / Double(maxWords)

                    VStack(spacing: 1) {
                        Rectangle()
                            .fill(Color.omoiOrange.opacity(max(voiceI, 0.05)))
                            .frame(height: 24)
                        Rectangle()
                            .fill(Color.omoiTeal.opacity(max(typedI, 0.05)))
                            .frame(height: 24)
                    }
                    .frame(maxWidth: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(hoveredMonth == month.date ? Color.omoiTeal : Color.clear, lineWidth: 1)
                    )
                    .onContinuousHover { phase in
                        switch phase {
                        case .active: hoveredMonth = month.date
                        case .ended: hoveredMonth = nil
                        }
                    }
                    .popover(isPresented: Binding(
                        get: { hoveredMonth == month.date },
                        set: { if !$0 { hoveredMonth = nil } }
                    ), arrowEdge: .bottom) {
                        monthTooltip(for: month.date)
                    }
                }
            }
            .padding(.horizontal, 20)

            HStack(spacing: 3) {
                ForEach(Array(months.enumerated()), id: \.offset) { _, month in
                    Text(month.label.prefix(3).uppercased())
                        .font(OmoiFont.mono(size: 8))
                        .foregroundStyle(Color.omoiMuted)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(Color.omoiDarkGray)
    }

    private func monthlyWords(for date: Date) -> (voice: Int, typed: Int) {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else {
            return (0, 0)
        }
        let voice = statsManager.sessions
            .filter { $0.timestamp >= monthInterval.start && $0.timestamp < monthInterval.end }
            .reduce(0) { $0 + $1.wordCount }
        let typed = statsManager.typingSessions
            .filter { $0.timestamp >= monthInterval.start && $0.timestamp < monthInterval.end }
            .reduce(0) { $0 + $1.wordCount }
        return (voice, typed)
    }

    // MARK: - Heatmap Tooltip

    @ViewBuilder
    private func heatmapTooltip(for hour: Int) -> some View {
        let calendar = Calendar.current

        let voiceSessions = statsManager.sessions.filter { session in
            calendar.isDateInToday(session.timestamp) &&
            calendar.component(.hour, from: session.timestamp) == hour
        }
        let typedSessions = statsManager.typingSessions.filter { session in
            calendar.isDateInToday(session.timestamp) &&
            calendar.component(.hour, from: session.timestamp) == hour
        }

        let totalVoice = voiceSessions.reduce(0) { $0 + $1.wordCount }
        let totalTyped = typedSessions.reduce(0) { $0 + $1.wordCount }

        let voiceByApp = Dictionary(grouping: voiceSessions) { $0.targetAppName ?? "Unknown" }
        let typedByApp = Dictionary(grouping: typedSessions) { $0.appName }
        let allApps = Set(voiceByApp.keys).union(typedByApp.keys)

        VStack(alignment: .leading, spacing: 8) {
            Text(formatHour(hour))
                .font(OmoiFont.label(size: 11))
                .foregroundStyle(Color.omoiWhite)

            if totalVoice + totalTyped == 0 {
                Text("No activity")
                    .font(OmoiFont.body(size: 11))
                    .foregroundStyle(Color.omoiMuted)
            } else {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.omoiOrange).frame(width: 6, height: 6)
                        Text("\(totalVoice) voice")
                            .font(OmoiFont.mono(size: 10))
                            .foregroundStyle(Color.omoiOrange)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color.omoiTeal).frame(width: 6, height: 6)
                        Text("\(totalTyped) typed")
                            .font(OmoiFont.mono(size: 10))
                            .foregroundStyle(Color.omoiTeal)
                    }
                }

                ForEach(Array(allApps.sorted().prefix(4)), id: \.self) { app in
                    let vWords = voiceByApp[app]?.reduce(0) { $0 + $1.wordCount } ?? 0
                    let tWords = typedByApp[app]?.reduce(0) { $0 + $1.wordCount } ?? 0
                    HStack {
                        Text(app)
                            .font(OmoiFont.body(size: 10))
                            .foregroundStyle(Color.omoiOffWhite)
                            .lineLimit(1)
                        Spacer()
                        if vWords > 0 {
                            Text("\(vWords)")
                                .font(OmoiFont.mono(size: 9))
                                .foregroundStyle(Color.omoiOrange)
                        }
                        if tWords > 0 {
                            Text("\(tWords)")
                                .font(OmoiFont.mono(size: 9))
                                .foregroundStyle(Color.omoiTeal)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(minWidth: 150)
        .background(Color.omoiDarkGray)
    }

    // MARK: - Day Tooltip

    @ViewBuilder
    private func dayTooltip(for date: Date) -> some View {
        let calendar = Calendar.current
        let voiceSessions = statsManager.sessions.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
        let typedSessions = statsManager.typingSessions.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
        let totalVoice = voiceSessions.reduce(0) { $0 + $1.wordCount }
        let totalTyped = typedSessions.reduce(0) { $0 + $1.wordCount }

        let voiceByApp = Dictionary(grouping: voiceSessions) { $0.targetAppName ?? "Unknown" }
        let typedByApp = Dictionary(grouping: typedSessions) { $0.appName }
        let allApps = Set(voiceByApp.keys).union(typedByApp.keys)

        VStack(alignment: .leading, spacing: 8) {
            Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(OmoiFont.label(size: 11))
                .foregroundStyle(Color.omoiWhite)

            if totalVoice + totalTyped == 0 {
                Text("No activity")
                    .font(OmoiFont.body(size: 11))
                    .foregroundStyle(Color.omoiMuted)
            } else {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.omoiOrange).frame(width: 6, height: 6)
                        Text("\(totalVoice) voice")
                            .font(OmoiFont.mono(size: 10))
                            .foregroundStyle(Color.omoiOrange)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color.omoiTeal).frame(width: 6, height: 6)
                        Text("\(totalTyped) typed")
                            .font(OmoiFont.mono(size: 10))
                            .foregroundStyle(Color.omoiTeal)
                    }
                }

                ForEach(Array(allApps.sorted().prefix(4)), id: \.self) { app in
                    let vWords = voiceByApp[app]?.reduce(0) { $0 + $1.wordCount } ?? 0
                    let tWords = typedByApp[app]?.reduce(0) { $0 + $1.wordCount } ?? 0
                    HStack {
                        Text(app)
                            .font(OmoiFont.body(size: 10))
                            .foregroundStyle(Color.omoiOffWhite)
                            .lineLimit(1)
                        Spacer()
                        if vWords > 0 {
                            Text("\(vWords)")
                                .font(OmoiFont.mono(size: 9))
                                .foregroundStyle(Color.omoiOrange)
                        }
                        if tWords > 0 {
                            Text("\(tWords)")
                                .font(OmoiFont.mono(size: 9))
                                .foregroundStyle(Color.omoiTeal)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(minWidth: 150)
        .background(Color.omoiDarkGray)
    }

    // MARK: - Month Tooltip

    @ViewBuilder
    private func monthTooltip(for date: Date) -> some View {
        let calendar = Calendar.current
        let monthInterval = calendar.dateInterval(of: .month, for: date)
        let voiceSessions = statsManager.sessions.filter { s in
            guard let mi = monthInterval else { return false }
            return s.timestamp >= mi.start && s.timestamp < mi.end
        }
        let typedSessions = statsManager.typingSessions.filter { s in
            guard let mi = monthInterval else { return false }
            return s.timestamp >= mi.start && s.timestamp < mi.end
        }
        let totalVoice = voiceSessions.reduce(0) { $0 + $1.wordCount }
        let totalTyped = typedSessions.reduce(0) { $0 + $1.wordCount }

        let voiceByApp = Dictionary(grouping: voiceSessions) { $0.targetAppName ?? "Unknown" }
        let typedByApp = Dictionary(grouping: typedSessions) { $0.appName }
        let allApps = Set(voiceByApp.keys).union(typedByApp.keys)

        VStack(alignment: .leading, spacing: 8) {
            Text(date.formatted(.dateTime.month(.wide).year()))
                .font(OmoiFont.label(size: 11))
                .foregroundStyle(Color.omoiWhite)

            if totalVoice + totalTyped == 0 {
                Text("No activity")
                    .font(OmoiFont.body(size: 11))
                    .foregroundStyle(Color.omoiMuted)
            } else {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.omoiOrange).frame(width: 6, height: 6)
                        Text("\(totalVoice) voice")
                            .font(OmoiFont.mono(size: 10))
                            .foregroundStyle(Color.omoiOrange)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color.omoiTeal).frame(width: 6, height: 6)
                        Text("\(totalTyped) typed")
                            .font(OmoiFont.mono(size: 10))
                            .foregroundStyle(Color.omoiTeal)
                    }
                }

                ForEach(Array(allApps.sorted().prefix(5)), id: \.self) { app in
                    let vWords = voiceByApp[app]?.reduce(0) { $0 + $1.wordCount } ?? 0
                    let tWords = typedByApp[app]?.reduce(0) { $0 + $1.wordCount } ?? 0
                    HStack {
                        Text(app)
                            .font(OmoiFont.body(size: 10))
                            .foregroundStyle(Color.omoiOffWhite)
                            .lineLimit(1)
                        Spacer()
                        if vWords > 0 {
                            Text("\(vWords)")
                                .font(OmoiFont.mono(size: 9))
                                .foregroundStyle(Color.omoiOrange)
                        }
                        if tWords > 0 {
                            Text("\(tWords)")
                                .font(OmoiFont.mono(size: 9))
                                .foregroundStyle(Color.omoiTeal)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(minWidth: 180)
        .background(Color.omoiDarkGray)
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

    // MARK: - App Stats Breakdown Section
    @ViewBuilder
    private var appWPMSection: some View {
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

    private var filteredVoiceSessions: [TranscriptionSession] {
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

    private var filteredTypingSessions: [TypingSession] {
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

    private var filteredPeakHour: (hour: Int, words: Int)? {
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
    private var allAppStats: [(appName: String, voiceWords: Int, typedWords: Int, avgWpm: Double)] {
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

    private func formatWordCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
        return "\(count)"
    }

    // MARK: - LLM Insights Block

    private var insightsBlock: some View {
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

    private func bulletColor(for index: Int) -> Color {
        let colors: [Color] = [.omoiTeal, .omoiOrange, .omoiPurple, .omoiGreen]
        return colors[index % colors.count]
    }

    private func generateInsights() {
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

    // MARK: - Helper: Stat Card with Split (Brutalist)
    @ViewBuilder
    private func statCardWithSplit(
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
    private func statCardWithTrend(
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

    // MARK: - Utilities

    private func thisWeekWords() -> Int {
        thisWeekVoiceWords() + thisWeekTypedWords()
    }

    private func thisWeekVoiceWords() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        return statsManager.sessions
            .filter { $0.timestamp >= weekAgo }
            .reduce(0) { $0 + $1.wordCount }
    }

    private func thisWeekTypedWords() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        return statsManager.typingSessions
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
