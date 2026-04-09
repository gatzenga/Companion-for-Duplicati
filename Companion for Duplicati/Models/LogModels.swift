import Foundation

// MARK: - Log-Eintrag vom Endpunkt /api/v1/backup/{id}/log

struct BackupLogEntry: Codable, Sendable {
    let ID: Int
    let BackupID: String?
    let Timestamp: String?
    let Message: String?   // JSON-String, muss separat geparst werden
    let Exception: String?
    let EntryType: String? // z.B. "Information", "RetryAttempt"

    enum CodingKeys: String, CodingKey {
        case ID, BackupID, Timestamp, Message, Exception
        case EntryType = "Type"
    }
}

// MARK: - Geparster Inhalt des Message-Feldes

struct BackupLogMessage: Codable, Sendable {
    let ParsedResult: String?   // "Success", "Warning", "Error", "Fatal"
    let Warnings: [String]?
    let Errors: [String]?
    let PartialBackup: Bool?
    let Duration: String?
    let BeginTime: String?
    let EndTime: String?

    // Abgeleiteter Status basierend auf den Log-Daten
    var derivedStatus: LogStatus {
        switch ParsedResult {
        case "Success":
            if PartialBackup == true { return .warning(Warnings ?? []) }
            return .ok
        case "Warning":
            return .warning(Warnings ?? [])
        case "Error", "Fatal":
            return .error(Errors ?? [])
        default:
            // Fehler-Array als Fallback prüfen
            if let errors = Errors, !errors.isEmpty { return .error(errors) }
            if let warnings = Warnings, !warnings.isEmpty { return .warning(warnings) }
            return .ok
        }
    }
}

// MARK: - Abgeleiteter Status aus dem letzten Log-Eintrag

enum LogStatus {
    case ok
    case warning([String])
    case error([String])

    // Hauptfehlermeldung für die Anzeige
    var firstMessage: String? {
        switch self {
        case .ok: nil
        case .warning(let msgs): msgs.first
        case .error(let msgs): msgs.first
        }
    }

    var allMessages: [String] {
        switch self {
        case .ok: []
        case .warning(let msgs): msgs
        case .error(let msgs): msgs
        }
    }
}

// MARK: - Hilfsfunktion: Message-JSON parsen

func parseLogMessage(_ jsonString: String?) -> BackupLogMessage? {
    guard let jsonString, !jsonString.isEmpty,
          let data = jsonString.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(BackupLogMessage.self, from: data)
}
