import SwiftUI
import KeyboardShortcuts
import UniformTypeIdentifiers

struct PipelinesView: View {
    @State private var sanitizationManager = SanitizationManager.shared
    @ObservedObject var statsManager: StatsManager
    
    // State for Sanitization
    @State private var isPreviewLoading = false
    @State private var previewSanitized: String?
    @State private var previewError: String?
    @State private var showPreviewError = false
    @State private var isSanitizingAll = false
    @State private var sanitizationProgress = 0
    @State private var selectedSessions: Set<UUID> = []
    @State private var showSavePresetSheet = false
    @State private var newPresetName = ""
    
    // Settings state
    @State private var shortcutDescription: String = ""
    @State private var backups: [StorageManager.BackupInfo] = []
    @State private var historyInfo: (sessionCount: Int, fileSize: Int64, lastModified: Date?)? = nil
    @State private var showingExportPanel = false
    @State private var showingImportPanel = false
    @State private var showingRestoreAlert = false
    @State private var selectedBackup: StorageManager.BackupInfo? = nil
    @State private var settingsStatusMessage: String? = nil
    @State private var integrityStatus: String = "Checking..."
    @State private var showingDeleteRecordingsAlert = false
    @AppStorage("saveRecordingsForPlayback") private var saveRecordingsForPlayback = true
    @AppStorage("transcriptionLanguage") private var transcriptionLanguage = "auto"

    // UI State
    @State private var expandedSection: PipelineSection? = .input // Default to input expanded
    
    enum PipelineSection: String, Identifiable {
        case input = "INPUT LAYER"
        case output = "SYNTHESIS LAYER"
        case system = "SYSTEM CORE"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("INTELLIGENCE PIPELINES")
                            .font(OmoiFont.brand(size: 18))
                            .foregroundStyle(Color.omoiWhite)
                        Text("Configure how Omoi transforms your data.")
                            .font(OmoiFont.body(size: 12))
                            .foregroundStyle(Color.omoiMuted)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // 1. Input Layer (Sanitization)
                pipelineCard(
                    title: "INPUT LAYER",
                    subtitle: "Real-time Sanitization & Privacy",
                    icon: "shield.checkerboard",
                    color: Color.omoiTeal,
                    section: .input
                ) {
                    inputLayerContent()
                }
                
                // 2. Synthesis Layer (Retrospective)
                pipelineCard(
                    title: "SYNTHESIS LAYER",
                    subtitle: "Daily Retrospective & Analysis",
                    icon: "brain.head.profile",
                    color: Color.omoiPurple, // Using Purple if available, else fallback
                    section: .output
                ) {
                    outputLayerContent()
                }
                
                // 3. System Core (Permissions)
                pipelineCard(
                    title: "SYSTEM CORE",
                    subtitle: "Permissions & Health",
                    icon: "cpu",
                    color: Color.omoiGray,
                    section: .system
                ) {
                    systemCoreContent()
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color.omoiBlack)
        .sheet(isPresented: $showSavePresetSheet) {
            savePresetSheet()
        }
    }
    
    // MARK: - Card Component
    
    @ViewBuilder
    private func pipelineCard<Content: View>(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        section: PipelineSection,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            // Card Header
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if expandedSection == section {
                        expandedSection = nil
                    } else {
                        expandedSection = section
                    }
                }
            }) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.1))
                            .frame(width: 40, height: 40)
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundStyle(color)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(OmoiFont.label(size: 12))
                            .foregroundStyle(color)
                            .kerning(1.0)
                        Text(subtitle)
                            .font(OmoiFont.body(size: 13))
                            .foregroundStyle(Color.omoiOffWhite)
                    }
                    
                    Spacer()
                    
                    if section == .input {
                        // Mini status indicator for Input
                        Text(sanitizationManager.rules.enabled ? "ACTIVE" : "OFF")
                            .font(OmoiFont.mono(size: 10))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(sanitizationManager.rules.enabled ? Color.omoiGreen.opacity(0.2) : Color.omoiGray)
                            .foregroundStyle(sanitizationManager.rules.enabled ? Color.omoiGreen : Color.omoiMuted)
                            .cornerRadius(4)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.omoiGray)
                        .rotationEffect(.degrees(expandedSection == section ? 90 : 0))
                }
                .padding(20)
                .background(Color.omoiDarkGray)
            }
            .buttonStyle(.plain)
            
            // Expanded Content
            if expandedSection == section {
                VStack(spacing: 0) {
                    Divider().overlay(Color.omoiGray.opacity(0.5))
                    content()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                .background(Color.omoiDarkGray.opacity(0.5))
            }
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.omoiGray, lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
    
    // MARK: - Layer Contents
    
    @ViewBuilder
    private func inputLayerContent() -> some View {
        VStack(spacing: 24) {
            // 1. Master Toggle & Instructions
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Toggle(isOn: $sanitizationManager.rules.enabled) {
                        Text("ENABLE FIREWALL")
                            .font(OmoiFont.label(size: 11))
                            .foregroundStyle(Color.omoiWhite)
                    }
                    .toggleStyle(.switch)
                    
                    Spacer()
                    
                    Toggle(isOn: $sanitizationManager.rules.autoSanitizeBeforePaste) {
                        Text("AUTO-PASTE")
                            .font(OmoiFont.label(size: 11))
                            .foregroundStyle(Color.omoiWhite)
                    }
                    .toggleStyle(.switch)
                    .disabled(!sanitizationManager.rules.enabled)
                    .opacity(sanitizationManager.rules.enabled ? 1 : 0.5)
                }
                
                // Presets Scroller
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sanitizationManager.presets) { preset in
                            presetPill(preset)
                        }
                    }
                }
                .disabled(!sanitizationManager.rules.enabled)
                .opacity(sanitizationManager.rules.enabled ? 1 : 0.5)
                
                // Instructions Editor
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("INSTRUCTION SET")
                            .font(OmoiFont.label(size: 10))
                            .foregroundStyle(Color.omoiMuted)
                        Spacer()
                        Button(action: { showSavePresetSheet = true }) {
                            Text("SAVE AS PRESET")
                                .font(OmoiFont.label(size: 10))
                                .foregroundStyle(Color.omoiTeal)
                        }
                        .buttonStyle(.plain)
                        .disabled(sanitizationManager.rules.instructions.isEmpty)
                        .opacity(sanitizationManager.rules.instructions.isEmpty ? 0.3 : 1.0)
                    }

                    TextEditor(text: $sanitizationManager.rules.instructions)
                        .font(OmoiFont.body(size: 13))
                        .scrollContentBackground(.hidden)
                        .background(Color.omoiBlack)
                        .foregroundStyle(Color.omoiWhite)
                        .frame(height: 100)
                        .overlay(Rectangle().stroke(Color.omoiGray, lineWidth: 1))
                        .disabled(!sanitizationManager.rules.enabled)
                        .opacity(sanitizationManager.rules.enabled ? 1 : 0.5)
                        .overlay(alignment: .topLeading) {
                            if sanitizationManager.rules.instructions.isEmpty {
                                Text("Type here to create new preset...")
                                    .font(OmoiFont.body(size: 13))
                                    .foregroundStyle(Color.omoiMuted.opacity(0.5))
                                    .padding(8)
                                    .allowsHitTesting(false)
                            }
                        }
                }
            }
            .padding(20)
            
            Divider().overlay(Color.omoiGray.opacity(0.5))
            
            // 2. Interactive Preview
            if let mostRecent = statsManager.sessions.first {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "eye")
                        Text("SIMULATION")
                    }
                    .font(OmoiFont.label(size: 11))
                    .foregroundStyle(Color.omoiMuted)
                    
                    HStack(spacing: 0) {
                        // Original
                        Text(mostRecent.text)
                            .font(OmoiFont.body(size: 11))
                            .foregroundStyle(Color.omoiMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.omoiBlack)
                            .overlay(Rectangle().stroke(Color.omoiGray, lineWidth: 1))
                        
                        // Arrow
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.omoiGray)
                            .frame(width: 32)
                        
                        // Result
                        Group {
                            if isPreviewLoading {
                                ProgressView().scaleEffect(0.5)
                            } else if let sanitized = previewSanitized {
                                Text(sanitized)
                                    .foregroundStyle(Color.omoiTeal)
                            } else if let error = previewError {
                                Text(error).foregroundStyle(Color.omoiOrange)
                            } else {
                                Text("Run simulation...")
                                    .foregroundStyle(Color.omoiMuted)
                                    .italic()
                            }
                        }
                        .font(OmoiFont.body(size: 11))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.omoiBlack)
                        .overlay(Rectangle().stroke(Color.omoiGray, lineWidth: 1))
                    }
                    .frame(height: 80)
                    
                    Button(action: previewSanitization) {
                        Text("RUN SIMULATION")
                            .font(OmoiFont.label(size: 11))
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(Color.omoiGray)
                            .foregroundStyle(Color.omoiWhite)
                            .overlay(Rectangle().stroke(Color.omoiGray, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(isPreviewLoading || !sanitizationManager.rules.enabled)
                }
                .padding(20)
            }
            
            // 3. Batch Actions (Collapsed feel)
            if !statsManager.sessions.isEmpty {
                VStack(spacing: 0) {
                    Divider().overlay(Color.omoiGray.opacity(0.5))
                    Button(action: sanitizeSelected) { // Simplified batch for now, could expand
                        HStack {
                            Text("APPLY TO \(selectedSessions.isEmpty ? "ALL" : "\(selectedSessions.count)") PAST SESSIONS")
                                .font(OmoiFont.label(size: 11))
                            Spacer()
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(Color.omoiTeal)
                        .padding(20)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSanitizingAll)
                }
            }
        }
    }
    
    @ViewBuilder
    private func outputLayerContent() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            
            HStack {
                Text("RETROSPECTIVE PROMPT")
                    .font(OmoiFont.label(size: 10))
                    .foregroundStyle(Color.omoiMuted)
                Spacer()
                Button("Reset Default") {
                    sanitizationManager.retrospectivePrompt = SanitizationManager.defaultRetrospectivePrompt
                }
                .font(OmoiFont.label(size: 10))
                .foregroundStyle(Color.omoiOrange)
                .buttonStyle(.plain)
            }
            
            TextEditor(text: $sanitizationManager.retrospectivePrompt)
                .font(OmoiFont.mono(size: 12))
                .scrollContentBackground(.hidden)
                .background(Color.omoiBlack)
                .foregroundStyle(Color.omoiOffWhite)
                .frame(minHeight: 250)
                .overlay(Rectangle().stroke(Color.omoiGray, lineWidth: 1))
            
            HStack(spacing: 12) {
                Image(systemName: "info.circle")
                Text("This prompt is used by the Retro tab to generate your daily synthesis.")
                    .font(OmoiFont.caption)
            }
            .foregroundStyle(Color.omoiMuted)
        }
        .padding(20)
    }
    
    @ViewBuilder
    private func systemCoreContent() -> some View {
        VStack(spacing: 0) {
            // Accessibility
            settingsRow {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ACCESSIBILITY")
                            .font(OmoiFont.label(size: 11))
                            .foregroundStyle(Color.omoiWhite)
                        Text("Required for auto-paste functionality.")
                            .font(OmoiFont.caption)
                            .foregroundStyle(Color.omoiMuted)
                    }
                    Spacer()
                    if AccessibilityPermissions.hasAccessibilityPermission() {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("GRANTED")
                        }
                        .font(OmoiFont.label(size: 11))
                        .foregroundStyle(Color.omoiGreen)
                    } else {
                        Button("GRANT PERMISSION") {
                            AccessibilityPermissions.openAccessibilitySettings()
                        }
                        .font(OmoiFont.label(size: 10))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.omoiOrange)
                        .foregroundStyle(Color.omoiBlack)
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider().overlay(Color.omoiGray.opacity(0.5))

            // Auto-Restart
            settingsRow {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AUTO-RESTART")
                            .font(OmoiFont.label(size: 11))
                            .foregroundStyle(Color.omoiMuted)
                        Text("Launch at login and restart if killed")
                            .font(OmoiFont.caption)
                            .foregroundStyle(Color.omoiMuted)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { LaunchAgentManager.shared.isInstalled },
                        set: { enable in
                            if enable {
                                do {
                                    try LaunchAgentManager.shared.install()
                                    settingsStatusMessage = "Auto-restart enabled"
                                } catch {
                                    settingsStatusMessage = "Failed: \(error.localizedDescription)"
                                }
                            } else {
                                do {
                                    try LaunchAgentManager.shared.uninstall()
                                    settingsStatusMessage = "Auto-restart disabled"
                                } catch {
                                    settingsStatusMessage = "Failed: \(error.localizedDescription)"
                                }
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .tint(Color.omoiTeal)
                }
                if LaunchAgentManager.shared.isInstalled {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.omoiGreen)
                        Text("Omoi will automatically restart if closed or killed")
                            .font(OmoiFont.caption)
                            .foregroundStyle(Color.omoiGreen)
                    }
                }
            }

            Divider().overlay(Color.omoiGray.opacity(0.5))

            // Keyboard Shortcut
            settingsRow {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("RECORD SHORTCUT")
                            .font(OmoiFont.label(size: 11))
                            .foregroundStyle(Color.omoiMuted)
                            .frame(width: 120, alignment: .leading)
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .toggleRecord) { shortcut in
                            if let shortcut = shortcut {
                                self.shortcutDescription = ShortcutFormatter.format(shortcut)
                            } else {
                                self.shortcutDescription = "None"
                            }
                        }
                        .frame(minWidth: 150, minHeight: 30)
                    }
                    HStack {
                        Text("Current:")
                            .font(OmoiFont.label(size: 10))
                            .foregroundStyle(Color.omoiMuted)
                        Text(shortcutDescription)
                            .font(OmoiFont.mono(size: 12))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.omoiTeal.opacity(0.2))
                            .foregroundStyle(Color.omoiTeal)
                        Spacer()
                    }
                    Text("Click recorder and press desired key combination")
                        .font(OmoiFont.caption)
                        .foregroundStyle(Color.omoiMuted)
                    Text("Note: Fn key combinations not supported")
                        .font(OmoiFont.caption)
                        .foregroundStyle(Color.omoiOrange)
                }
            }

            Divider().overlay(Color.omoiGray.opacity(0.5))

            // Language
            settingsRow {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("LANGUAGE")
                            .font(OmoiFont.label(size: 11))
                            .foregroundStyle(Color.omoiMuted)
                            .frame(width: 120, alignment: .leading)
                        Spacer()
                        Picker("", selection: $transcriptionLanguage) {
                            Text("Auto-Detect").tag("auto")
                            Text("English").tag("en")
                            Text("Spanish").tag("es")
                            Text("French").tag("fr")
                            Text("German").tag("de")
                            Text("Italian").tag("it")
                            Text("Portuguese").tag("pt")
                            Text("Dutch").tag("nl")
                            Text("Russian").tag("ru")
                            Text("Chinese").tag("zh")
                            Text("Japanese").tag("ja")
                            Text("Korean").tag("ko")
                            Text("Arabic").tag("ar")
                            Text("Hindi").tag("hi")
                            Text("Turkish").tag("tr")
                            Text("Polish").tag("pl")
                            Text("Swedish").tag("sv")
                            Text("Norwegian").tag("no")
                            Text("Danish").tag("da")
                            Text("Finnish").tag("fi")
                        }
                        .labelsHidden()
                        .frame(minWidth: 150)
                    }
                    Text("Auto-detect will identify the language automatically")
                        .font(OmoiFont.caption)
                        .foregroundStyle(Color.omoiMuted)
                    Text("Whisper supports 99 languages total")
                        .font(OmoiFont.caption)
                        .foregroundStyle(Color.omoiTeal.opacity(0.7))
                }
            }

            Divider().overlay(Color.omoiGray.opacity(0.5))

            // Save Recordings
            settingsRow {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("SAVE RECORDINGS FOR PLAYBACK")
                            .font(OmoiFont.label(size: 11))
                            .foregroundStyle(Color.omoiWhite)
                        Spacer()
                        Toggle("", isOn: $saveRecordingsForPlayback)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    HStack {
                        Text("STORAGE")
                            .font(OmoiFont.label(size: 10))
                            .foregroundStyle(Color.omoiMuted)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: StorageManager.shared.recordingsStorageSize, countStyle: .file))
                            .font(OmoiFont.mono(size: 12))
                            .foregroundStyle(Color.omoiWhite)
                        Text("(\(StorageManager.shared.recordingsCount))")
                            .font(OmoiFont.mono(size: 11))
                            .foregroundStyle(Color.omoiMuted)
                    }
                    Button(action: { showingDeleteRecordingsAlert = true }) {
                        Text("DELETE ALL RECORDINGS")
                            .font(OmoiFont.label(size: 10))
                            .foregroundStyle(StorageManager.shared.recordingsCount == 0 ? Color.omoiGray : Color.omoiOrange)
                    }
                    .buttonStyle(.plain)
                    .disabled(StorageManager.shared.recordingsCount == 0)
                    Text("Recordings enable audio playback from history")
                        .font(OmoiFont.caption)
                        .foregroundStyle(Color.omoiMuted)
                }
            }

            Divider().overlay(Color.omoiGray.opacity(0.5))

            // Data
            settingsRow {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("INTEGRITY")
                            .font(OmoiFont.label(size: 10))
                            .foregroundStyle(Color.omoiMuted)
                        Spacer()
                        Text(integrityStatus.uppercased())
                            .font(OmoiFont.mono(size: 11))
                            .foregroundStyle(Color.omoiGreen)
                    }
                    if let info = historyInfo {
                        HStack {
                            Text("SESSIONS")
                                .font(OmoiFont.label(size: 10))
                                .foregroundStyle(Color.omoiMuted)
                            Spacer()
                            Text("\(info.sessionCount)")
                                .font(OmoiFont.mono(size: 14))
                                .foregroundStyle(Color.omoiWhite)
                            Text(ByteCountFormatter.string(fromByteCount: info.fileSize, countStyle: .file))
                                .font(OmoiFont.mono(size: 11))
                                .foregroundStyle(Color.omoiMuted)
                        }
                    }
                    HStack {
                        Text("BACKUPS")
                            .font(OmoiFont.label(size: 10))
                            .foregroundStyle(Color.omoiMuted)
                        Spacer()
                        Text("\(backups.count)")
                            .font(OmoiFont.mono(size: 14))
                            .foregroundStyle(Color.omoiWhite)
                    }
                    HStack(spacing: 1) {
                        settingsButton("EXPORT") { showingExportPanel = true }
                        settingsButton("IMPORT") { showingImportPanel = true }
                        settingsButton("BACKUP") { createManualBackup() }
                    }
                    .background(Color.omoiGray)
                    if let message = settingsStatusMessage {
                        Text(message.uppercased())
                            .font(OmoiFont.label(size: 10))
                            .foregroundStyle(Color.omoiGreen)
                    }
                    Button(action: { StorageManager.shared.revealInFinder() }) {
                        Text("OPEN DATA FOLDER")
                            .font(OmoiFont.label(size: 10))
                            .foregroundStyle(Color.omoiTeal)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            shortcutDescription = ShortcutFormatter.format(KeyboardShortcuts.getShortcut(for: .toggleRecord))
            refreshDataStatus()
        }
        .fileExporter(
            isPresented: $showingExportPanel,
            document: HistoryDocument(),
            contentType: .json,
            defaultFilename: "omoi_history_\(Date().formatted(date: .numeric, time: .omitted)).json"
        ) { result in
            switch result {
            case .success(let url):
                showSettingsStatus("Exported to \(url.lastPathComponent)")
            case .failure(let error):
                showSettingsStatus("Export failed: \(error.localizedDescription)")
            }
        }
        .fileImporter(
            isPresented: $showingImportPanel,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importHistory(from: url)
                }
            case .failure(let error):
                showSettingsStatus("Import failed: \(error.localizedDescription)")
            }
        }
        .alert("Restore Backup?", isPresented: $showingRestoreAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Restore", role: .destructive) {
                if let backup = selectedBackup {
                    restoreBackup(backup)
                }
            }
        } message: {
            if let backup = selectedBackup {
                Text("This will replace your current history with \(backup.sessionCount) sessions from \(backup.date.formatted()). A backup of your current data will be created first.")
            }
        }
        .alert("Delete All Recordings?", isPresented: $showingDeleteRecordingsAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                StorageManager.shared.deleteAllRecordings()
                showSettingsStatus("All recordings deleted")
            }
        } message: {
            Text("This will permanently delete all \(StorageManager.shared.recordingsCount) audio recordings. Your transcription history will be preserved.")
        }
    }
    
    // MARK: - Helpers
    
    @ViewBuilder
    private func presetPill(_ preset: SanitizationPreset) -> some View {
        Button(action: { sanitizationManager.applyPreset(preset) }) {
            Text(preset.name.uppercased())
                .font(OmoiFont.label(size: 10))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    sanitizationManager.rules.activePresetId == preset.id
                    ? Color.omoiTeal
                    : Color.omoiBlack
                )
                .foregroundStyle(
                    sanitizationManager.rules.activePresetId == preset.id
                    ? Color.omoiBlack
                    : Color.omoiWhite
                )
                .overlay(Rectangle().stroke(Color.omoiGray, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !preset.isBuiltIn {
                Button(role: .destructive) {
                    sanitizationManager.deletePreset(preset)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
    
    @ViewBuilder
    private func savePresetSheet() -> some View {
        VStack(spacing: 20) {
            Text("SAVE PRESET")
                .font(OmoiFont.heading(size: 16))
                .foregroundStyle(Color.omoiWhite)
            
            TextField("Preset Name", text: $newPresetName)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.omoiGray)
                .foregroundStyle(Color.omoiWhite)
            
            HStack {
                Button("Cancel") { showSavePresetSheet = false }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.omoiMuted)
                Spacer()
                Button("Save") {
                    if !newPresetName.isEmpty {
                        sanitizationManager.addPreset(name: newPresetName, instructions: sanitizationManager.rules.instructions)
                        newPresetName = ""
                        showSavePresetSheet = false
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.omoiTeal)
                .foregroundStyle(Color.omoiBlack)
            }
        }
        .padding(24)
        .background(Color.omoiDarkGray)
        .frame(width: 300, height: 200)
    }
    
    // MARK: - Settings Helpers

    @ViewBuilder
    private func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading) {
            content()
        }
        .padding(20)
    }

    @ViewBuilder
    private func settingsButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(OmoiFont.label(size: 10))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.omoiDarkGray)
                .foregroundStyle(Color.omoiTeal)
        }
        .buttonStyle(.plain)
    }

    private func refreshDataStatus() {
        backups = StorageManager.shared.listAllBackups()
        historyInfo = StorageManager.shared.currentHistoryInfo

        let result = StorageManager.shared.verifyAndRecoverHistory()
        switch result {
        case .valid(let count):
            integrityStatus = "Verified (\(count) sessions)"
        case .corrupted(let error):
            integrityStatus = "Error: \(error)"
        case .missing:
            integrityStatus = "No data yet"
        case .recovered(let count, let backup):
            integrityStatus = "Recovered \(count) from \(backup)"
        }
    }

    private func createManualBackup() {
        if let url = StorageManager.shared.createManualBackup() {
            showSettingsStatus("Backup created: \(url.lastPathComponent)")
            refreshDataStatus()
        } else {
            showSettingsStatus("No data to backup")
        }
    }

    private func importHistory(from url: URL) {
        do {
            let count = try StorageManager.shared.importHistory(from: url, merge: true)
            showSettingsStatus("Imported \(count) new sessions")
            refreshDataStatus()
        } catch {
            showSettingsStatus("Import failed: \(error.localizedDescription)")
        }
    }

    private func restoreBackup(_ backup: StorageManager.BackupInfo) {
        do {
            let count = try StorageManager.shared.restoreFromBackup(backup)
            showSettingsStatus("Restored \(count) sessions")
            refreshDataStatus()
        } catch {
            showSettingsStatus("Restore failed: \(error.localizedDescription)")
        }
    }

    private func showSettingsStatus(_ message: String) {
        withAnimation {
            settingsStatusMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                settingsStatusMessage = nil
            }
        }
    }

    // MARK: - Logic

    private func previewSanitization() {
        guard let mostRecent = statsManager.sessions.first else { return }
        isPreviewLoading = true
        previewError = nil
        previewSanitized = nil
        
        Task {
            do {
                let sanitized = try await APIService().sanitizeText(
                    text: mostRecent.text,
                    instructions: sanitizationManager.rules.instructions
                )
                await MainActor.run {
                    previewSanitized = sanitized
                    isPreviewLoading = false
                }
            } catch {
                await MainActor.run {
                    previewError = error.localizedDescription
                    showPreviewError = true
                    isPreviewLoading = false
                }
            }
        }
    }
    
    private func sanitizeSelected() {
        let sessions = statsManager.sessions
        guard !sessions.isEmpty else { return }

        isSanitizingAll = true

        Task {
            let api = APIService()
            for session in sessions {
                do {
                    let sanitized = try await api.sanitizeText(text: session.text, instructions: sanitizationManager.rules.instructions)
                    await MainActor.run {
                        statsManager.updateSessionSanitized(session.id, sanitizedText: sanitized)
                    }
                } catch {
                    print("Failed to sanitize session: \(session.id)")
                }
            }
            await MainActor.run { isSanitizingAll = false }
        }
    }
}

// MARK: - Document for Export

struct HistoryDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    init() {}

    init(configuration: ReadConfiguration) throws {
        // Not used for export-only
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let historyPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Omoi/history.json")
        let data = try Data(contentsOf: historyPath)
        return FileWrapper(regularFileWithContents: data)
    }
}
