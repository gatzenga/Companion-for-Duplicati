import SwiftUI

struct HomeView: View {
    @Environment(BackupStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appLanguage) private var appLanguage
    @Environment(\.timeFormat) private var timeFormat

    var body: some View {
        NavigationStack {
            Group {
                if !store.isLoggedIn {
                    EmptyStateView()
                } else if store.isLoading && store.backups.isEmpty {
                    ProgressView(tr("Loading backups…", "Lade Backups…", appLanguage))
                } else if let error = store.errorMessage, store.backups.isEmpty {
                    ContentUnavailableView {
                        Label(tr("Error", "Fehler", appLanguage), systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button(tr("Retry", "Erneut versuchen", appLanguage)) {
                            Task { await store.fetchBackups() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if store.backups.isEmpty {
                    ContentUnavailableView(
                        tr("No Backups", "Keine Backups", appLanguage),
                        systemImage: "externaldrive.badge.questionmark",
                        description: Text(tr("No backup jobs found on server.", "Keine Backup-Jobs auf dem Server gefunden.", appLanguage))
                    )
                } else {
                    backupList
                }
            }
            .navigationTitle(tr("Backups", "Backups", appLanguage))
            .toolbar {
                if store.isLoggedIn && !store.backups.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        sortMenu
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        pauseResumeButton
                    }
                }
            }
        }
        .task {
            if store.isLoggedIn {
                await store.fetchBackups()
                store.startPolling()
                // Sofort einen Poll triggern für aktuelle Server-Daten
                await store.pollOnce()
            }
        }
        // Polling pausieren wenn App in den Hintergrund geht
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                store.stopPolling()
            } else if phase == .active && store.isLoggedIn {
                // Sofort einen Poll, um nach Background aktuell zu sein
                Task {
                    await store.pollOnce()
                    store.startPolling()
                }
            }
        }
    }

    // MARK: - Backup-Liste

    private var backupList: some View {
        List {
            topBanner
            ForEach(store.sortedBackups) { backup in
                NavigationLink(destination: BackupDetailView(backup: backup)) {
                    BackupRowView(backup: backup)
                }
            }
        }
        .refreshable {
            await store.fetchBackups()
        }
    }

    // MARK: - Oberer Banner (laufend / nächstes Backup)

    @ViewBuilder
    private var topBanner: some View {
        if store.isServerRunning {
            // Server is running — show whatever is happening, no own logic
            if let progress = store.progressState {
                bannerSection {
                    ProgressBannerView(
                        progress: progress,
                        backupName: store.backupName(for: progress.backupID),
                        lang: appLanguage
                    )
                }
            } else {
                bannerSection {
                    GenericOperationCard(
                        backupName: store.serverState?.ActiveTask.map { store.backupName(for: $0.Item2) },
                        lang: appLanguage
                    )
                }
            }
        } else if let next = store.serverState?.ProposedSchedule.first {
            // Server idle — show next scheduled backup
            nextBackupSection(name: store.backupName(for: next.Item1), schedule: next.Item2)
        }
    }

    private func nextBackupSection(name: String, schedule: String) -> some View {
        bannerSection {
            NextBackupCard(backupName: name, scheduleLabel: formatScheduleDetailed(schedule, timeFormat: timeFormat, lang: appLanguage))
        }
    }

    private func bannerSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Section {
            content()
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }

    // MARK: - Pause / Resume

    private var pauseResumeButton: some View {
        Button {
            Task { await store.togglePause() }
        } label: {
            Image(systemName: store.serverState?.isPaused == true ? "play.fill" : "pause.fill")
        }
        .disabled(store.serverState == nil)
    }

    // MARK: - Sortier-Menü

    private var sortMenu: some View {
        Menu {
            ForEach(SortOrder.allCases, id: \.self) { order in
                Button {
                    store.sortOrder = order
                } label: {
                    if store.sortOrder == order {
                        Label(order.label(lang: appLanguage), systemImage: "checkmark")
                    } else {
                        Text(order.label(lang: appLanguage))
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }
}
