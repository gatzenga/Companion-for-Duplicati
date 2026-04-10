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
    let TargetURL: String?
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
    let TargetFilesetsCount: String?
}

struct BackupSchedule: Codable, Sendable {
    let ID: Int
    let Time: String?
    let Repeat: String?
    let LastRun: String?
    let Rule: String?
}

// MARK: - Backup Detail (full config)

struct BackupDetailResponse: Sendable {
    let settings: [BackupSetting]

    func retentionLabel(lang: String = "en") -> String? {
        if let v = settings.first(where: { $0.name.lowercased() == "keep-versions" }),
           let value = v.value, !value.isEmpty, value != "0" {
            return value
        }
        if let v = settings.first(where: { $0.name.lowercased() == "keep-time" }),
           let value = v.value, !value.isEmpty {
            return lang == "de" ? "\(value) (Zeit)" : "\(value) (time-based)"
        }
        if let v = settings.first(where: { $0.name.lowercased() == "retention-policy" }),
           let value = v.value, !value.isEmpty {
            return value
        }
        return nil
    }
}

struct BackupSetting: Sendable {
    let name: String
    let value: String?
}

// MARK: - Status

enum BackupStatus {
    case ok                  // grün – letzter Run erfolgreich
    case warning             // orange – Warnung oder partielles Backup
    case error(String)       // rot – Fehler im letzten Run
    case neverRun            // grau – noch nie gelaufen

    var color: Color {
        switch self {
        case .ok:      .green
        case .warning: .orange
        case .error:   .red
        case .neverRun: .gray
        }
    }

    func shortLabel(lang: String = "en") -> String {
        switch self {
        case .ok:       "OK"
        case .warning:  lang == "de" ? "Warnung" : "Warning"
        case .error:    lang == "de" ? "Fehler" : "Error"
        case .neverRun: lang == "de" ? "Noch nie ausgeführt" : "Never Run"
        }
    }

    var sortPriority: Int {
        switch self {
        case .error:   0
        case .warning: 1
        case .neverRun: 2
        case .ok:      3
        }
    }
}

extension BackupListItem {
    var lastBackupDate: Date? {
        parseBackupDate(Backup.Metadata.LastBackupStarted)
    }

    func relativeLastBackupString(lang: String = "en") -> String? {
        relativeTimeString(from: Backup.Metadata.LastBackupStarted, lang: lang)
    }

    func backendType(lang: String = "en") -> String? {
        guard let targetURL = Backup.TargetURL else { return nil }

        if targetURL.starts(with: "smb://")        { return "Windows Share (SMB)" }
        if targetURL.starts(with: "cifs://")       { return "Windows Share (CIFS)" }
        if targetURL.starts(with: "s3://")         { return "Amazon S3" }
        if targetURL.starts(with: "b2://")         { return "Backblaze B2" }
        if targetURL.starts(with: "azure://")      { return "Microsoft Azure" }
        if targetURL.starts(with: "ftp://")        { return "FTP" }
        if targetURL.starts(with: "ssh://")        { return "SFTP" }
        if targetURL.starts(with: "webdav")        { return "WebDAV" }
        if targetURL.starts(with: "openstack://")  { return "OpenStack Blob" }
        if targetURL.starts(with: "googledrive://") { return "Google Drive" }
        if targetURL.starts(with: "onedrive://")   { return "OneDrive" }
        if targetURL.starts(with: "dropbox://")    { return "Dropbox" }
        if targetURL.starts(with: "file://")       { return lang == "de" ? "Lokales Laufwerk" : "Local Drive" }

        return nil
    }
}
