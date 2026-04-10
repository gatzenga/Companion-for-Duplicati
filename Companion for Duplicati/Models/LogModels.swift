import SwiftUI

struct BackupLogEntry: Sendable, Identifiable {
    let id: UUID
    let entryID: Int
    let operationID: Int?
    let timestamp: Int?
    let message: String?
    let exception: String?
    let entryType: String?
    let parsedMessage: BackupLogMessage?

    var timestampDate: Date? {
        guard let ts = timestamp else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(ts))
    }
}

extension BackupLogEntry: Decodable {
    enum CodingKeys: String, CodingKey {
        case entryID     = "ID"
        case operationID = "OperationID"
        case timestamp   = "Timestamp"
        case message     = "Message"
        case exception   = "Exception"
        case entryType   = "Type"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = UUID()
        entryID     = (try? c.decode(Int.self,    forKey: .entryID))     ?? 0
        operationID = try? c.decode(Int.self,    forKey: .operationID)
        timestamp   = try? c.decode(Int.self,    forKey: .timestamp)
        message     = try? c.decode(String.self, forKey: .message)
        exception   = try? c.decode(String.self, forKey: .exception)
        entryType   = try? c.decode(String.self, forKey: .entryType)
        parsedMessage = parseLogMessage(message)
    }
}

// MARK: - Geparster Inhalt des Message-Feldes

struct BackupLogMessage: Codable, Sendable {
    let ParsedResult: String?
    let Warnings: [String]?
    let Errors: [String]?
    let PartialBackup: Bool?
    let Duration: String?
    let BeginTime: String?
    let EndTime: String?

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
            if let errors = Errors, !errors.isEmpty { return .error(errors) }
            if let warnings = Warnings, !warnings.isEmpty { return .warning(warnings) }
            return .ok
        }
    }

    func statusLabel(lang: String) -> String {
        switch derivedStatus {
        case .ok:
            return PartialBackup == true
                ? tr("Partial Backup", "Partielles Backup", lang)
                : tr("Success", "Erfolgreich", lang)
        case .warning: return tr("Warning", "Warnung", lang)
        case .error:   return tr("Error", "Fehler", lang)
        }
    }

    var statusColor: Color {
        switch derivedStatus {
        case .ok:      return PartialBackup == true ? .orange : .green
        case .warning: return .orange
        case .error:   return .red
        }
    }
}

// MARK: - Log-Status

enum LogStatus {
    case ok
    case warning([String])
    case error([String])

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

// MARK: - Hilfsfunktion

func parseLogMessage(_ jsonString: String?) -> BackupLogMessage? {
    guard let jsonString, !jsonString.isEmpty,
          let data = jsonString.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(BackupLogMessage.self, from: data)
}
