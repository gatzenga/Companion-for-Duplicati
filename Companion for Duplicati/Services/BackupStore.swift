import SwiftUI

enum AppTab: Hashable {
    case home, notifications, alerts, settings
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
    // MARK: - Backup-Liste

    var backups: [BackupListItem] = []
    var isLoggedIn = false
    var isLoading = false
    var errorMessage: String?
    var sortOrder: SortOrder = .name
    var serverURL: String = ""
    var selectedTab: AppTab = .home

    // MARK: - Log-Daten (ID → letzter geparster Log)

    var backupLogs: [String: BackupLogMessage] = [:]

    // MARK: - Notifications

    var notifications: [DuplicatiNotification] = []

    // MARK: - Live-Status (Polling)

    var progressState: ProgressState?
    var serverState: ServerState?

    var isServerRunning: Bool {
        serverState?.ProgramState == "Running"
    }

    // Badge-Zähler für Tabs
    var notificationBadgeCount: Int { notifications.count }

    var alertBadgeCount: Int {
        backups.filter { backup in
            if case .error = effectiveStatus(for: backup) { return true }
            return false
        }.count
    }

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

    // MARK: - Effektiver Status (Log-basiert mit Fallback auf Metadaten)

    func effectiveStatus(for backup: BackupListItem) -> BackupStatus {
        let active = notifications.filter { $0.BackupID == backup.Backup.ID }
        let log = backupLogs[backup.Backup.ID]

        let hasErrorNotification = active.contains(where: { $0.isError })
        let hasWarningNotification = active.contains(where: { $0.isWarning })

        // -------------------------------------------------------
        // 1) Error-Notification vorhanden
        //    → rot SOLANGE der Log NICHT zeigt, dass der Job
        //      inzwischen nochmal gelaufen ist (ok ODER warning).
        //    Ein neuer Run mit Warning löst den Error-Zustand auf
        //    (Punkt 4: Error → Warning-Übergang).
        // -------------------------------------------------------
        if hasErrorNotification {
            if let log {
                switch log.derivedStatus {
                case .ok:
                    // Job lief erfolgreich nach dem Error → grün
                    return .ok
                case .warning:
                    // Job lief nochmal, aber mit Warning → Error ist aufgelöst,
                    // Warning-Status übernehmen (orange solange Warning-Notif da)
                    return hasWarningNotification ? .warning : .ok
                case .error:
                    // Log zeigt immer noch Error → rot
                    break
                }
            }
            let msg = active.first(where: { $0.isError })?.Message ?? "Error"
            return .error(msg)
        }

        // -------------------------------------------------------
        // 2) Warning-Notification vorhanden (kein Error)
        //    → orange bis die Benachrichtigung quittiert wird
        // -------------------------------------------------------
        if hasWarningNotification {
            return .warning
        }

        // -------------------------------------------------------
        // 3) Keine passende Notification → Log auswerten
        // -------------------------------------------------------
        guard let log else {
            return backup.status // Metadaten-Fallback
        }

        switch log.derivedStatus {
        case .ok:
            return .ok
        case .warning:
            // Log-Warning ohne aktive Notification → bereits quittiert → grün
            return .ok
        case .error(let msgs):
            // Log-Error ohne Notification → rot bis Job erfolgreich läuft
            return .error(msgs.first ?? "Unknown error")
        }
    }

    // MARK: - Backups mit Fehlern (für Alerts-Tab)

    var alertBackups: [(backup: BackupListItem, errors: [String])] {
        backups.compactMap { backup in
            guard let log = backupLogs[backup.Backup.ID] else { return nil }
            if case .error(let msgs) = log.derivedStatus, !msgs.isEmpty {
                return (backup, msgs)
            }
            return nil
        }
    }

    // MARK: - Backup-Name auflösen

    func backupName(for id: String) -> String {
        backups.first { $0.Backup.ID == id }?.Backup.Name ?? "Backup \(id)"
    }

    // MARK: - Sortierte Backup-Liste

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
        backupLogs = [:]
        notifications = []
        isLoggedIn = false
        serverURL = ""
        errorMessage = nil
        progressState = nil
        serverState = nil
    }

    // MARK: - Backups laden (inkl. Logs und Notifications)

    func fetchBackups() async {
        guard isLoggedIn else { return }
        isLoading = true

        do {
            backups = try await api.fetchBackups()
            errorMessage = nil

            // Logs und Notifications parallel nachladen
            async let logsTask: Void = fetchAllLogs()
            async let notifTask: Void = fetchNotificationsData()
            _ = await (logsTask, notifTask)
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

    // MARK: - Alle Logs parallel laden

    func fetchAllLogs() async {
        guard !backups.isEmpty else { return }

        await withTaskGroup(of: (String, BackupLogMessage?).self) { group in
            for backup in backups {
                let id = backup.Backup.ID
                group.addTask {
                    let log = try? await self.api.fetchLastLog(id: id)
                    return (id, log)
                }
            }

            var newLogs: [String: BackupLogMessage] = [:]
            for await (id, log) in group {
                if let log { newLogs[id] = log }
            }
            backupLogs = newLogs
        }
    }

    // MARK: - Notifications laden

    func fetchNotificationsData() async {
        do {
            notifications = try await api.fetchNotifications()
        } catch {
            // Fehler still ignorieren
        }
    }

    // MARK: - Notification quittieren

    func dismissNotification(id: Int) async {
        do {
            try await api.dismissNotification(id: id)
            notifications.removeAll { $0.notificationID == id }
        } catch {
            // Fehler still ignorieren
        }
    }

    // MARK: - Backup starten

    func runBackup(id: String) async throws {
        try await api.runBackup(id: id)
    }

    // MARK: - Polling starten

    func startPolling() {
        guard isLoggedIn else { return }
        pollingTask?.cancel()

        pollingTask = Task {
            while !Task.isCancelled {
                await pollOnce()
                let delay: Duration = isServerRunning ? .seconds(2) : .seconds(30)
                try? await Task.sleep(for: delay)
            }
        }
    }

    // MARK: - Polling stoppen

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Einzelner Poll-Durchlauf

    func pollOnce() async {
        // ServerState separat fangen: schlägt er fehl, bleibt der alte Zustand erhalten.
        guard let state = try? await api.fetchServerState() else { return }
        serverState = state

        if state.ProgramState == "Running" {
            // ProgressState separat fangen: schlägt er fehl (Task bereits beendet),
            // wird der Banner sofort ausgeblendet statt eingefroren zu bleiben.
            progressState = try? await api.fetchProgressState()
        } else {
            progressState = nil
        }

        // Notifications bei jedem Idle-Poll aktualisieren
        if !isServerRunning {
            await fetchNotificationsData()
        }
    }
}
