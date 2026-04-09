import SwiftUI

struct NotificationsView: View {
    @Environment(BackupStore.self) private var store
    @Environment(\.appLanguage) private var appLanguage

    var body: some View {
        NavigationStack {
            Group {
                if store.notifications.isEmpty {
                    ContentUnavailableView(
                        tr("No Notifications", "Keine Benachrichtigungen", appLanguage),
                        systemImage: "bell.slash",
                        description: Text(tr("All notifications have been acknowledged.", "Alle Benachrichtigungen wurden quittiert.", appLanguage))
                    )
                } else {
                    notificationList
                }
            }
            .navigationTitle(tr("Notifications", "Benachrichtigungen", appLanguage))
        }
        .task {
            await store.fetchNotificationsData()
        }
    }

    private var notificationList: some View {
        List {
            ForEach(store.notifications) { notification in
                NotificationRowView(notification: notification) {
                    Task { await store.dismissNotification(id: notification.notificationID) }
                }
            }
        }
        .refreshable {
            await store.fetchNotificationsData()
        }
    }
}

// MARK: - Einzelne Notification-Zeile

struct NotificationRowView: View {
    let notification: DuplicatiNotification
    let onDismiss: () -> Void

    private var accentColor: Color {
        if notification.isError   { return .red }
        if notification.isWarning { return .orange }
        return .secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                // Typ-Icon
                Image(systemName: iconName)
                    .foregroundStyle(accentColor)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(notification.Title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(accentColor)

                    if let timestamp = notification.parsedTimestamp {
                        Text(RelativeDateTimeFormatter().localizedString(for: timestamp, relativeTo: Date()))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Quittieren-Button
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
            }

            // Nachricht (eingerückt unter Icon)
            Text(notification.Message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 26)
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        if notification.isError   { return "exclamationmark.circle.fill" }
        if notification.isWarning { return "exclamationmark.triangle.fill" }
        return "info.circle.fill"
    }
}
