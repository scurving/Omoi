import SwiftUI
import AppKit

// MARK: - Expandable History Row

struct ExpandableHistoryRow: View {
    let session: TranscriptionSession
    @Binding var expandedSessionId: UUID?
    @ObservedObject var statsManager: StatsManager
    var sanitizationManager = SanitizationManager.shared
    @ObservedObject var audioManager = AudioManager.shared

    // Local state
    @State private var isHovering = false
    @State private var transformationMode: TransformationMode = .parallel
    @State private var loadingPresets: Set<UUID> = []
    @State private var error: String?
    @State private var showSavePipelineSheet = false

    private var isExpanded: Bool {
        expandedSessionId == session.id
    }

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
        VStack(spacing: 0) {
            // Collapsed row content
            collapsedRow

            // Expanded accordion content
            if isExpanded {
                accordionContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .sheet(isPresented: $showSavePipelineSheet) {
            SavePipelineSheet(
                presetIds: currentPresetIds,
                mode: transformationMode,
                isPresented: $showSavePipelineSheet
            )
        }
    }

    // MARK: - Collapsed Row

    @ViewBuilder
    private var collapsedRow: some View {
        HStack(spacing: 12) {
            // App Icon
            appIcon

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
                // Play button for audio
                if session.hasAudio, let fileName = session.audioFileName {
                    audioPlayButton(fileName: fileName)
                }

                Text(relativeTimeString(for: session.timestamp))
                    .font(OmoiFont.mono(size: 10))
                    .foregroundStyle(Color.omoiMuted)

                // Transformation indicator
                if session.transformations?.results.isEmpty == false {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.omoiTeal)
                }

                // Quick copy button (appears on hover)
                if isHovering {
                    Button(action: copyOriginalToClipboard) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.omoiMuted)
                    }
                    .buttonStyle(.plain)
                    .help("Copy text")
                    .transition(.scale.combined(with: .opacity))
                }

                // Expand/collapse chevron
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
            withAnimation {
                if expandedSessionId == session.id {
                    expandedSessionId = nil
                } else {
                    expandedSessionId = session.id
                }
            }
        }
    }

    // MARK: - Accordion Content

    @ViewBuilder
    private var accordionContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Mode Toggle
            modeToggle

            // Preset Chips
            presetChipsSection

            // Error display
            if let error = error {
                Text(error)
                    .font(OmoiFont.body(size: 11))
                    .foregroundStyle(Color.omoiOrange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.omoiOrange.opacity(0.1))
            }

            // Results Tabs (if any)
            if hasResults {
                resultTabsSection
            }

            // Actions
            actionsSection
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

    // MARK: - Mode Toggle

    @ViewBuilder
    private var modeToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MODE")
                .font(OmoiFont.label(size: 10))
                .foregroundStyle(Color.omoiMuted)

            HStack(spacing: 0) {
                modeButton("PARALLEL", mode: .parallel)
                modeButton("SEQUENTIAL", mode: .sequential)
            }
            .background(Color.omoiGray)
        }
    }

    @ViewBuilder
    private func modeButton(_ title: String, mode: TransformationMode) -> some View {
        Button(action: { transformationMode = mode }) {
            Text(title)
                .font(OmoiFont.label(size: 10))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(transformationMode == mode ? Color.omoiTeal : Color.clear)
                .foregroundStyle(transformationMode == mode ? Color.omoiBlack : Color.omoiLightGray)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Preset Chips

    @ViewBuilder
    private var presetChipsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PRESETS")
                .font(OmoiFont.label(size: 10))
                .foregroundStyle(Color.omoiMuted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sanitizationManager.presets) { preset in
                        PresetChip(
                            preset: preset,
                            isLoading: loadingPresets.contains(preset.id),
                            onTap: { applyPreset(preset) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Result Tabs

    @ViewBuilder
    private var resultTabsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RESULTS")
                .font(OmoiFont.label(size: 10))
                .foregroundStyle(Color.omoiMuted)

            // Tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    // Original tab
                    ResultTab(
                        label: "ORIGINAL",
                        isSelected: selectedResultId == nil,
                        onTap: { selectResult(nil) }
                    )

                    // Transformation result tabs
                    if let results = session.transformations?.results {
                        ForEach(results) { result in
                            ResultTab(
                                label: result.displayLabel.uppercased(),
                                isSelected: selectedResultId == result.id,
                                onTap: { selectResult(result.id) }
                            )
                        }
                    }
                }
            }

            // Content preview
            VStack(alignment: .leading, spacing: 8) {
                Text(selectedText)
                    .font(OmoiFont.body(size: 12))
                    .foregroundStyle(Color.omoiOffWhite)
                    .lineLimit(4)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.omoiGray)

                // Copy button
                HStack {
                    Spacer()
                    Button(action: copySelectedToClipboard) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                            Text("COPY")
                                .font(OmoiFont.label(size: 10))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.omoiTeal)
                        .foregroundStyle(Color.omoiBlack)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionsSection: some View {
        HStack(spacing: 12) {
            // Clear transformations
            if hasResults {
                Button(action: clearTransformations) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                        Text("CLEAR")
                            .font(OmoiFont.label(size: 10))
                    }
                    .foregroundStyle(Color.omoiMuted)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Save Pipeline (only if we have transformations)
            if hasResults {
                Button(action: { showSavePipelineSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 10))
                        Text("SAVE PIPELINE")
                            .font(OmoiFont.label(size: 10))
                    }
                    .foregroundStyle(Color.omoiLightGray)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private var appIcon: some View {
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
    }

    @ViewBuilder
    private func audioPlayButton(fileName: String) -> some View {
        Button {
            audioManager.togglePlayback(fileName: fileName, sessionID: session.id)
        } label: {
            ZStack {
                if isPlayingThis {
                    Rectangle()
                        .fill(Color.omoiTeal)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "pause.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.omoiBlack)
                        )
                } else if isPausedThis {
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

    private func relativeTimeString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Computed Properties

    private var hasResults: Bool {
        session.transformations?.results.isEmpty == false
    }

    private var selectedResultId: UUID? {
        session.transformations?.selectedResultId
    }

    private var selectedText: String {
        if let selected = session.transformations?.selectedResult {
            return selected.text
        }
        return session.text
    }

    private var currentPresetIds: [UUID] {
        session.transformations?.results.last?.presetIds ?? []
    }

    // MARK: - Actions

    private func selectResult(_ resultId: UUID?) {
        statsManager.selectTransformationResult(session.id, resultId: resultId)
    }

    private func copySelectedToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(selectedText, forType: .string)
    }

    private func copyOriginalToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(session.text, forType: .string)
    }

    private func clearTransformations() {
        statsManager.clearSessionTransformations(session.id)
    }

    private func applyPreset(_ preset: SanitizationPreset) {
        loadingPresets.insert(preset.id)
        error = nil

        Task {
            do {
                let sourceText: String
                let prevIds: [UUID]
                let prevNames: [String]

                if transformationMode == .parallel {
                    // Parallel: always use original text
                    sourceText = session.text
                    prevIds = []
                    prevNames = []
                } else {
                    // Sequential: chain from SELECTED result (not last)
                    if let selected = session.transformations?.selectedResult {
                        sourceText = selected.text
                        prevIds = selected.presetIds
                        prevNames = selected.presetNames
                    } else {
                        // No selection (Original tab) = start fresh chain
                        sourceText = session.text
                        prevIds = []
                        prevNames = []
                    }
                }

                let sanitized = try await APIService().sanitizeText(
                    text: sourceText,
                    instructions: preset.instructions
                )

                let result = TransformationResult(
                    text: sanitized,
                    presetIds: prevIds + [preset.id],
                    presetNames: prevNames + [preset.name],
                    mode: transformationMode
                )

                await MainActor.run {
                    statsManager.addTransformationResult(session.id, result: result)
                    loadingPresets.remove(preset.id)
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    loadingPresets.remove(preset.id)
                }
            }
        }
    }
}

// MARK: - Preset Chip

struct PresetChip: View {
    let preset: SanitizationPreset
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                }
                Text(preset.name.uppercased())
                    .font(OmoiFont.label(size: 10))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.omoiGray)
            .foregroundStyle(Color.omoiWhite)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .opacity(isLoading ? 0.6 : 1)
    }
}

// MARK: - Result Tab

struct ResultTab: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(OmoiFont.label(size: 10))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.omoiTeal : Color.omoiGray)
                .foregroundStyle(isSelected ? Color.omoiBlack : Color.omoiLightGray)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Save Pipeline Sheet

struct SavePipelineSheet: View {
    let presetIds: [UUID]
    let mode: TransformationMode
    @Binding var isPresented: Bool
    var sanitizationManager = SanitizationManager.shared

    @State private var pipelineName = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("SAVE PIPELINE")
                .font(OmoiFont.heading(size: 16))
                .foregroundStyle(Color.omoiWhite)

            // Preview of what's being saved
            VStack(alignment: .leading, spacing: 8) {
                Text("PRESETS")
                    .font(OmoiFont.label(size: 10))
                    .foregroundStyle(Color.omoiMuted)

                let presetNames = sanitizationManager.presetNames(for: presetIds)
                let separator = mode == .sequential ? " → " : ", "
                Text(presetNames.joined(separator: separator))
                    .font(OmoiFont.body(size: 12))
                    .foregroundStyle(Color.omoiTeal)

                Text("MODE: \(mode.rawValue.uppercased())")
                    .font(OmoiFont.label(size: 10))
                    .foregroundStyle(Color.omoiMuted)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            TextField("Pipeline name", text: $pipelineName)
                .textFieldStyle(.plain)
                .font(OmoiFont.body(size: 14))
                .padding(12)
                .background(Color.omoiGray)
                .foregroundStyle(Color.omoiWhite)

            HStack(spacing: 12) {
                Button("CANCEL") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.omoiMuted)

                Button("SAVE") {
                    savePipeline()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(pipelineName.isEmpty ? Color.omoiGray : Color.omoiTeal)
                .foregroundStyle(pipelineName.isEmpty ? Color.omoiMuted : Color.omoiBlack)
                .disabled(pipelineName.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 320)
        .background(Color.omoiDarkGray)
    }

    private func savePipeline() {
        sanitizationManager.addPipeline(
            name: pipelineName,
            presetIds: presetIds,
            mode: mode
        )
        isPresented = false
    }
}
