import SwiftUI
import KeyboardShortcuts
import UniformTypeIdentifiers

// MARK: - Omoi Settings

struct SettingsView: View {
    @State private var shortcutDescription: String = ""
    @State private var backups: [StorageManager.BackupInfo] = []
    @State private var historyInfo: (sessionCount: Int, fileSize: Int64, lastModified: Date?)? = nil
    @State private var showingExportPanel = false
    @State private var showingImportPanel = false
    @State private var showingRestoreAlert = false
    @State private var selectedBackup: StorageManager.BackupInfo? = nil
    @State private var statusMessage: String? = nil
    @State private var integrityStatus: String = "Checking..."
    @State private var showingDeleteRecordingsAlert = false

    @AppStorage("saveRecordingsForPlayback") private var saveRecordingsForPlayback = true
    @AppStorage("transcriptionLanguage") private var transcriptionLanguage = "auto"

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                Text("SETTINGS")
                    .font(OmoiFont.heading(size: 18))
                    .foregroundStyle(Color.omoiWhite)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color.omoiDarkGray)

                // Startup Section
                settingsSection(title: "STARTUP") {
                    VStack(alignment: .leading, spacing: 12) {
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
                                            statusMessage = "Auto-restart enabled"
                                        } catch {
                                            statusMessage = "Failed: \(error.localizedDescription)"
                                        }
                                    } else {
                                        do {
                                            try LaunchAgentManager.shared.uninstall()
                                            statusMessage = "Auto-restart disabled"
                                        } catch {
                                            statusMessage = "Failed: \(error.localizedDescription)"
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
                }

                // Keyboard Shortcuts Section
                settingsSection(title: "KEYBOARD") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("RECORD")
                                .font(OmoiFont.label(size: 11))
                                .foregroundStyle(Color.omoiMuted)
                                .frame(width: 80, alignment: .leading)

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

                        // Current shortcut display
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

                // Transcription Settings Section
                settingsSection(title: "TRANSCRIPTION") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("LANGUAGE")
                                .font(OmoiFont.label(size: 11))
                                .foregroundStyle(Color.omoiMuted)
                                .frame(width: 80, alignment: .leading)

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

                // Data Protection Section
                settingsSection(title: "DATA") {
                    VStack(alignment: .leading, spacing: 12) {
                        // Status row
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

                        // Action buttons - brutalist style
                        HStack(spacing: 1) {
                            settingsButton("EXPORT") { showingExportPanel = true }
                            settingsButton("IMPORT") { showingImportPanel = true }
                            settingsButton("BACKUP") { createManualBackup() }
                        }
                        .background(Color.omoiGray)

                        // Status message
                        if let message = statusMessage {
                            Text(message.uppercased())
                                .font(OmoiFont.label(size: 10))
                                .foregroundStyle(Color.omoiGreen)
                        }

                        // Open folder button
                        Button(action: { StorageManager.shared.revealInFinder() }) {
                            Text("OPEN DATA FOLDER")
                                .font(OmoiFont.label(size: 10))
                                .foregroundStyle(Color.omoiTeal)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Recordings Section
                settingsSection(title: "RECORDINGS") {
                    VStack(alignment: .leading, spacing: 12) {
                        // Toggle row
                        HStack {
                            Text("SAVE FOR PLAYBACK")
                                .font(OmoiFont.label(size: 11))
                                .foregroundStyle(Color.omoiWhite)
                            Spacer()
                            Toggle("", isOn: $saveRecordingsForPlayback)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }

                        // Storage info
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

                        // Delete button
                        Button(action: { showingDeleteRecordingsAlert = true }) {
                            Text("DELETE ALL")
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
            }
        }
        .background(Color.omoiBlack)
        .frame(width: 400, height: 650)
        .fileExporter(
            isPresented: $showingExportPanel,
            document: HistoryDocument(),
            contentType: .json,
            defaultFilename: "superwhispr_history_\(Date().formatted(date: .numeric, time: .omitted)).json"
        ) { result in
            switch result {
            case .success(let url):
                showStatus("Exported to \(url.lastPathComponent)")
            case .failure(let error):
                showStatus("Export failed: \(error.localizedDescription)")
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
                showStatus("Import failed: \(error.localizedDescription)")
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
                showStatus("All recordings deleted")
            }
        } message: {
            Text("This will permanently delete all \(StorageManager.shared.recordingsCount) audio recordings. Your transcription history will be preserved.")
        }
        .onAppear {
            print("🪟 [SettingsView] View appeared")
            updateShortcutDescription()
            refreshDataStatus()
        }
        .onChange(of: KeyboardShortcuts.getShortcut(for: .toggleRecord)) {
            updateShortcutDescription()
        }
    }

    private func updateShortcutDescription() {
        shortcutDescription = ShortcutFormatter.format(KeyboardShortcuts.getShortcut(for: .toggleRecord))
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
            showStatus("Backup created: \(url.lastPathComponent)")
            refreshDataStatus()
        } else {
            showStatus("No data to backup")
        }
    }

    private func importHistory(from url: URL) {
        do {
            let count = try StorageManager.shared.importHistory(from: url, merge: true)
            showStatus("Imported \(count) new sessions")
            refreshDataStatus()
        } catch {
            showStatus("Import failed: \(error.localizedDescription)")
        }
    }

    private func restoreBackup(_ backup: StorageManager.BackupInfo) {
        do {
            let count = try StorageManager.shared.restoreFromBackup(backup)
            showStatus("Restored \(count) sessions")
            refreshDataStatus()
        } catch {
            showStatus("Restore failed: \(error.localizedDescription)")
        }
    }

    private func showStatus(_ message: String) {
        withAnimation {
            statusMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                statusMessage = nil
            }
        }
    }

    // MARK: - Omoi Helpers

    @ViewBuilder
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(OmoiFont.label(size: 10))
                .foregroundStyle(Color.omoiMuted)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.omoiDarkGray)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color.omoiGray),
                    alignment: .top
                )

            VStack(alignment: .leading) {
                content()
            }
            .padding(20)
            .background(Color.omoiDarkGray)
        }
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
