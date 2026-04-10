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
                    NavigationLink(destination: BackupLogDetailView(
                        entry: entry,
                        lang: lang,
                        timeFormat: timeFormat
                    )) {
                        BackupLogRowView(
                            entry: entry,
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
    let lang: String
    let timeFormat: String

    private var statusLabel: String {
        guard let parsed = entry.parsedMessage, parsed.ParsedResult != nil else {
            return entry.entryType ?? tr("Log Entry", "Log-Eintrag", lang)
        }
        return parsed.statusLabel(lang: lang)
    }

    private var statusColor: Color {
        guard let parsed = entry.parsedMessage, parsed.ParsedResult != nil else { return .secondary }
        return parsed.statusColor
    }

    private var dateDisplay: String {
        if let beginTime = entry.parsedMessage?.BeginTime,
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
                if let duration = formatDuration(entry.parsedMessage?.Duration, lang: lang) {
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
