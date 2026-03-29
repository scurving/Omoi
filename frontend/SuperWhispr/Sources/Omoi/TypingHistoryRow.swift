import SwiftUI
import AppKit

// MARK: - TypingHistoryRow
//
// Displays a single TypingSession in the unified history timeline.
// Shows: app icon, app name, keyboard source badge, duration, word count, WPM.
// No expanded accordion (typing sessions have no text content to transform).

struct TypingHistoryRow: View {
    let session: TypingSession
    @Binding var expandedSessionId: UUID?

    @State private var isHovering = false

    private var isExpanded: Bool {
        expandedSessionId == session.id
    }

    var body: some View {
        VStack(spacing: 0) {
            // Collapsed row
            collapsedRow

            // Expanded detail (keyboard source, app details, no transform UI)
            if isExpanded {
                expandedDetail
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }

    // MARK: - Collapsed Row

    @ViewBuilder
    private var collapsedRow: some View {
        HStack(spacing: 12) {
            // App Icon
            appIcon

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(session.appName.uppercased())
                        .font(OmoiFont.label(size: 10))
                        .foregroundStyle(Color.omoiPurple)

                    // Keyboard source badge
                    keyboardBadge
                }

                Text("\(session.wordCount) words, \(Int(session.duration))s")
                    .font(OmoiFont.body(size: 13))
                    .foregroundStyle(Color.omoiOffWhite)
            }

            Spacer()

            HStack(spacing: 8) {
                // WPM indicator
                Text("\(Int(session.wpm)) WPM")
                    .font(OmoiFont.mono(size: 10))
                    .foregroundStyle(Color.omoiPurple)

                // Relative time
                Text(relativeTimeString(for: session.timestamp))
                    .font(OmoiFont.mono(size: 10))
                    .foregroundStyle(Color.omoiMuted)

                // Keyboard icon (on hover)
                if isHovering {
                    Image(systemName: session.keyboard.iconName)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.omoiPurple)
                        .transition(.scale.combined(with: .opacity))
                }

                // Expand/collapse
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.omoiMuted)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(isHovering || isExpanded ? Color.omoiGray : Color.omoiDarkGray)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.omoiGray),
            alignment: .top
        )
        .overlay(alignment: .leading) {
            // Left border accent to distinguish typing from voice
            Rectangle()
                .fill(Color.omoiPurple)
                .frame(width: 2)
                .opacity(isHovering || isExpanded ? 1 : 0)
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:  isHovering = true
            case .ended:   isHovering = false
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                if expandedSessionId == session.id {
                    expandedSessionId = nil
                } else {
                    expandedSessionId = session.id
                }
            }
        }
    }

    // MARK: - Expanded Detail

    @ViewBuilder
    private var expandedDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Keyboard breakdown
            HStack(spacing: 16) {
                detailPill(icon: session.keyboard.iconName,
                           label: session.keyboard.displayName,
                           color: Color.omoiPurple)

                detailPill(icon: "number",
                           label: "\(session.keystrokeCount) keystrokes",
                           color: Color.omoiTeal)

                detailPill(icon: "clock",
                           label: "\(Int(session.duration))s",
                           color: Color.omoiOrange)

                if let windowTitle = session.windowTitle, !windowTitle.isEmpty {
                    detailPill(icon: "macwindow",
                               label: windowTitle,
                               color: Color.omoiMuted)
                }
            }

            // Note about no text content
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.omoiMuted)
                Text("Typing sessions show keystroke counts — no text content is logged")
                    .font(OmoiFont.body(size: 11))
                    .foregroundStyle(Color.omoiMuted)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.omoiGray)
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

    @ViewBuilder
    private func detailPill(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(label.uppercased())
                .font(OmoiFont.label(size: 9))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
    }

    // MARK: - App Icon

    @ViewBuilder
    private var appIcon: some View {
        Group {
            if let path = NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: session.appBundleID) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .frame(width: 28, height: 28)
            } else {
                Rectangle()
                    .fill(Color.omoiGray)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "keyboard.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.omoiPurple)
                    )
            }
        }
        .overlay(alignment: .bottomTrailing) {
            // Small keyboard badge
            Circle()
                .fill(Color.omoiPurple)
                .frame(width: 8, height: 8)
        }
    }

    // MARK: - Keyboard Badge

    @ViewBuilder
    private var keyboardBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: session.keyboard.iconName)
                .font(.system(size: 8))
            Text(session.keyboard.displayName.uppercased())
                .font(OmoiFont.label(size: 8))
        }
        .foregroundStyle(Color.omoiPurple)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color.omoiPurple.opacity(0.15))
    }

    // MARK: - Helpers

    private func relativeTimeString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
