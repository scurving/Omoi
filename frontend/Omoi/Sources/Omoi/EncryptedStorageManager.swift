import Foundation
import CryptoKit
import Security
import os.log

// MARK: - EncryptedStorageManager
//
// Handles AES-256-GCM encryption of typing data at rest.
// Key is stored in macOS Keychain, scoped to Omoi's bundle ID.
// Files on disk are opaque sealed boxes — useless without the Keychain key.

final class EncryptedStorageManager {
    static let shared = EncryptedStorageManager()

    private let logger = Logger(subsystem: "com.wisprrd.Omoi", category: "EncryptedStorage")

    // MARK: - File Paths

    private var dataDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("Omoi")
    }

    private var typingFile: URL {
        dataDirectory.appendingPathComponent("typing.enc")
    }

    private var backupDirectory: URL {
        dataDirectory.appendingPathComponent("backups")
    }

    // MARK: - In-Memory Cache

    /// Live typing storage — decrypted from disk on init, kept in memory.
    private(set) var typingStorage: TypingStorage

    // MARK: - Flush Timer

    /// Flush to disk every 60s while typing is active. Also flushes on app termination.
    private var flushTimer: Timer?
    private var isDirty = false

    // MARK: - Keychain Constants

    private let keychainService = "com.wisprrd.Omoi.TypingKey"
    private let keychainAccount = "AES256Key"

    // MARK: - Init

    private init() {
        typingStorage = TypingStorage()
        ensureDirectoriesExist()
        load()
        startFlushTimer()
    }

    private func ensureDirectoriesExist() {
        try? FileManager.default.createDirectory(
            at: dataDirectory,
            withIntermediateDirectories: true
        )
        try? FileManager.default.createDirectory(
            at: backupDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Public API

    /// Call from app termination / scene phase changes
    func flush() {
        save()
    }

    /// Add a typing burst session
    func addTypingSession(_ session: TypingSession) {
        typingStorage.addSession(session)
        markDirty()
    }

    /// Roll an active accumulator into the current hourly aggregate
    func rollAccumulator(_ accumulator: ActiveTypingAccumulator) {
        typingStorage.rollAccumulatorIntoHour(accumulator, hour: Date())
        markDirty()
    }

    /// WPM breakdown by keyboard (includes today's sessions)
    var wpmByKeyboard: [KeyboardSource: Double] {
        typingStorage.wpmByKeyboard()
    }

    /// Today's typed word count
    var todayTypedWords: Int {
        typingStorage.todayTypedWords
    }

    /// Average typed WPM
    var averageTypedWpm: Double {
        typingStorage.averageTypedWpm
    }

    // MARK: - Mark Dirty

    private func markDirty() {
        isDirty = true
        NotificationCenter.default.post(name: .typingDataChanged, object: nil)
    }

    private func startFlushTimer() {
        // Every 60 seconds while app is alive
        flushTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isDirty {
                self.save()
            }
        }
    }

    // MARK: - Load (Decrypt)

    private func load() {
        guard FileManager.default.fileExists(atPath: typingFile.path) else {
            logger.info("No typing.enc found — starting fresh")
            return
        }

        // Try main file, fall back to backups
        do {
            try loadFrom(url: typingFile)
            logger.info("Loaded typing data from disk")
            return
        } catch {
            logger.warning("Failed to load typing.enc: \(error.localizedDescription)")
        }

        // Attempt recovery from backups
        if let recovered = recoverFromBackup() {
            typingStorage = recovered
            logger.info("Recovered typing data from backup")
        } else {
            logger.error("All recovery attempts failed — starting fresh")
            typingStorage = TypingStorage()
        }
    }

    private func loadFrom(url: URL) throws {
        let sealedBoxData = try Data(contentsOf: url)

        guard let key = retrieveOrCreateKey() else {
            throw EncryptedStorageError.keychainUnavailable
        }

        let sealedBox = try AES.GCM.SealedBox(combined: sealedBoxData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        typingStorage = try decoder.decode(TypingStorage.self, from: decryptedData)
    }

    private func recoverFromBackup() -> TypingStorage? {
        guard let backupFiles = try? FileManager.default.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return nil }

        let encBackups = backupFiles
            .filter { $0.lastPathComponent.hasPrefix("typing_") && $0.pathExtension == "enc" }
            .sorted {
                let a = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let b = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return a > b  // Newest first
            }

        for backupURL in encBackups {
            do {
                try loadFrom(url: backupURL)
                logger.info("Recovered from: \(backupURL.lastPathComponent)")
                return typingStorage
            } catch {
                continue
            }
        }

        return nil
    }

    // MARK: - Save (Encrypt)

    private func save() {
        guard isDirty else { return }
        isDirty = false

        logger.debug("Flushing typing data to disk")

        // Create backup before writing
        createBackup()

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(typingStorage)

            guard let key = retrieveOrCreateKey() else {
                throw EncryptedStorageError.keychainUnavailable
            }

            let sealedBox = try AES.GCM.seal(jsonData, using: key)
            guard let combined = sealedBox.combined else {
                throw EncryptedStorageError.encryptionFailed
            }

            // Atomic write to final path (Foundation's .atomic handles temp+rename internally)
            try combined.write(to: typingFile, options: .atomic)

            // Clean up orphaned temp files from prior buggy version
            cleanupTempFiles()

            logger.info("Saved \(self.typingStorage.sessions.count) typing sessions (\(combined.count) bytes encrypted)")

        } catch {
            logger.error("Failed to save typing data: \(error.localizedDescription)")
        }
    }

    // MARK: - Backup

    private func createBackup() {
        guard FileManager.default.fileExists(atPath: typingFile.path) else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let backupFile = backupDirectory.appendingPathComponent("typing_\(timestamp).enc")

        do {
            try FileManager.default.copyItem(at: typingFile, to: backupFile)
            logger.debug("Created backup: \(backupFile.lastPathComponent)")
        } catch {
            logger.warning("Failed to create backup: \(error.localizedDescription)")
        }
    }

    private func cleanupTempFiles() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dataDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        for file in files where file.lastPathComponent.hasPrefix("typing.tmp.") {
            try? FileManager.default.removeItem(at: file)
        }
    }

    // MARK: - Keychain

    /// Retrieves the key from Keychain, or creates + stores one if absent.
    private func retrieveOrCreateKey() -> SymmetricKey? {
        if let existing = retrieveKeyFromKeychain() {
            return existing
        }
        return createAndStoreKey()
    }

    private func retrieveKeyFromKeychain() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let keyData = result as? Data,
              keyData.count == 32 else {
            return nil
        }

        return SymmetricKey(data: keyData)
    }

    @discardableResult
    private func createAndStoreKey() -> SymmetricKey? {
        let key = SymmetricKey(size: .bits256)

        let keyData = key.withUnsafeBytes { Data($0) }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        // Delete any existing key first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            logger.info("Generated and stored new AES-256 key in Keychain")
        } else {
            logger.error("Failed to store key in Keychain: status=\(status)")
            return nil
        }

        return key
    }

    // MARK: - Debug / Verification

    /// Security test: verify the encrypted file is not readable as JSON
    func verifyEncrypted() -> Bool {
        guard FileManager.default.fileExists(atPath: typingFile.path),
              let data = try? Data(contentsOf: typingFile) else {
            return false
        }

        // AES-GCM sealed boxes are not valid UTF-8, and certainly not JSON
        // If it starts with `{` it's plaintext — something is wrong
        if let firstByte = data.first, firstByte == 0x7B {  // `{`
            logger.error("SECURITY: typing.enc appears to be plaintext JSON!")
            return false
        }

        // Try to decrypt it — if we can, the encryption is working
        if let key = retrieveKeyFromKeychain() {
            if let _ = try? AES.GCM.SealedBox(combined: data),
               let _ = try? AES.GCM.open(AES.GCM.SealedBox(combined: data), using: key) {
                return true
            }
        }

        return false
    }
}

// MARK: - Errors

extension Notification.Name {
    static let typingDataChanged = Notification.Name("typingDataChanged")
}

enum EncryptedStorageError: Error, LocalizedError {
    case keychainUnavailable
    case encryptionFailed
    case decryptionFailed
    case corruptedData

    var errorDescription: String? {
        switch self {
        case .keychainUnavailable: return "Keychain is unavailable — cannot retrieve encryption key"
        case .encryptionFailed:    return "AES-256-GCM encryption failed"
        case .decryptionFailed:    return "AES-256-GCM decryption failed"
        case .corruptedData:       return "Encrypted data is corrupted"
        }
    }
}
