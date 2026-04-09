import SwiftUI

// MARK: - Live-Progress-Banner
// Wird im HomeScreen oben angezeigt, solange ein Backup aktiv läuft.

struct ProgressBannerView: View {
    let progress: ProgressState
    let backupName: String
    var lang: String = "en"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            progressSection
            countersRow
            if let filename = progress.currentFilenameOnly, !filename.isEmpty {
                currentFileRow(filename)
            }
        }
        .padding(14)
        .background(bannerBackground)
    }

    // MARK: - Header (drehendes Icon + Name + Phase)

    private var headerRow: some View {
        HStack(spacing: 8) {
            Image(systemName: progress.operationIcon)
                .symbolEffect(.rotate, options: .repeating)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.blue)

            Text(backupName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)

            Spacer()

            Text(progress.localizedPhase(lang: lang))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: - Fortschrittsbalken oder "Zähle Dateien..."

    @ViewBuilder
    private var progressSection: some View {
        if progress.stillCounting {
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.75)
                Text(lang == "de" ? "Zähle Dateien…" : "Counting files…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue.opacity(0.15))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, Color(red: 0.2, green: 0.6, blue: 1.0)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: max(0, geo.size.width * progress.calculatedProgress),
                                height: 8
                            )
                            .animation(.easeInOut(duration: 0.5), value: progress.calculatedProgress)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(formatSwissInt(progress.processedFileCount)) / \(formatSwissInt(progress.totalFileCount)) \(lang == "de" ? "Dateien" : "files")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(Int(progress.calculatedProgress * 100))%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                }
            }
        }
    }

    // MARK: - Grössen & Geschwindigkeit

    private var countersRow: some View {
        HStack {
            Text("\(formatBytes(progress.processedFileSize)) / \(formatBytes(progress.totalFileSize))")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            if progress.backendSpeed > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up")
                        .font(.caption2)
                    Text(formatSpeed(progress.backendSpeed))
                        .font(.caption2)
                }
                .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Aktuelle Datei

    private func currentFileRow(_ filename: String) -> some View {
        Text(filename)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            .truncationMode(.middle)
    }

    // MARK: - Hintergrund

    private var bannerBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.45), lineWidth: 1.5)
            )
    }
}

// MARK: - Generischer Laufend-Banner (kein progressState verfügbar, z. B. Recreate / Repair)

struct GenericOperationCard: View {
    let backupName: String?
    var lang: String = "en"

    private var runningLabel: String {
        lang == "de" ? "Vorgang läuft…" : "Operation running…"
    }

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(backupName ?? runningLabel)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                if backupName != nil {
                    Text(runningLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.45), lineWidth: 1.5)
                )
        )
    }
}

// MARK: - Nächstes geplantes Backup (Idle-Zustand)

struct NextBackupCard: View {
    let backupName: String
    let scheduleLabel: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(backupName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(scheduleLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        // Keine Übersetzung nötig - BackupName und scheduleLabel kommen bereits übersetzt von außen
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1.5)
                )
        )
    }
}
