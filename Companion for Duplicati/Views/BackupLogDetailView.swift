import SwiftUI

struct BackupLogDetailView: View {
    let entry: BackupLogEntry
    let parsed: BackupLogMessage?
    let lang: String
    let timeFormat: String

    private var logStatus: LogStatus {
        parsed?.derivedStatus ?? .ok
    }

    private var statusLabel: String {
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
        switch logStatus {
        case .ok:      return parsed?.PartialBackup == true ? .orange : .green
        case .warning: return .orange
        case .error:   return .red
        }
    }

    var body: some View {
        List {
            statusSection
            timeSection
            warningsSection
            errorsSection
            exceptionSection
        }
        .navigationTitle(tr("Log Detail", "Log-Detail", lang))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Status

    private var statusSection: some View {
        Section(tr("Result", "Ergebnis", lang)) {
            HStack {
                Text(tr("Status", "Status", lang))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusLabel)
                        .foregroundStyle(statusColor)
                }
            }

            if parsed?.PartialBackup == true {
                HStack {
                    Text(tr("Partial Backup", "Partielles Backup", lang))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(tr("Yes", "Ja", lang))
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: - Zeit

    @ViewBuilder
    private var timeSection: some View {
        // BeginTime aus dem Message-JSON (ISO8601) hat Vorrang,
        // Fallback auf den Unix-Timestamp der SQLite-Zeile.
        let beginFormatted: String? = formatLogDate(parsed?.BeginTime, lang: lang, timeFormat: timeFormat)
            ?? entry.timestampDate.map { formatDate($0, lang: lang, timeFormat: timeFormat) }

        let hasAnyTime = beginFormatted != nil || parsed?.EndTime != nil || parsed?.Duration != nil

        if hasAnyTime {
            Section(tr("Time", "Zeit", lang)) {
                if let begin = beginFormatted {
                    detailRow(tr("Started", "Gestartet", lang), value: begin)
                }
                if let end = formatLogDate(parsed?.EndTime, lang: lang, timeFormat: timeFormat) {
                    detailRow(tr("Finished", "Beendet", lang), value: end)
                }
                if let duration = formatDuration(parsed?.Duration, lang: lang) {
                    detailRow(tr("Duration", "Dauer", lang), value: duration)
                }
            }
        }
    }

    // MARK: - Warnungen

    @ViewBuilder
    private var warningsSection: some View {
        if let warnings = parsed?.Warnings, !warnings.isEmpty {
            Section(tr("Warnings", "Warnungen", lang)) {
                ForEach(warnings, id: \.self) { warning in
                    Text(warning)
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: - Fehler

    @ViewBuilder
    private var errorsSection: some View {
        if let errors = parsed?.Errors, !errors.isEmpty {
            Section(tr("Errors", "Fehler", lang)) {
                ForEach(errors, id: \.self) { error in
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Exception (technisches Detail)

    @ViewBuilder
    private var exceptionSection: some View {
        if let exception = entry.exception, !exception.isEmpty {
            Section(tr("Exception", "Exception", lang)) {
                Text(exception)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Hilfsfunktion

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}
