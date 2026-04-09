import SwiftUI

// MARK: - Auth

struct AuthResponse: Codable, Sendable {
    let AccessToken: String
    let RefreshNonce: String?
}

// MARK: - Backup

struct BackupListItem: Codable, Sendable, Identifiable {
    let Backup: BackupInfo
    let Schedule: BackupSchedule?

    var id: String { Backup.ID }
}

struct BackupInfo: Codable, Sendable {
    let ID: String
    let Name: String
    let Description: String?
    let Metadata: BackupMetadata
}

struct BackupMetadata: Codable, Sendable {
    let LastBackupDate: String?
    let LastBackupStarted: String?
    let LastBackupFinished: String?
    let LastBackupDuration: String?
    let SourceFilesSize: String?
    let SourceFilesCount: String?
    let SourceSizeString: String?
    let LastBackupStartedString: String?
    let LastBackupFinishedString: String?
    let LastErrorDate: String?
    let LastErrorMessage: String?
    let BackendSourceFilesSize: String?
    let TargetFilesSize: String?
    let TargetFilesCount: String?
    let TargetSizeString: String?
}

struct BackupSchedule: Codable, Sendable {
    let ID: Int
    let Time: String?
    let Repeat: String?
    let LastRun: String?
    let Rule: String?
}

// MARK: - Status

enum BackupStatus {
    case ok
    case error(String)
    case neverRun

    var color: Color {
        switch self {
        case .ok: .green
        case .error: .red
        case .neverRun: .gray
        }
    }

    var shortLabel: String {
        switch self {
        case .ok: "OK"
        case .error: "Fehler"
        case .neverRun: "Noch nie ausgeführt"
        }
    }

    var sortPriority: Int {
        switch self {
        case .error: 0
        case .neverRun: 1
        case .ok: 2
        }
    }
}

extension BackupListItem {
    var status: BackupStatus {
        let errorMessage = Backup.Metadata.LastErrorMessage ?? ""
        let lastBackupDate = Backup.Metadata.LastBackupDate ?? ""

        if !errorMessage.isEmpty {
            return .error(errorMessage)
        } else if !lastBackupDate.isEmpty {
            return .ok
        } else {
            return .neverRun
        }
    }

    var lastBackupDate: Date? {
        parseBackupDate(Backup.Metadata.LastBackupStarted)
    }

    var relativeLastBackupString: String? {
        relativeTimeString(from: Backup.Metadata.LastBackupStarted)
    }
}
