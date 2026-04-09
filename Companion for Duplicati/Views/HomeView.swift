import SwiftUI

struct HomeView: View {
    @Environment(BackupStore.self) private var store

    var body: some View {
        NavigationStack {
            Group {
                if !store.isLoggedIn {
                    EmptyStateView()
                } else if store.isLoading && store.backups.isEmpty {
                    ProgressView("Lade Backups…")
                } else if let error = store.errorMessage, store.backups.isEmpty {
                    ContentUnavailableView {
                        Label("Fehler", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Erneut versuchen") {
                            Task { await store.fetchBackups() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if store.backups.isEmpty {
                    ContentUnavailableView(
                        "Keine Backups",
                        systemImage: "externaldrive.badge.questionmark",
                        description: Text("Keine Backup-Jobs auf dem Server gefunden.")
                    )
                } else {
                    backupList
                }
            }
            .navigationTitle("Backups")
            .toolbar {
                if store.isLoggedIn && !store.backups.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        sortMenu
                    }
                }
            }
        }
        .task {
            if store.isLoggedIn {
                await store.fetchBackups()
            }
        }
    }

    private var backupList: some View {
        List(store.sortedBackups) { backup in
            NavigationLink(destination: BackupDetailView(backup: backup)) {
                BackupRowView(backup: backup)
            }
        }
        .refreshable {
            await store.fetchBackups()
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(SortOrder.allCases, id: \.self) { order in
                Button {
                    store.sortOrder = order
                } label: {
                    if store.sortOrder == order {
                        Label(order.label, systemImage: "checkmark")
                    } else {
                        Text(order.label)
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }
}
