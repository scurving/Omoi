import Cocoa

struct StorageManager {
    static let shared = StorageManager()

    // Use ~/Documents/Omoi/
    private var dataDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory.appendingPathComponent("Omoi")
    }

    private var historyFile: URL {
        return dataDirectory.appendingPathComponent("history.json")
    }

    private var backupDirectory: URL {
        return dataDirectory.appendingPathComponent("backups")
    }

    private var preBuildBackupDirectory: URL {
        return dataDirectory.appendingPathComponent("pre-build-backups")
    }

    private var goalsFile: URL {
        return dataDirectory.appendingPathComponent("goals.json")
    }
    
    private var retrospectivesFile: URL {
        return dataDirectory.appendingPathComponent("retrospectives.json")
    }

    // MARK: - Data Integrity

    enum DataIntegrityResult {
        case valid(sessionCount: Int)
        case corrupted(error: String)
        case missing
        case recovered(sessionCount: Int, fromBackup: String)
    }

    func verifyAndRecoverHistory() -> DataIntegrityResult {
        guard FileManager.default.fileExists(atPath: historyFile.path) else {
            return .missing
        }

        // Try to load and validate
        do {
            let data = try Data(contentsOf: historyFile)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let sessions = try decoder.decode([TranscriptionSession].self, from: data)

            // Validate basic structure
            for session in sessions {
                guard !session.id.uuidString.isEmpty else {
                    throw NSError(domain: "DataIntegrity", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid session ID"])
                }
            }

            print("✅ History integrity verified: \(sessions.count) sessions")
            return .valid(sessionCount: sessions.count)

        } catch {
            print("⚠️ History file corrupted: \(error.localizedDescription)")
            return attemptRecovery(originalError: error.localizedDescription)
        }
    }

    private func attemptRecovery(originalError: String) -> DataIntegrityResult {
        print("🔄 Attempting recovery from backups...")

        // Collect all backup sources
        var backupFiles: [(url: URL, date: Date)] = []

        // Check regular backups
        if let regularBackups = try? FileManager.default.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.creationDateKey]) {
            for file in regularBackups where file.lastPathComponent.hasPrefix("history_") {
                let date = (try? file.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                backupFiles.append((file, date))
            }
        }

        // Check pre-build backups
        if let preBuildDirs = try? FileManager.default.contentsOfDirectory(at: preBuildBackupDirectory, includingPropertiesForKeys: [.creationDateKey]) {
            for dir in preBuildDirs where dir.lastPathComponent.hasPrefix("backup_") {
                let historyInBackup = dir.appendingPathComponent("history.json")
                if FileManager.default.fileExists(atPath: historyInBackup.path) {
                    let date = (try? dir.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    backupFiles.append((historyInBackup, date))
                }
            }
        }

        // Sort by date, newest first
        backupFiles.sort { $0.date > $1.date }

        // Try each backup until one works
        for backup in backupFiles {
            do {
                let data = try Data(contentsOf: backup.url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let sessions = try decoder.decode([TranscriptionSession].self, from: data)

                // Valid backup found - restore it
                try data.write(to: historyFile, options: .atomic)

                let backupName = backup.url.deletingLastPathComponent().lastPathComponent
                print("✅ Recovered \(sessions.count) sessions from: \(backupName)")
                return .recovered(sessionCount: sessions.count, fromBackup: backupName)

            } catch {
                continue // Try next backup
            }
        }

        return .corrupted(error: originalError)
    }

    // UserDefaults keys for migration
    private let userDefaultsDomains = ["Omoi", "com.omoi.Omoi"]
    private let sessionsKey = "Omoi.Sessions"

    init() {
        createDirectoryIfNeeded()
    }
    
    private func createDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: dataDirectory.path) {
            try? FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        if !FileManager.default.fileExists(atPath: backupDirectory.path) {
            try? FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true, attributes: nil)
        }
    }

    // MARK: - Backup

    private func createBackup() {
        guard FileManager.default.fileExists(atPath: historyFile.path) else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let backupFile = backupDirectory.appendingPathComponent("history_\(timestamp).json")

        do {
            try FileManager.default.copyItem(at: historyFile, to: backupFile)
            print("📦 Created backup: \(backupFile.lastPathComponent)")
        } catch {
            print("⚠️ Failed to create backup: \(error)")
        }
    }

    // Backups are kept forever - user manually cleans up if needed

    // MARK: - Migration from UserDefaults

    func migrateFromUserDefaultsIfNeeded() -> [TranscriptionSession] {
        var migratedSessions: [TranscriptionSession] = []

        for domain in userDefaultsDomains {
            if let defaults = UserDefaults(suiteName: domain),
               let data = defaults.data(forKey: sessionsKey) {
                do {
                    let sessions = try decodeUserDefaultsSessions(data)
                    migratedSessions.append(contentsOf: sessions)
                    print("📥 Found \(sessions.count) sessions in UserDefaults domain: \(domain)")
                } catch {
                    print("⚠️ Failed to decode sessions from \(domain): \(error)")
                }
            }
        }

        // Also check standard UserDefaults
        if let data = UserDefaults.standard.data(forKey: sessionsKey) {
            do {
                let sessions = try decodeUserDefaultsSessions(data)
                migratedSessions.append(contentsOf: sessions)
                print("📥 Found \(sessions.count) sessions in standard UserDefaults")
            } catch {
                print("⚠️ Failed to decode sessions from standard UserDefaults: \(error)")
            }
        }

        return migratedSessions
    }

    private func decodeUserDefaultsSessions(_ data: Data) throws -> [TranscriptionSession] {
        // UserDefaults stores with reference date timestamps (seconds since Jan 1, 2001)
        let decoder = JSONDecoder()

        // Custom strategy for Apple reference date
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let timestamp = try? container.decode(Double.self) {
                // Apple reference date: Jan 1, 2001
                return Date(timeIntervalSinceReferenceDate: timestamp)
            }
            if let dateString = try? container.decode(String.self) {
                let formatter = ISO8601DateFormatter()
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date")
        }

        return try decoder.decode([TranscriptionSession].self, from: data)
    }
    
    func saveSessions(_ sessions: [TranscriptionSession]) {
        // Create backup before saving
        createBackup()

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted // Readable JSON
            encoder.dateEncodingStrategy = .iso8601 // Standard date string

            let data = try encoder.encode(sessions)
            try data.write(to: historyFile, options: .atomic)
            print("💾 Saved history to: \(historyFile.path) (\(sessions.count) sessions)")

        } catch {
            print("❌ Failed to save history: \(error)")
        }
    }
    
    func loadSessions() -> [TranscriptionSession] {
        var fileSessions: [TranscriptionSession] = []

        // Load from JSON file
        if FileManager.default.fileExists(atPath: historyFile.path) {
            do {
                let data = try Data(contentsOf: historyFile)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                fileSessions = try decoder.decode([TranscriptionSession].self, from: data)
                print("📂 Loaded \(fileSessions.count) sessions from JSON file")
            } catch {
                print("❌ Failed to load history: \(error)")
            }
        }

        // Check for UserDefaults data to migrate
        let userDefaultsSessions = migrateFromUserDefaultsIfNeeded()

        if !userDefaultsSessions.isEmpty {
            // Merge sessions, avoiding duplicates by ID
            let existingIDs = Set(fileSessions.map { $0.id })
            let newSessions = userDefaultsSessions.filter { !existingIDs.contains($0.id) }

            if !newSessions.isEmpty {
                print("🔄 Migrating \(newSessions.count) sessions from UserDefaults")
                fileSessions.append(contentsOf: newSessions)

                // Save merged data and clear UserDefaults
                let merged = fileSessions.sorted { $0.timestamp > $1.timestamp }
                saveSessions(merged)
                clearUserDefaultsSessions()

                return merged
            }
        }

        return fileSessions.sorted { $0.timestamp > $1.timestamp }
    }

    private func clearUserDefaultsSessions() {
        for domain in userDefaultsDomains {
            if let defaults = UserDefaults(suiteName: domain) {
                defaults.removeObject(forKey: sessionsKey)
                print("🧹 Cleared sessions from UserDefaults domain: \(domain)")
            }
        }
        UserDefaults.standard.removeObject(forKey: sessionsKey)
    }
    
    // MARK: - Goals Storage

    func saveGoals(_ goals: [UserGoal]) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(goals)
            try data.write(to: goalsFile, options: .atomic)
            print("💾 Saved goals to: \(goalsFile.path)")

        } catch {
            print("❌ Failed to save goals: \(error)")
        }
    }

    func loadGoals() -> [UserGoal] {
        guard FileManager.default.fileExists(atPath: goalsFile.path) else { return [] }

        do {
            let data = try Data(contentsOf: goalsFile)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let goals = try decoder.decode([UserGoal].self, from: data)
            return goals.sorted { $0.createdAt > $1.createdAt }

        } catch {
            print("❌ Failed to load goals: \(error)")
            return []
        }
    }
    
    // MARK: - Retrospectives Storage
    
    struct DailyRetro: Codable {
        let date: Date
        let content: String
    }
    
    func saveRetrospective(_ text: String, for date: Date) {
        var retros = loadRetrospectivesMap()
        // Normalized date (start of day) to avoid time issues
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        retros[startOfDay] = text
        
        saveRetrospectivesMap(retros)
    }
    
    func loadRetrospective(for date: Date) -> String? {
        let retros = loadRetrospectivesMap()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        return retros[startOfDay]
    }
    
    private func loadRetrospectivesMap() -> [Date: String] {
        guard FileManager.default.fileExists(atPath: retrospectivesFile.path) else { return [:] }
        
        do {
            let data = try Data(contentsOf: retrospectivesFile)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let items = try decoder.decode([DailyRetro].self, from: data)
            
            // Convert list to map
            return Dictionary(uniqueKeysWithValues: items.map { ($0.date, $0.content) })
        } catch {
            print("❌ Failed to load retrospectives: \(error)")
            return [:]
        }
    }
    
    private func saveRetrospectivesMap(_ map: [Date: String]) {
        do {
            let items = map.map { DailyRetro(date: $0.key, content: $0.value) }
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            
            let data = try encoder.encode(items)
            try data.write(to: retrospectivesFile, options: .atomic)
             print("💾 Saved retrospectives to: \(retrospectivesFile.path)")
        } catch {
            print("❌ Failed to save retrospectives: \(error)")
        }
    }

    // Helper to reveal file in Finder (for user convenience)
    func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([historyFile])
    }

    // MARK: - Manual Backup & Export

    struct BackupInfo {
        let name: String
        let date: Date
        let sessionCount: Int
        let fileSize: Int64
        let url: URL
    }

    func listAllBackups() -> [BackupInfo] {
        var backups: [BackupInfo] = []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Regular backups
        if let files = try? FileManager.default.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey]) {
            for file in files where file.lastPathComponent.hasPrefix("history_") {
                if let info = backupInfoFromFile(file, decoder: decoder) {
                    backups.append(info)
                }
            }
        }

        // Pre-build backups
        if let dirs = try? FileManager.default.contentsOfDirectory(at: preBuildBackupDirectory, includingPropertiesForKeys: [.creationDateKey]) {
            for dir in dirs where dir.lastPathComponent.hasPrefix("backup_") {
                let historyFile = dir.appendingPathComponent("history.json")
                if FileManager.default.fileExists(atPath: historyFile.path),
                   let info = backupInfoFromFile(historyFile, decoder: decoder, nameOverride: "pre-build: \(dir.lastPathComponent)") {
                    backups.append(info)
                }
            }
        }

        return backups.sorted { $0.date > $1.date }
    }

    private func backupInfoFromFile(_ url: URL, decoder: JSONDecoder, nameOverride: String? = nil) -> BackupInfo? {
        guard let values = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey]),
              let date = values.creationDate,
              let size = values.fileSize else { return nil }

        var sessionCount = 0
        if let data = try? Data(contentsOf: url),
           let sessions = try? decoder.decode([TranscriptionSession].self, from: data) {
            sessionCount = sessions.count
        }

        return BackupInfo(
            name: nameOverride ?? url.lastPathComponent,
            date: date,
            sessionCount: sessionCount,
            fileSize: Int64(size),
            url: url
        )
    }

    func exportHistory(to destinationURL: URL) throws {
        guard FileManager.default.fileExists(atPath: historyFile.path) else {
            throw NSError(domain: "StorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No history file exists"])
        }
        try FileManager.default.copyItem(at: historyFile, to: destinationURL)
        print("📤 Exported history to: \(destinationURL.path)")
    }

    func importHistory(from sourceURL: URL, merge: Bool = true) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let importedData = try Data(contentsOf: sourceURL)
        let importedSessions = try decoder.decode([TranscriptionSession].self, from: importedData)

        if merge {
            // Merge with existing
            var existing = loadSessions()
            let existingIDs = Set(existing.map { $0.id })
            let newSessions = importedSessions.filter { !existingIDs.contains($0.id) }
            existing.append(contentsOf: newSessions)
            saveSessions(existing.sorted { $0.timestamp > $1.timestamp })
            print("📥 Imported \(newSessions.count) new sessions (merged with existing)")
            return newSessions.count
        } else {
            // Replace entirely
            createBackup() // Safety backup first
            saveSessions(importedSessions.sorted { $0.timestamp > $1.timestamp })
            print("📥 Imported \(importedSessions.count) sessions (replaced existing)")
            return importedSessions.count
        }
    }

    func restoreFromBackup(_ backup: BackupInfo) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try Data(contentsOf: backup.url)
        let sessions = try decoder.decode([TranscriptionSession].self, from: data)

        createBackup() // Safety backup before restore
        try data.write(to: historyFile, options: .atomic)
        print("🔄 Restored \(sessions.count) sessions from: \(backup.name)")
        return sessions.count
    }

    func createManualBackup(named name: String? = nil) -> URL? {
        guard FileManager.default.fileExists(atPath: historyFile.path) else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let backupName = name ?? "manual_\(timestamp)"
        let backupFile = backupDirectory.appendingPathComponent("\(backupName).json")

        do {
            try FileManager.default.copyItem(at: historyFile, to: backupFile)
            print("💾 Created manual backup: \(backupFile.lastPathComponent)")
            return backupFile
        } catch {
            print("❌ Failed to create manual backup: \(error)")
            return nil
        }
    }

    var currentHistoryInfo: (sessionCount: Int, fileSize: Int64, lastModified: Date?)? {
        guard FileManager.default.fileExists(atPath: historyFile.path) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let data = try? Data(contentsOf: historyFile),
              let sessions = try? decoder.decode([TranscriptionSession].self, from: data),
              let values = try? historyFile.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) else {
            return nil
        }

        return (sessions.count, Int64(values.fileSize ?? 0), values.contentModificationDate)
    }

    // MARK: - Audio Recordings Storage

    private var recordingsDirectory: URL {
        return dataDirectory.appendingPathComponent("recordings")
    }

    /// Save a recording for a session
    func saveRecording(data: Data, for sessionID: UUID) -> String? {
        let fileName = "\(sessionID.uuidString).wav"
        let url = recordingsDirectory.appendingPathComponent(fileName)

        do {
            try FileManager.default.createDirectory(
                at: recordingsDirectory,
                withIntermediateDirectories: true
            )
            try data.write(to: url)
            print("🎵 Saved recording: \(fileName)")
            return fileName
        } catch {
            print("❌ Failed to save recording: \(error)")
            return nil
        }
    }

    /// Get URL for a recording file
    func recordingURL(for fileName: String) -> URL {
        return recordingsDirectory.appendingPathComponent(fileName)
    }

    /// Delete a specific recording
    func deleteRecording(fileName: String) {
        let url = recordingsDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
        print("🗑️ Deleted recording: \(fileName)")
    }

    /// Delete all recordings
    func deleteAllRecordings() {
        try? FileManager.default.removeItem(at: recordingsDirectory)
        print("🗑️ Deleted all recordings")
    }

    /// Total storage used by recordings in bytes
    var recordingsStorageSize: Int64 {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: recordingsDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }

        return files.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + Int64(size)
        }
    }

    /// Number of saved recordings
    var recordingsCount: Int {
        (try? FileManager.default.contentsOfDirectory(atPath: recordingsDirectory.path))?.count ?? 0
    }
}
