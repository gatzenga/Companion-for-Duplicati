import SwiftUI

struct BackupRowView: View {
    let backup: BackupListItem
    @Environment(BackupStore.self) private var store
    @Environment(\.appLanguage) private var appLanguage
    @Environment(\.timeFormat) private var timeFormat

    var body: some View {
        let status = store.effectiveStatus(for: backup)

        HStack(spacing: 12) {
            Circle()
                .fill(status.color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 3) {
                Text(backup.Backup.Name)
                    .font(.body)
                    .fontWeight(.medium)

                // Letztes Backup (relativ)
                if let relative = backup.relativeLastBackupString(lang: appLanguage) {
                    subtitleRow(label: tr("Last Backup", "Letztes Backup", appLanguage), value: relative)
                } else if case .neverRun = status {
                    Text(tr("Never run", "Noch nie ausgeführt", appLanguage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Nächstes Backup aus ProposedSchedule
                if let nextTime = nextScheduledTime {
                    subtitleRow(label: tr("Next Backup", "Nächstes Backup", appLanguage), value: nextTime)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var nextScheduledTime: String? {
        guard let schedule = store.serverState?.ProposedSchedule else { return nil }
        guard let item = schedule.first(where: { $0.Item1 == backup.Backup.ID }) else { return nil }
        return formatScheduleRelative(item.Item2, lang: appLanguage, timeFormat: timeFormat)
    }

    private func subtitleRow(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text("\(label):")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
