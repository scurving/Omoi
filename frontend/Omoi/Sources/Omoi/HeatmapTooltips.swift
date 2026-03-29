import SwiftUI

// MARK: - Heatmap Tooltips Extension

extension DashboardView {

    @ViewBuilder
    func heatmapTooltip(for hour: Int) -> some View {
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

    @ViewBuilder
    func dayTooltip(for date: Date) -> some View {
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

    @ViewBuilder
    func monthTooltip(for date: Date) -> some View {
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
}
