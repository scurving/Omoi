import SwiftUI

struct RecentTranscriptionsView: View {
    @ObservedObject var statsManager: StatsManager
    private let maxRecent = 5

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if statsManager.sessions.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.omoiMuted)
                        Text("No recent transcriptions")
                            .font(.caption)
                            .foregroundStyle(Color.omoiMuted)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ForEach(statsManager.sessions.prefix(maxRecent)) { session in
                        CompactHistoryRow(session: session)
                    }
                    .padding(.horizontal, 8)
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color.omoiBlack)
    }
}

struct CompactHistoryRow: View {
    let session: TranscriptionSession
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            // App icon (20x20)
            if let bundleID = session.targetAppBundleID,
               let path = NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: bundleID) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "app.dashed")
                    .font(.caption)
                    .foregroundStyle(Color.omoiMuted)
            }

            // Truncated text (1 line)
            Text(session.text)
                .lineLimit(1)
                .font(.caption)
                .foregroundStyle(Color.omoiOffWhite)

            Spacer()

            // Copy button on hover
            if isHovering {
                Button(action: { copyToClipboard(session.text) }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption2)
                        .foregroundStyle(Color.omoiTeal)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(isHovering ? Color.omoiGray : Color.omoiDarkGray)
        .cornerRadius(6)
        .onContinuousHover { phase in
            switch phase {
            case .active:
                isHovering = true
            case .ended:
                isHovering = false
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
