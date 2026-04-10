import SwiftUI

struct BackupLogsView: View {
    let backup: BackupListItem
    @Environment(BackupStore.self) private var store
    @AppStorage("appLanguage") private var lang = "en"
    @AppStorage("timeFormat") private var timeFormat = "24h"

    @State private var entries: [BackupLogEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView(
                    tr("Failed to Load", "Laden fehlgeschlagen", lang),
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if entries.isEmpty {
                ContentUnavailableView(
                    tr("No Logs", "Keine Logs", lang),
                    systemImage: "doc.text",
                    description: Text(tr(
                        "No log entries found for this backup.",
                        "Keine Log-Einträge für dieses Backup gefunden.",
                        lang
                    ))
                )
            } else {
                List(entries) { entry in
                    let parsed = parseLogMessage(entry.message)
                    NavigationLink(destination: BackupLogDetailView(
                        entry: entry,
                        parsed: parsed,
                        lang: lang,
                        timeFormat: timeFormat
                    )) {
                        BackupLogRowView(
                            entry: entry,
                            parsed: parsed,
                            lang: lang,
                            timeFormat: timeFormat
                        )
                    }
                }
            }
        }
        .navigationTitle(tr("Logs", "Logs", lang))
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadLogs() }
        .refreshable { await loadLogs() }
    }

    private func loadLogs() async {
        isLoading = true
        errorMessage = nil
        do {
            entries = try await store.fetchBackupLogs(id: backup.Backup.ID)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Zeile in der Log-Liste

struct BackupLogRowView: View {
    let entry: BackupLogEntry
    let parsed: BackupLogMessage?
    let lang: String
    let timeFormat: String

    private var logStatus: LogStatus {
        parsed?.derivedStatus ?? .ok
    }

    // Gibt es ein ParsedResult → farbige Statusanzeige
    // Gibt es keins → EntryType neutral in Grau
    private var hasParsedResult: Bool {
        parsed?.ParsedResult != nil
    }

    private var statusLabel: String {
        guard hasParsedResult else {
            return entry.entryType ?? tr("Log Entry", "Log-Eintrag", lang)
        }
        switch logStatus {
        case .ok:
            return parsed?.PartialBackup == true
                ? tr("Partial Backup", "Partielles Backup", lang)
                : tr("Success", "Erfolgreich", lang)
        case .warning: return tr("Warning", "Warnung", lang)
        case .error:   return tr("Error", "Fehler", lang)
        }
    }

    private var statusColor: Color {
        guard hasParsedResult else { return .secondary }
        switch logStatus {
        case .ok:      return parsed?.PartialBackup == true ? .orange : .green
        case .warning: return .orange
        case .error:   return .red
        }
    }

    private var dateDisplay: String {
        // Bevorzuge BeginTime aus dem geparsten Message-JSON (ISO8601-String),
        // Fallback auf den Unix-Timestamp der SQLite-Zeile.
        if let beginTime = parsed?.BeginTime,
           let formatted = formatLogDate(beginTime, lang: lang, timeFormat: timeFormat) {
            return formatted
        }
        if let date = entry.timestampDate {
            return formatDate(date, lang: lang, timeFormat: timeFormat)
        }
        return tr("Unknown date", "Unbekanntes Datum", lang)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(statusLabel)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(statusColor)
                Spacer()
                if let duration = formatDuration(parsed?.Duration, lang: lang) {
                    Text(duration)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Text(dateDisplay)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
