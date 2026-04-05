import SwiftUI

// MARK: - Activity Heatmaps Extension

extension DashboardView {

    struct HourData {
        let voiceIntensity: Double
        let typedIntensity: Double
    }

    @ViewBuilder var activityHeatmap: some View {
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
                ForEach(0..<24, id: \.self) { hour in
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
                ForEach(0..<24, id: \.self) { hour in
                    Text(hour % 4 == 0 ? "\(hour == 0 ? 12 : hour > 12 ? hour - 12 : hour)\(hour >= 12 ? "p" : "a")" : "")
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

    @ViewBuilder var weeklyHeatmap: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days: [(date: Date, label: String)] = (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let label = calendar.isDateInToday(date) ? "Today" : date.formatted(.dateTime.weekday(.abbreviated))
            return (date: date, label: label)
        }

        let maxWords = max(days.map { dailyWords(for: $0.date).voice + dailyWords(for: $0.date).typed }.max() ?? 1, 1)

        VStack(alignment: .leading, spacing: 8) {
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

    @ViewBuilder var monthlyHeatmap: some View {
        let calendar = Calendar.current
        let now = Date()
        let months: [(date: Date, label: String)] = (0..<12).reversed().compactMap { offset in
            guard let rawDate = calendar.date(byAdding: .month, value: -offset, to: now),
                  let monthStart = calendar.dateInterval(of: .month, for: rawDate)?.start else { return nil }
            return (date: monthStart, label: rawDate.formatted(.dateTime.month(.abbreviated)))
        }

        let maxWords = max(months.map { monthlyWords(for: $0.date).voice + monthlyWords(for: $0.date).typed }.max() ?? 1, 1)

        VStack(alignment: .leading, spacing: 8) {
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

    func hourlyData(for hour: Int) -> HourData {
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

    func dailyWords(for date: Date) -> (voice: Int, typed: Int) {
        let calendar = Calendar.current
        let voice = statsManager.sessions
            .filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
            .reduce(0) { $0 + $1.wordCount }
        let typed = statsManager.typingSessions
            .filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
            .reduce(0) { $0 + $1.wordCount }
        return (voice, typed)
    }

    func monthlyWords(for date: Date) -> (voice: Int, typed: Int) {
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
}
