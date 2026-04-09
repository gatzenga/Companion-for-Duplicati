import SwiftUI

struct BackupDetailView: View {
    let backup: BackupListItem
    @Environment(BackupStore.self) private var store
    @State private var showRunConfirmation = false
    @State private var showRunSuccess = false
    @State private var showError = false
    @State private var runErrorMessage = ""
    @State private var isRunning = false

    var body: some View {
        List {
            statusSection
            sizeSection
            errorSection
            actionsSection
        }
        .navigationTitle(backup.Backup.Name)
        .confirmationDialog(
            "Backup starten?",
            isPresented: $showRunConfirmation,
            titleVisibility: .visible
        ) {
            Button("Backup starten") {
                Task { await runBackup() }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Möchtest du das Backup \"\(backup.Backup.Name)\" jetzt starten?")
        }
        .alert("Backup gestartet", isPresented: $showRunSuccess) {
            Button("OK") {}
        } message: {
            Text("Das Backup wurde erfolgreich gestartet.")
        }
        .alert("Fehler", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(runErrorMessage)
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        Section("Status") {
            HStack {
                Text("Status")
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(backup.status.color)
                        .frame(width: 8, height: 8)
                    Text(backup.status.shortLabel)
                        .foregroundStyle(backup.status.color)
                }
            }

            if let lastBackup = backup.Backup.Metadata.LastBackupStartedString, !lastBackup.isEmpty {
                detailRow("Letztes Backup", value: lastBackup)
            }

            if let nextBackup = formatScheduleDate(backup.Schedule?.Time) {
                detailRow("Nächstes Backup", value: nextBackup)
            }

            if let duration = formatDuration(backup.Backup.Metadata.LastBackupDuration) {
                detailRow("Dauer", value: duration)
            }

            if let interval = formatInterval(backup.Schedule?.Repeat) {
                detailRow("Intervall", value: interval)
            }
        }
    }

    // MARK: - Size

    private var sizeSection: some View {
        Section("Grösse") {
            if let sourceSize = backup.Backup.Metadata.SourceSizeString, !sourceSize.isEmpty {
                detailRow("Quelldaten", value: sourceSize)
            }

            if let count = backup.Backup.Metadata.SourceFilesCount, !count.isEmpty {
                detailRow("Quelldateien", value: formatSwissNumber(count))
            }

            if let targetSize = backup.Backup.Metadata.TargetSizeString, !targetSize.isEmpty {
                detailRow("Backup-Grösse", value: targetSize)
            }

            if let count = backup.Backup.Metadata.TargetFilesCount, !count.isEmpty {
                detailRow("Backup-Dateien", value: formatSwissNumber(count))
            }
        }
    }

    // MARK: - Error

    @ViewBuilder
    private var errorSection: some View {
        if case .error(let message) = backup.status {
            Section("Fehler") {
                Text(message)
                    .foregroundStyle(.red)

                if let errorDate = backup.Backup.Metadata.LastErrorDate, !errorDate.isEmpty,
                   let formatted = formatErrorDate(errorDate) {
                    HStack {
                        Text("Fehler-Datum")
                            .foregroundStyle(.red.opacity(0.8))
                        Spacer()
                        Text(formatted)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        Section("Aktionen") {
            Button {
                showRunConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    if isRunning {
                        ProgressView()
                            .padding(.trailing, 8)
                    }
                    Text("Backup jetzt starten")
                        .fontWeight(.semibold)
                    Spacer()
                }
            }
            .disabled(isRunning)
        }
    }

    // MARK: - Helpers

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }

    private func runBackup() async {
        isRunning = true
        do {
            try await store.runBackup(id: backup.Backup.ID)
            showRunSuccess = true
        } catch {
            runErrorMessage = error.localizedDescription
            showError = true
        }
        isRunning = false
    }
}
