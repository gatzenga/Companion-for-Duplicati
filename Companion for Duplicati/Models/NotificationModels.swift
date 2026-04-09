import Foundation

// MARK: - Notification vom Endpunkt /api/v1/notifications
// Das Message-Feld ist hier ein direkter Text (kein JSON), direkt anzeigbar.

struct DuplicatiNotification: Codable, Sendable, Identifiable {
    let notificationID: Int
    let notificationType: String   // "Warning", "Error", "Information"
    let Title: String
    let Message: String            // Lesbarer Text, kein JSON
    let Exception: String?
    let BackupID: String?
    let Action: String?
    let Timestamp: String          // ISO8601
    let LogEntryID: Int?
    let MessageID: String?
    let MessageLogTag: String?

    var id: Int { notificationID }

    enum CodingKeys: String, CodingKey {
        case notificationID   = "ID"
        case notificationType = "Type"
        case Title, Message, Exception, BackupID, Action
        case Timestamp, LogEntryID, MessageID, MessageLogTag
    }

    var parsedTimestamp: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: Timestamp)
    }

    var isWarning: Bool { notificationType == "Warning" }
    var isError: Bool   { notificationType == "Error" }
}
