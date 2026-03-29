import SwiftUI

// MARK: - Omoi History View

struct HistoryView: View {
    @ObservedObject var statsManager: StatsManager
    @State private var searchText = ""
    @State private var selectedDateFilter = "all"
    @State private var selectedAppFilter = "all"
    @State private var selectedModeFilter: InputMode = .all
    @State private var expandedSessionId: UUID?

    enum InputMode: String, CaseIterable {
        case all = "all"
        case voice = "voice"
        case typed = "typed"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search and Filter Bar
            searchFilterBar

            // Content
            ScrollView {
                LazyVStack(spacing: 0) {
                    if filteredVoiceSessions.isEmpty && filteredTypingSessions.isEmpty {
                        emptyStateView
                            .padding(.top, 60)
                    } else {
                        // Interleave voice and typing sessions chronologically
                        ForEach(unifiedTimeline, id: \.id) { entry in
                            switch entry {
                            case .voice(let session):
                                ExpandableHistoryRow(
                                    session: session,
                                    expandedSessionId: $expandedSessionId,
                                    statsManager: statsManager
                                )
                            case .typed(let session):
                                TypingHistoryRow(
                                    session: session,
                                    expandedSessionId: $expandedSessionId
                                )
                            }
                        }
                    }
                }
            }
            .omoiBackground()
        }
    }

    // MARK: - Search & Filter Bar
    @ViewBuilder
    private var searchFilterBar: some View {
        HStack(spacing: 1) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: AppIcons.History.magnifyingglass)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.omoiMuted)
                TextField("SEARCH...", text: $searchText)
                    .font(OmoiFont.body(size: 13))
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.omoiWhite)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.omoiMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.omoiGray)

            // Filter menu
            Menu {
                Section("Date") {
                    Button(action: { selectedDateFilter = "all" }) {
                        Label("All time", systemImage: selectedDateFilter == "all" ? "checkmark" : "")
                    }
                    Button(action: { selectedDateFilter = "week" }) {
                        Label("This week", systemImage: selectedDateFilter == "week" ? "checkmark" : "")
                    }
                    Button(action: { selectedDateFilter = "month" }) {
                        Label("Last month", systemImage: selectedDateFilter == "month" ? "checkmark" : "")
                    }
                }

                Section("App") {
                    Button(action: { selectedAppFilter = "all" }) {
                        Label("All apps", systemImage: selectedAppFilter == "all" ? "checkmark" : "")
                    }
                    Divider()
                    ForEach(topApps, id: \.self) { appName in
                        Button(action: { selectedAppFilter = appName }) {
                            Label(appName, systemImage: selectedAppFilter == appName ? "checkmark" : "")
                        }
                    }
                }

                Section("Input Mode") {
                    Button(action: { selectedModeFilter = .all }) {
                        Label("All", systemImage: selectedModeFilter == .all ? "checkmark" : "")
                    }
                    Button(action: { selectedModeFilter = .voice }) {
                        Label("Voice", systemImage: selectedModeFilter == .voice ? "checkmark" : "")
                    }
                    Button(action: { selectedModeFilter = .typed }) {
                        Label("Typed", systemImage: selectedModeFilter == .typed ? "checkmark" : "")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: AppIcons.History.filter)
                        .font(.system(size: 12))
                    if activeFilterCount > 0 {
                        Text("\(activeFilterCount)")
                            .font(OmoiFont.mono(size: 10))
                    }
                }
                .foregroundStyle(activeFilterCount > 0 ? Color.omoiTeal : Color.omoiMuted)
                .padding(12)
                .background(Color.omoiGray)
            }
            .buttonStyle(.plain)
        }
        .background(Color.omoiDarkGray)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.omoiGray),
            alignment: .bottom
        )
    }

    // MARK: - Empty State
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Text("—")
                .font(OmoiFont.stat)
                .foregroundStyle(Color.omoiGray)

            VStack(spacing: 8) {
                let hasVoice   = !statsManager.sessions.isEmpty
                let hasTyped   = !statsManager.typingSessions.isEmpty
                if !hasVoice && !hasTyped {
                    Text("NO HISTORY")
                        .font(OmoiFont.label(size: 12))
                        .foregroundStyle(Color.omoiMuted)
                    Text("Record voice or start typing to see history")
                        .font(OmoiFont.body(size: 12))
                        .foregroundStyle(Color.omoiGray)
                } else {
                    Text("NO RESULTS")
                        .font(OmoiFont.label(size: 12))
                        .foregroundStyle(Color.omoiMuted)
                    Text("Adjust search or filters")
                        .font(OmoiFont.body(size: 12))
                        .foregroundStyle(Color.omoiGray)
                }
            }
        }
    }

    // MARK: - Filtering Logic

    /// Unified timeline entry that can represent either a voice or typing session
    enum TimelineEntry: Identifiable {
        case voice(TranscriptionSession)
        case typed(TypingSession)

        var id: UUID {
            switch self {
            case .voice(let s):  return s.id
            case .typed(let s): return s.id
            }
        }

        var timestamp: Date {
            switch self {
            case .voice(let s):  return s.timestamp
            case .typed(let s): return s.timestamp
            }
        }

        var appBundleID: String? {
            switch self {
            case .voice(let s):  return s.targetAppBundleID
            case .typed(let s): return s.appBundleID
            }
        }
    }

    /// Combined timeline of voice + typing sessions, sorted chronologically (newest first)
    private var unifiedTimeline: [TimelineEntry] {
        var entries: [TimelineEntry] = []

        if selectedModeFilter == .all || selectedModeFilter == .voice {
            entries += filteredVoiceSessions.map { .voice($0) }
        }

        if selectedModeFilter == .all || selectedModeFilter == .typed {
            entries += filteredTypingSessions.map { .typed($0) }
        }

        return entries.sorted { $0.timestamp > $1.timestamp }
    }

    private var filteredVoiceSessions: [TranscriptionSession] {
        var result = statsManager.sessions

        // Date filter
        let calendar = Calendar.current
        let now = Date()

        if selectedDateFilter == "week" {
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            result = result.filter { $0.timestamp >= weekAgo }
        } else if selectedDateFilter == "month" {
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            result = result.filter { $0.timestamp >= monthAgo }
        }

        // App filter
        if selectedAppFilter != "all" {
            result = result.filter { $0.targetAppName == selectedAppFilter }
        }

        // Search filter (case-insensitive)
        if !searchText.isEmpty {
            result = result.filter { session in
                session.text.localizedCaseInsensitiveContains(searchText) ||
                (session.targetAppName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return result
    }

    private var filteredTypingSessions: [TypingSession] {
        var result = statsManager.typingSessions

        // Date filter
        let calendar = Calendar.current
        let now = Date()

        if selectedDateFilter == "week" {
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            result = result.filter { $0.timestamp >= weekAgo }
        } else if selectedDateFilter == "month" {
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            result = result.filter { $0.timestamp >= monthAgo }
        }

        // App filter (by bundle ID or app name)
        if selectedAppFilter != "all" {
            result = result.filter { $0.appName == selectedAppFilter }
        }

        // Search filter (by app name)
        if !searchText.isEmpty {
            result = result.filter { session in
                session.appName.localizedCaseInsensitiveContains(searchText) ||
                (session.windowTitle?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return result
    }

    private var topApps: [String] {
        let appNames = statsManager.sessions
            .compactMap { $0.targetAppName }
            .reduce(into: [String: Int]()) { counts, app in
                counts[app, default: 0] += 1
            }
        return appNames
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }

    private var activeFilterCount: Int {
        var count = 0
        if selectedDateFilter != "all" { count += 1 }
        if selectedAppFilter != "all" { count += 1 }
        if selectedModeFilter != .all { count += 1 }
        return count
    }
}
