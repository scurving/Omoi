import SwiftUI

struct DashboardWindowView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("", selection: $selectedTab) {
                Label("Dashboard", systemImage: "chart.bar.fill").tag(0)
                Label("History", systemImage: "clock.fill").tag(1)
                Label("Privacy", systemImage: "eye.slash.fill").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            // Reuse existing views
            Group {
                switch selectedTab {
                case 0:
                    DashboardView(statsManager: StatsManager.shared)
                case 1:
                    HistoryView(statsManager: StatsManager.shared)
                case 2:
                    PrivacyView(statsManager: StatsManager.shared)
                default:
                    DashboardView(statsManager: StatsManager.shared)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
