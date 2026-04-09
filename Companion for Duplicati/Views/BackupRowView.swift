import SwiftUI

struct BackupRowView: View {
    let backup: BackupListItem

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(backup.status.color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(backup.Backup.Name)
                    .font(.body)
                    .fontWeight(.medium)

                if let relative = backup.relativeLastBackupString {
                    Text(relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if case .neverRun = backup.status {
                    Text("Noch nie ausgeführt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
