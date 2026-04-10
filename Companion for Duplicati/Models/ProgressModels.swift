import Foundation

// MARK: - Fortschritts-Zustand (vom /api/v1/progressstate Endpunkt)

struct ProgressState: Codable {
    let backupID: String
    let taskID: Int
    let currentFilename: String?
    let currentFilesize: Int64
    let phase: String
    let overallProgress: Double
    let processedFileCount: Int
    let processedFileSize: Int64
    let totalFileCount: Int
    let totalFileSize: Int64
    let backendSpeed: Double
    let stillCounting: Bool

    enum CodingKeys: String, CodingKey {
        case backupID = "BackupID"
        case taskID = "TaskID"
        case currentFilename = "CurrentFilename"
        case currentFilesize = "CurrentFilesize"
        case phase = "Phase"
        case overallProgress = "OverallProgress"
        case processedFileCount = "ProcessedFileCount"
        case processedFileSize = "ProcessedFileSize"
        case totalFileCount = "TotalFileCount"
        case totalFileSize = "TotalFileSize"
        case backendSpeed = "BackendSpeed"
        case stillCounting = "StillCounting"
    }

    // Best progress value (0.0 – 1.0)
    // Uses file-based progress when available (backup/restore phases),
    // falls back to OverallProgress for operations without file data (Recreate, Repair, Verify etc.)
    var displayProgress: Double {
        if totalFileSize > 0 {
            return min(1.0, Double(processedFileSize) / Double(totalFileSize))
        } else if totalFileCount > 0 {
            return min(1.0, Double(processedFileCount) / Double(totalFileCount))
        }
        return min(1.0, overallProgress)
    }

    // Übersetzte Phase für die Anzeige (Englisch/Deutsch)
    func localizedPhase(lang: String = "en") -> String {
        switch phase {
        // Backup
        case "Backup_Begin":
            return lang == "de" ? "Backup startet" : "Backup starting"
        case "Backup_PreBackupVerify":
            return lang == "de" ? "Vorprüfung" : "Pre-backup verification"
        case "Backup_ScanForLocalChanges":
            return lang == "de" ? "Lokale Änderungen suchen" : "Scanning for local changes"
        case "Backup_ProcessingFiles":
            return lang == "de" ? "Dateien werden verarbeitet" : "Processing files"
        case "Backup_WaitForUpload", "Backup_WaitingForUpload":
            return lang == "de" ? "Warten auf Upload" : "Waiting for upload"
        case "Backup_Finalize":
            return lang == "de" ? "Finalisierung" : "Finalizing"
        case "Backup_Delete":
            return lang == "de" ? "Alte Versionen löschen" : "Deleting old versions"
        case "Backup_Compact":
            return lang == "de" ? "Komprimierung" : "Compacting"
        case "Backup_VerificationUpload":
            return lang == "de" ? "Verifizierung hochladen" : "Uploading verification"
        case "Backup_PostBackupVerify":
            return lang == "de" ? "Nachprüfung" : "Post-backup verification"
        case "Backup_PostBackupTest":
            return lang == "de" ? "Backup-Test" : "Testing backup"
        case "Backup_VerifyRemote":
            return lang == "de" ? "Remote-Prüfung" : "Verifying remote"
        case "Backup_Complete":
            return lang == "de" ? "Backup abgeschlossen" : "Backup completed"

        // Restore
        case "Restore_Begin":
            return lang == "de" ? "Wiederherstellung startet" : "Restore starting"
        case "Restore_RecreateDatabase":
            return lang == "de" ? "Datenbank wird neu aufgebaut" : "Recreating database"
        case "Restore_PreRestoreVerify":
            return lang == "de" ? "Vorprüfung" : "Pre-restore verification"
        case "Restore_ScanForExistingFiles":
            return lang == "de" ? "Bestehende Dateien suchen" : "Scanning existing files"
        case "Restore_DownloadingRemoteFiles":
            return lang == "de" ? "Dateien werden heruntergeladen" : "Downloading remote files"
        case "Restore_RestoringFiles":
            return lang == "de" ? "Dateien werden wiederhergestellt" : "Restoring files"
        case "Restore_PostRestoreVerify":
            return lang == "de" ? "Nachprüfung" : "Post-restore verification"
        case "Restore_Complete":
            return lang == "de" ? "Wiederherstellung abgeschlossen" : "Restore completed"

        // Recreate / Repair / Verify
        case "Recreate_Running", "RepairUpdate":
            return lang == "de" ? "Datenbank wird neu aufgebaut" : "Recreating database"
        case "Repair_Running":
            return lang == "de" ? "Reparatur läuft" : "Repair running"
        case "Verify_Running":
            return lang == "de" ? "Verifizierung läuft" : "Verification running"

        default:
            // Generischer Fallback: Präfix entfernen und lesbar machen
            let parts = phase.components(separatedBy: "_")
            let label = parts.count > 1 ? parts.dropFirst().joined(separator: " ") : phase
            return label.isEmpty ? phase : label
        }
    }

    // Icon je nach Operationstyp
    var operationIcon: String {
        if phase.hasPrefix("Backup_")  { return "arrow.triangle.2.circlepath" }
        if phase.hasPrefix("Restore_") { return "arrow.down.circle" }
        if phase.hasPrefix("Recreate_") || phase.hasPrefix("Repair") { return "wrench.and.screwdriver" }
        if phase.hasPrefix("Verify_")  { return "checkmark.shield" }
        return "gearshape"
    }

    // Nur Dateiname ohne Pfad (für kompakte Anzeige)
    var currentFilenameOnly: String? {
        guard let filename = currentFilename, !filename.isEmpty else { return nil }
        return URL(fileURLWithPath: filename).lastPathComponent
    }
}

// MARK: - Server-Zustand (vom /api/v1/serverstate Endpunkt)

struct ServerState: Codable {
    let ActiveTask: ActiveTaskItem?
    let ProgramState: String           // "Running" (scheduler active) or "Paused"
    let ProposedSchedule: [ScheduledItem]
    let HasWarning: Bool
    let HasError: Bool
    let SuggestedStatusIcon: String?
    let LastEventID: Int?              // Für Long-Polling: mitschicken damit Server auf Änderung wartet

    var isPaused: Bool { ProgramState == "Paused" }
}

// MARK: - Aktiver Task

struct ActiveTaskItem: Codable {
    let Item1: Int     // Task-ID
    let Item2: String  // Backup-ID
}

// MARK: - Geplanter Backup-Job

struct ScheduledItem: Codable {
    let Item1: String  // Backup-ID
    let Item2: String  // Geplante Startzeit (ISO8601)
}
