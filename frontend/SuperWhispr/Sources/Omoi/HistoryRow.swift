import SwiftUI
import AppKit

// MARK: - Omoi History Row

struct HistoryRow: View {
    let session: TranscriptionSession
    var sanitizationManager = SanitizationManager.shared
    @ObservedObject var audioManager = AudioManager.shared
    @State private var isHovering = false
    @State private var isCopying = false
    @State private var showCopyError = false
    @State private var copyError: String?

    private var isPlayingThis: Bool {
        audioManager.playbackState.currentSessionID == session.id && audioManager.playbackState.isPlaying
    }

    private var isPausedThis: Bool {
        if case .paused(let id) = audioManager.playbackState {
            return id == session.id
        }
        return false
    }

    var body: some View {
        HStack(spacing: 12) {
            // App Icon
            Group {
                if let bundleID = session.targetAppBundleID,
                   let path = NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: bundleID) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                        .resizable()
                        .frame(width: 28, height: 28)
                } else {
                    Rectangle()
                        .fill(Color.omoiGray)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "app.dashed")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.omoiMuted)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.targetAppName?.uppercased() ?? "UNKNOWN")
                    .font(OmoiFont.label(size: 10))
                    .foregroundStyle(Color.omoiTeal)

                Text(session.text)
                    .lineLimit(2)
                    .font(OmoiFont.body(size: 13))
                    .foregroundStyle(Color.omoiOffWhite)
            }

            Spacer()

            HStack(spacing: 8) {
                // Play button
                if session.hasAudio, let fileName = session.audioFileName {
                    Button {
                        audioManager.togglePlayback(fileName: fileName, sessionID: session.id)
                    } label: {
                        ZStack {
                            if isPlayingThis {
                                // Playing - show pause
                                Rectangle()
                                    .fill(Color.omoiTeal)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Image(systemName: "pause.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.omoiBlack)
                                    )
                            } else if isPausedThis {
                                // Paused - show play with progress
                                ZStack {
                                    Rectangle()
                                        .stroke(Color.omoiGray, lineWidth: 2)
                                        .frame(width: 24, height: 24)
                                    Rectangle()
                                        .fill(Color.omoiTeal)
                                        .frame(width: 24 * audioManager.playbackProgress, height: 24)
                                        .frame(maxWidth: 24, alignment: .leading)
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(Color.omoiWhite)
                                }
                            } else {
                                // Idle
                                Rectangle()
                                    .stroke(Color.omoiGray, lineWidth: 1)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 8))
                                            .foregroundStyle(Color.omoiMuted)
                                    )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .help(isPlayingThis ? "Pause" : "Play recording")
                }

                Text(relativeTimeString(for: session.timestamp))
                    .font(OmoiFont.mono(size: 10))
                    .foregroundStyle(Color.omoiMuted)

                if isHovering {
                    if sanitizationManager.rules.enabled {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.omoiTeal)
                    }

                    Button(action: copyToClipboard) {
                        if isCopying {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.omoiLightGray)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isCopying)
                    .transition(.opacity)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(isHovering ? Color.omoiGray : Color.omoiDarkGray)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.omoiGray),
            alignment: .top
        )
        .onContinuousHover { phase in
            switch phase {
            case .active:
                isHovering = true
            case .ended:
                isHovering = false
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            copyToClipboard()
        }
        .alert("Copy Error", isPresented: $showCopyError) {
            Button("OK") { showCopyError = false }
        } message: {
            Text(copyError ?? "Unknown error")
        }
    }

    private func copyToClipboard() {
        let textToCopy: String

        // Determine if we should use sanitized or original text
        if sanitizationManager.rules.enabled {
            // If we have cached sanitized text, use it
            if let sanitized = session.sanitizedText {
                textToCopy = sanitized
                doCopy(textToCopy)
                return
            }

            // Otherwise, fetch sanitized version
            isCopying = true
            Task {
                do {
                    let sanitized = try await APIService().sanitizeText(
                        text: session.text,
                        instructions: sanitizationManager.rules.instructions
                    )
                    await MainActor.run {
                        doCopy(sanitized)
                        isCopying = false
                    }
                } catch {
                    await MainActor.run {
                        copyError = error.localizedDescription
                        showCopyError = true
                        isCopying = false
                    }
                }
            }
        } else {
            // Copy original text
            textToCopy = session.text
            doCopy(textToCopy)
        }
    }

    private func doCopy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func relativeTimeString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
