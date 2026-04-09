import SwiftUI

struct AlertsView: View {
    @Environment(BackupStore.self) private var store

    var body: some View {
        NavigationStack {
            Group {
                if store.alertBackups.isEmpty {
                    ContentUnavailableView(
                        "Keine Fehler",
                        systemImage: "checkmark.shield",
                        description: Text("Alle Backups haben erfolgreich abgeschlossen.")
                    )
                } else {
                    alertList
                }
            }
            .navigationTitle("Fehler")
        }
    }

    private var alertList: some View {
        List {
            ForEach(store.alertBackups, id: \.backup.id) { item in
                AlertBackupSection(backup: item.backup, errors: item.errors)
            }
        }
    }
}

// MARK: - Sektion pro fehlerhaftem Backup

struct AlertBackupSection: View {
    let backup: BackupListItem
    let errors: [String]

    @State private var isExpanded = true

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(errors, id: \.self) { error in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.85))
                            .textSelection(.enabled)

                        if errors.count > 1 {
                            Divider()
                        }
                    }
                    .padding(.vertical, 2)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 13))

                    Text(backup.Backup.Name)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    // Anzahl Fehler als Badge
                    if errors.count > 1 {
                        Text("\(errors.count)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
            }
        } header: {
            // Letztes Backup-Datum als Section-Header
            if let date = backup.relativeLastBackupString() {
                Text(date)
                    .font(.caption)
            }
        }
    }
}
