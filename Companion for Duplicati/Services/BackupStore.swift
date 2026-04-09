import SwiftUI

enum AppTab: Hashable {
    case home, notifications, settings
}

enum SortOrder: String, CaseIterable {
    case name
    case lastBackup
    case status

    func label(lang: String = "en") -> String {
        switch self {
        case .name:       "Name"
        case .lastBackup: lang == "de" ? "Letztes Backup" : "Last Backup"
        case .status:     "Status"
        }
    }
}

@Observable
final class BackupStore {
    var backups: [BackupListItem] = []
    var isLoggedIn = false
    var isLoading = false
    var errorMessage: String?
    var sortOrder: SortOrder = .name
    var serverURL: String = ""
    var selectedTab: AppTab = .home
    var notifications: [DuplicatiNotification] = []
    var progressState: ProgressState?
    var serverState: ServerState?

    var isServerRunning: Bool {
        serverState?.ActiveTask != nil
    }

    var notificationBadgeCount: Int { notifications.count }

    private let api = APIService()
    private var pollingTask: Task<Void, Never>?

    init() {
        if let url = KeychainService.load(.serverURL),
           let token = KeychainService.load(.token) {
            serverURL = url
            api.configure(baseURL: url, token: token)
            isLoggedIn = true
        }
    }

    // MARK: - Effective Status

    func effectiveStatus(for backup: BackupListItem) -> BackupStatus {
        let active = notifications.filter { $0.BackupID == backup.Backup.ID }

        if active.contains(where: { $0.isError }) {
            let msg = active.first(where: { $0.isError })?.Message ?? "Error"
            return .error(msg)
        }

        if active.contains(where: { $0.isWarning }) {
            return .warning
        }

        // No notifications — status is purely based on whether the backup has ever run.
        // LastErrorMessage in metadata is intentionally ignored here: notifications
        // are the single source of truth for error/warning state.
        let lastBackupDate = backup.Backup.Metadata.LastBackupDate ?? ""
        return lastBackupDate.isEmpty ? .neverRun : .ok
    }

    // MARK: - Backup Name

    func backupName(for id: String) -> String {
        backups.first { $0.Backup.ID == id }?.Backup.Name ?? "Backup \(id)"
    }

    // MARK: - Sorted Backups

    var sortedBackups: [BackupListItem] {
        switch sortOrder {
        case .name:
            backups.sorted {
                $0.Backup.Name.localizedCaseInsensitiveCompare($1.Backup.Name) == .orderedAscending
            }
        case .lastBackup:
            backups.sorted {
                ($0.lastBackupDate ?? .distantPast) > ($1.lastBackupDate ?? .distantPast)
            }
        case .status:
            backups.sorted {
                let p0 = effectiveStatus(for: $0).sortPriority
                let p1 = effectiveStatus(for: $1).sortPriority
                if p0 != p1 { return p0 < p1 }
                return $0.Backup.Name.localizedCaseInsensitiveCompare($1.Backup.Name) == .orderedAscending
            }
        }
    }

    // MARK: - Login

    func login(url: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await api.login(baseURL: url, password: password)
            KeychainService.save(password, for: .password)
            KeychainService.save(response.AccessToken, for: .token)
            KeychainService.save(url, for: .serverURL)
            serverURL = url
            isLoggedIn = true
            selectedTab = .home
            await fetchBackups()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Logout

    func logout() {
        stopPolling()
        KeychainService.deleteAll()
        backups = []
        notifications = []
        isLoggedIn = false
        serverURL = ""
        errorMessage = nil
        progressState = nil
        serverState = nil
    }

    // MARK: - Fetch Backups

    func fetchBackups() async {
        guard isLoggedIn else { return }
        isLoading = true

        do {
            backups = try await api.fetchBackups()
            errorMessage = nil
            await fetchNotificationsData()
        } catch {
            if let apiError = error as? APIError, case .unauthorized = apiError {
                isLoggedIn = false
                errorMessage = "Session expired. Please log in again."
                selectedTab = .settings
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    // MARK: - Fetch Notifications

    func fetchNotificationsData() async {
        do {
            notifications = try await api.fetchNotifications()
        } catch {}
    }

    // MARK: - Dismiss Notification

    func dismissNotification(id: Int) async {
        do {
            try await api.dismissNotification(id: id)
            notifications.removeAll { $0.notificationID == id }
        } catch {}
    }

    // MARK: - Run Backup

    func runBackup(id: String) async throws {
        try await api.runBackup(id: id)
    }

    // MARK: - Polling

    func startPolling() {
        guard isLoggedIn else { return }
        pollingTask?.cancel()

        pollingTask = Task {
            while !Task.isCancelled {
                await pollOnce()
                let delay: Duration = isServerRunning ? .seconds(2) : .seconds(5)
                try? await Task.sleep(for: delay)
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func pollOnce() async {
        guard let state = try? await api.fetchServerState() else { return }
        serverState = state

        if state.ActiveTask != nil {
            progressState = try? await api.fetchProgressState()
        } else {
            progressState = nil
            await fetchNotificationsData()
        }
    }
}
