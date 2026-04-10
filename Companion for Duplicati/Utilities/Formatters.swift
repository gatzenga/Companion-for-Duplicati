import Foundation

// MARK: - Zahlenformat (Apostroph als Tausendertrennzeichen)

func formatSwissNumber(_ value: String?) -> String {
    guard let value, let number = Int(value) else { return value ?? "" }
    return formatSwissInt(number)
}

func formatSwissInt(_ number: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = "\u{2019}"
    formatter.groupingSize = 3
    return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
}

// MARK: - Datum parsen

func parseBackupDate(_ dateString: String?) -> Date? {
    guard let dateString, !dateString.isEmpty else { return nil }

    let isoWithTZ = DateFormatter()
    isoWithTZ.dateFormat = "yyyyMMdd'T'HHmmssXXX"
    isoWithTZ.locale = Locale(identifier: "en_US_POSIX")
    if let date = isoWithTZ.date(from: dateString) { return date }

    let isoZulu = DateFormatter()
    isoZulu.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
    isoZulu.locale = Locale(identifier: "en_US_POSIX")
    isoZulu.timeZone = TimeZone(abbreviation: "UTC")
    if let date = isoZulu.date(from: dateString) { return date }

    return nil
}

func parseScheduleDate(_ dateString: String?) -> Date? {
    guard let dateString, !dateString.isEmpty else { return nil }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: dateString)
}

// MARK: - Hilfsfunktion: Zeit-String nach Setting

// Zeitformat rein vom User-Setting gesteuert, NICHT von der Sprache
private func timeString(from date: Date, timeFormat: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    if timeFormat == "12h" {
        formatter.dateFormat = "h:mm a"
    } else {
        formatter.dateFormat = "HH:mm"
    }
    return formatter.string(from: date)
}

// MARK: - Relative Zeitangaben

func relativeTimeString(from dateString: String?, lang: String = "en") -> String? {
    guard let date = parseBackupDate(dateString) else { return nil }

    let formatter = RelativeDateTimeFormatter()
    formatter.locale = Locale(identifier: lang == "de" ? "de_CH" : "en_US")
    formatter.unitsStyle = .full
    return formatter.localizedString(for: date, relativeTo: Date())
}

// MARK: - Datum formatieren (für Backup-Details)

func formatScheduleDate(_ dateString: String?, lang: String = "en", timeFormat: String = "24h") -> String? {
    guard let date = parseScheduleDate(dateString) else { return dateString }

    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: lang == "de" ? "de_CH" : "en_US")
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .none
    let dateStr = dateFormatter.string(from: date)
    let timeStr = timeString(from: date, timeFormat: timeFormat)
    return "\(dateStr), \(timeStr)"
}

// MARK: - Zeitplan: kurz-relativ ("today 03:00" / "heute 03:00")

func formatScheduleRelative(_ dateString: String, lang: String = "en", timeFormat: String = "24h") -> String {
    guard let date = parseScheduleDate(dateString) else { return dateString }

    let calendar = Calendar.current
    let timeStr = timeString(from: date, timeFormat: timeFormat)

    if calendar.isDateInToday(date) {
        return lang == "de" ? "heute \(timeStr)" : "today \(timeStr)"
    } else if calendar.isDateInTomorrow(date) {
        return lang == "de" ? "morgen \(timeStr)" : "tomorrow \(timeStr)"
    } else {
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: lang == "de" ? "de_CH" : "en_US")
        dayFormatter.dateFormat = lang == "de" ? "EE dd.MM." : "EEE MM/dd"
        return "\(dayFormatter.string(from: date)) \(timeStr)"
    }
}

// MARK: - Zeitplan: detailliert mit Countdown ("in 10 h · 03:00")

func formatScheduleDetailed(_ dateString: String, timeFormat: String = "24h", lang: String = "en") -> String {
    guard let date = parseScheduleDate(dateString) else { return dateString }

    let timeStr = timeString(from: date, timeFormat: timeFormat)

    let interval = date.timeIntervalSince(Date())
    guard interval > 0 else { return timeStr }

    let totalMinutes = Int(interval / 60)
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60

    if lang == "de" {
        if hours == 0 {
            return "in \(minutes) Min. · \(timeStr)"
        } else if hours < 48 {
            return "in \(hours) Std. · \(timeStr)"
        } else {
            return "in \(hours / 24) Tagen · \(timeStr)"
        }
    } else {
        if hours == 0 {
            return "in \(minutes) min · \(timeStr)"
        } else if hours < 48 {
            return "in \(hours) h · \(timeStr)"
        } else {
            return "in \(hours / 24) days · \(timeStr)"
        }
    }
}

// MARK: - Dauer formatieren

func formatDuration(_ duration: String?, lang: String = "en") -> String? {
    guard let duration, !duration.isEmpty else { return nil }

    let parts = duration.split(separator: ":")
    guard parts.count >= 3 else { return duration }

    let hours = Int(parts[0]) ?? 0
    let minutes = Int(parts[1]) ?? 0
    let secondsPart = parts[2].split(separator: ".").first ?? parts[2]
    let seconds = Int(secondsPart) ?? 0

    var components: [String] = []
    if lang == "de" {
        if hours > 0   { components.append("\(hours) Std.") }
        if minutes > 0 { components.append("\(minutes) Min.") }
        if seconds > 0 || components.isEmpty { components.append("\(seconds) Sek.") }
    } else {
        if hours > 0   { components.append("\(hours) hr") }
        if minutes > 0 { components.append("\(minutes) min") }
        if seconds > 0 || components.isEmpty { components.append("\(seconds) sec") }
    }

    return components.joined(separator: " ")
}

// MARK: - Intervall formatieren

func formatInterval(_ interval: String?, lang: String = "en") -> String? {
    guard let interval, !interval.isEmpty else { return nil }

    if lang == "de" {
        switch interval {
        case "1D": return "Täglich"
        case "1W": return "Wöchentlich"
        case "1M": return "Monatlich"
        default: break
        }
        if interval.hasSuffix("D"), let days = Int(interval.dropLast()) {
            return "Alle \(days) Tage"
        } else if interval.hasSuffix("W"), let weeks = Int(interval.dropLast()) {
            return "Alle \(weeks) Wochen"
        } else if interval.hasSuffix("M"), let months = Int(interval.dropLast()) {
            return "Alle \(months) Monate"
        } else if interval.hasSuffix("h"), let hours = Int(interval.dropLast()) {
            return "Alle \(hours) Stunden"
        } else if interval.hasSuffix("m"), let mins = Int(interval.dropLast()) {
            return "Alle \(mins) Minuten"
        }
    } else {
        switch interval {
        case "1D": return "Daily"
        case "1W": return "Weekly"
        case "1M": return "Monthly"
        default: break
        }
        if interval.hasSuffix("D"), let days = Int(interval.dropLast()) {
            return "Every \(days) days"
        } else if interval.hasSuffix("W"), let weeks = Int(interval.dropLast()) {
            return "Every \(weeks) weeks"
        } else if interval.hasSuffix("M"), let months = Int(interval.dropLast()) {
            return "Every \(months) months"
        } else if interval.hasSuffix("h"), let hours = Int(interval.dropLast()) {
            return "Every \(hours) hours"
        } else if interval.hasSuffix("m"), let mins = Int(interval.dropLast()) {
            return "Every \(mins) minutes"
        }
    }
    return interval
}

// MARK: - Fehler-Datum formatieren

func formatErrorDate(_ dateString: String?, lang: String = "en") -> String? {
    guard let date = parseBackupDate(dateString) else { return dateString }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: lang == "de" ? "de_CH" : "en_US")
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

// MARK: - Log-Zeitstempel parsen (.NET liefert bis zu 7 Nachkommastellen)

func parseLogTimestamp(_ dateString: String?) -> Date? {
    guard let dateString, !dateString.isEmpty else { return nil }

    let iso = ISO8601DateFormatter()

    // Mit Sekundenbruchteilen (iOS unterstützt 1–9 Stellen)
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = iso.date(from: dateString) { return date }

    // Ohne Sekundenbruchteile
    iso.formatOptions = [.withInternetDateTime]
    if let date = iso.date(from: dateString) { return date }

    // Fallback auf bestehende Parser
    return parseScheduleDate(dateString) ?? parseBackupDate(dateString)
}

func formatLogDate(_ dateString: String?, lang: String = "en", timeFormat: String = "24h") -> String? {
    guard let dateString, !dateString.isEmpty else { return nil }
    guard let date = parseLogTimestamp(dateString) else { return dateString }
    return formatDate(date, lang: lang, timeFormat: timeFormat)
}

// Formatiert ein Date-Objekt direkt (z.B. aus Unix-Timestamp)
func formatDate(_ date: Date, lang: String = "en", timeFormat: String = "24h") -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: lang == "de" ? "de_CH" : "en_US")
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .none

    let timeFormatter = DateFormatter()
    timeFormatter.locale = Locale(identifier: "en_US_POSIX")
    timeFormatter.dateFormat = timeFormat == "12h" ? "h:mm a" : "HH:mm"

    return "\(dateFormatter.string(from: date)), \(timeFormatter.string(from: date))"
}

// MARK: - Dateigrösse formatieren

func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .decimal
    formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
    return formatter.string(fromByteCount: bytes)
}

func formatSpeed(_ bytesPerSecond: Double) -> String {
    guard bytesPerSecond > 0 else { return "" }
    let formatter = ByteCountFormatter()
    formatter.countStyle = .decimal
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    return formatter.string(fromByteCount: Int64(bytesPerSecond)) + "/s"
}
