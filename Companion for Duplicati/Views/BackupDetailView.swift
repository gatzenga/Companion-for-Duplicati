import SwiftUI

struct BackupDetailView: View {
    let backup: BackupListItem
    @Environment(BackupStore.self) private var store
    @AppStorage("appLanguage") private var lang = "en"
    @AppStorage("timeFormat") private var timeFormat = "24h"
    @State private var showRunConfirmation = false
    @State private var showRunSuccess = false
    @State private var showError = false
    @State private var runErrorMessage = ""
    @State private var isRunning = false
    @State private var retentionLabel: String?

    private var currentStatus: BackupStatus {
        store.effectiveStatus(for: backup)
    }

    var body: some View {
        List {
            infoSection
            statusSection
            sizeSection
            logsSection
            errorSection
            actionsSection
        }
        .task {
            if let detail = try? await store.fetchBackupDetail(id: backup.Backup.ID) {
                retentionLabel = detail.retentionLabel(lang: lang)
            }
        }
        .navigationTitle(backup.Backup.Name)
        .navigationBarTitleDisplayMode(.inline)
        .alert(tr("Run Backup?", "Backup starten?", lang), isPresented: $showRunConfirmation) {
            Button(tr("Run Backup", "Backup starten", lang)) {
                Task { await runBackup() }
            }
            Button(tr("Cancel", "Abbrechen", lang), role: .cancel) {}
        } message: {
            Text(tr(
                "Do you want to start the backup \"\(backup.Backup.Name)\" now?",
                "Möchtest du das Backup \"\(backup.Backup.Name)\" jetzt starten?",
                lang
            ))
        }
        .alert(tr("Backup Started", "Backup gestartet", lang), isPresented: $showRunSuccess) {
            Button("OK") {}
        } message: {
            Text(tr(
                "The backup was started successfully.",
                "Das Backup wurde erfolgreich gestartet.",
                lang
            ))
        }
        .alert(tr("Error", "Fehler", lang), isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(runErrorMessage)
        }
    }

    // MARK: - Info (Backup-Typ)

    @ViewBuilder
    private var infoSection: some View {
        if let backendType = backup.backendType(lang: lang) {
            Section(tr("Info", "Info", lang)) {
                detailRow(tr("Type", "Typ", lang), value: backendType)
            }
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        Section(tr("Status", "Status", lang)) {
            HStack {
                Text(tr("Status", "Status", lang))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(currentStatus.color)
                        .frame(width: 8, height: 8)
                    Text(currentStatus.shortLabel(lang: lang))
                        .foregroundStyle(currentStatus.color)
                }
            }

            if let nextBackup = formatScheduleDate(backup.Schedule?.Time, lang: lang, timeFormat: timeFormat) {
                detailRow(tr("Next Backup", "Nächstes Backup", lang), value: nextBackup)
            }

            if let lastBackup = backup.Backup.Metadata.LastBackupStartedString, !lastBackup.isEmpty {
                detailRow(tr("Last Backup", "Letztes Backup", lang), value: lastBackup)
            } else if let lastBackup = formatLogDate(backup.Backup.Metadata.LastBackupStarted, lang: lang, timeFormat: timeFormat) {
                detailRow(tr("Last Backup", "Letztes Backup", lang), value: lastBackup)
            }

            if let duration = formatDuration(backup.Backup.Metadata.LastBackupDuration, lang: lang) {
                detailRow(tr("Duration", "Dauer", lang), value: duration)
            }

            if let interval = formatInterval(backup.Schedule?.Repeat, lang: lang) {
                detailRow(tr("Interval", "Intervall", lang), value: interval)
            }
        }
    }

    // MARK: - Size

    private var sizeSection: some View {
        Section(tr("Size", "Grösse", lang)) {
            if let sourceSize = backup.Backup.Metadata.SourceSizeString, !sourceSize.isEmpty {
                detailRow(tr("Source Data", "Quelldaten", lang), value: sourceSize)
            }

            if let count = backup.Backup.Metadata.SourceFilesCount, !count.isEmpty {
                detailRow(tr("Source Files", "Quelldateien", lang), value: formatSwissNumber(count))
            }

            if let targetSize = backup.Backup.Metadata.TargetSizeString, !targetSize.isEmpty {
                detailRow(tr("Backup Size", "Backup-Grösse", lang), value: targetSize)
            }

            if let count = backup.Backup.Metadata.TargetFilesCount, !count.isEmpty {
                detailRow(tr("Backup Files", "Backup-Dateien", lang), value: formatSwissNumber(count))
            }

            if let count = backup.Backup.Metadata.TargetFilesetsCount, !count.isEmpty {
                detailRow(tr("Versions", "Versionen", lang), value: formatSwissNumber(count))
            } else if let retention = retentionLabel {
                detailRow(tr("Versions", "Versionen", lang), value: retention)
            }
        }
    }

    // MARK: - Logs

    private var logsSection: some View {
        Section {
            NavigationLink(destination: BackupLogsView(backup: backup)) {
                Label(
                    tr("Show Logs", "Logs anzeigen", lang),
                    systemImage: "doc.text.magnifyingglass"
                )
            }
        }
    }

    // MARK: - Error (nur wenn aktueller Fehler oder Warnung)

    @ViewBuilder
    private var errorSection: some View {
        switch currentStatus {
        case .error(let message):
            Section(tr("Error", "Fehler", lang)) {
                Text(message)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

        case .warning:
            let warnings = store.notifications
                .filter { $0.BackupID == backup.Backup.ID && $0.isWarning }
                .compactMap { $0.Message }
            if !warnings.isEmpty {
                Section(tr("Warnings", "Warnungen", lang)) {
                    ForEach(warnings, id: \.self) { warning in
                        Text(warning)
                            .foregroundStyle(.orange)
                            .font(.callout)
                    }
                }
            }

        default:
            EmptyView()
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        Section(tr("Actions", "Aktionen", lang)) {
            Button {
                showRunConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    if isRunning {
                        ProgressView()
                            .padding(.trailing, 8)
                    }
                    Text(tr("Run Backup Now", "Backup jetzt starten", lang))
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
