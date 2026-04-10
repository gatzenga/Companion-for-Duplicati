import Foundation

// MARK: - Log-Eintrag vom Endpunkt /api/v1/backup/{id}/log
//
// Die SQLite-Tabelle "LogData" hat folgende Spalten:
//   ID INTEGER, OperationID INTEGER, Timestamp INTEGER (Unix-Sekunden),
//   Type TEXT, Message TEXT, Exception TEXT
//
// Wichtig: SQLite-NULL wird von Duplicatis DumpTable als DBNull.Value
// übergeben, das System.Text.Json als {} serialisieren kann statt als null.
// Deshalb dekodieren wir jeden Wert fault-tolerant mit try?.

struct BackupLogEntry: Sendable, Identifiable {
    let id: Int            // Identifiable, mapped von JSON-Feld "ID"
    let operationID: Int?
    let timestamp: Int?    // Unix-Timestamp in Sekunden
    let message: String?   // JSON-String, muss separat geparst werden
    let exception: String?
    let entryType: String? // z.B. "Information", "RetryAttempt"

    // Timestamp als Date-Objekt
    var timestampDate: Date? {
        guard let ts = timestamp else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(ts))
    }
}

extension BackupLogEntry: Codable {
    enum CodingKeys: String, CodingKey {
        case id          = "ID"
        case operationID = "OperationID"
        case timestamp   = "Timestamp"
        case message     = "Message"
        case exception   = "Exception"
        case entryType   = "Type"
    }

    // Fault-toleranter Decoder: jedes Feld mit try? damit ein falscher Typ
    // (z.B. {} statt null für Exception) nicht die ganze Liste zum Absturz bringt.
    init(from decoder: Decoder) throws {
        let c   = try decoder.container(keyedBy: CodingKeys.self)
        id          = (try? c.decode(Int.self,    forKey: .id))          ?? 0
        operationID = try? c.decode(Int.self,    forKey: .operationID)
        timestamp   = try? c.decode(Int.self,    forKey: .timestamp)
        message     = try? c.decode(String.self, forKey: .message)
        exception   = try? c.decode(String.self, forKey: .exception)
        entryType   = try? c.decode(String.self, forKey: .entryType)
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
