import SwiftUI

struct BackupLogDetailView: View {
    let entry: BackupLogEntry
    let lang: String
    let timeFormat: String

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
                        .fill(entry.parsedMessage?.statusColor ?? .secondary)
                        .frame(width: 8, height: 8)
                    Text(entry.parsedMessage?.statusLabel(lang: lang) ?? tr("Log Entry", "Log-Eintrag", lang))
                        .foregroundStyle(entry.parsedMessage?.statusColor ?? .secondary)
                }
            }

            if entry.parsedMessage?.PartialBackup == true {
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
        let beginFormatted: String? = formatLogDate(entry.parsedMessage?.BeginTime, lang: lang, timeFormat: timeFormat)
            ?? entry.timestampDate.map { formatDate($0, lang: lang, timeFormat: timeFormat) }

        let hasAnyTime = beginFormatted != nil || entry.parsedMessage?.EndTime != nil || entry.parsedMessage?.Duration != nil

        if hasAnyTime {
            Section(tr("Time", "Zeit", lang)) {
                if let begin = beginFormatted {
                    detailRow(tr("Started", "Gestartet", lang), value: begin)
                }
                if let end = formatLogDate(entry.parsedMessage?.EndTime, lang: lang, timeFormat: timeFormat) {
                    detailRow(tr("Finished", "Beendet", lang), value: end)
                }
                if let duration = formatDuration(entry.parsedMessage?.Duration, lang: lang) {
                    detailRow(tr("Duration", "Dauer", lang), value: duration)
                }
            }
        }
    }

    // MARK: - Warnungen

    @ViewBuilder
    private var warningsSection: some View {
        if let warnings = entry.parsedMessage?.Warnings, !warnings.isEmpty {
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
        if let errors = entry.parsedMessage?.Errors, !errors.isEmpty {
            Section(tr("Errors", "Fehler", lang)) {
                ForEach(errors, id: \.self) { error in
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Exception

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
