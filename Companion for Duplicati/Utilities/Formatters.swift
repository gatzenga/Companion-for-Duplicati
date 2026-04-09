import Foundation

// MARK: - Numbers

func formatSwissNumber(_ value: String?) -> String {
    guard let value, let number = Int(value) else { return value ?? "" }
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = "\u{2019}" // typographic apostrophe '
    formatter.groupingSize = 3
    return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
}

// MARK: - Dates

func parseBackupDate(_ dateString: String?) -> Date? {
    guard let dateString, !dateString.isEmpty else { return nil }

    // "20250606T080005+02:00"
    let isoWithTZ = DateFormatter()
    isoWithTZ.dateFormat = "yyyyMMdd'T'HHmmssXXX"
    isoWithTZ.locale = Locale(identifier: "en_US_POSIX")
    if let date = isoWithTZ.date(from: dateString) { return date }

    // "20250606T081632Z"
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

func relativeTimeString(from dateString: String?) -> String? {
    guard let date = parseBackupDate(dateString) else { return nil }

    let formatter = RelativeDateTimeFormatter()
    formatter.locale = Locale(identifier: "de_CH")
    formatter.unitsStyle = .full
    return formatter.localizedString(for: date, relativeTo: Date())
}

func formatScheduleDate(_ dateString: String?) -> String? {
    guard let date = parseScheduleDate(dateString) else { return dateString }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "de_CH")
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

func formatErrorDate(_ dateString: String?) -> String? {
    guard let date = parseBackupDate(dateString) else { return dateString }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "de_CH")
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

// MARK: - Duration & Intervals

func formatDuration(_ duration: String?) -> String? {
    guard let duration, !duration.isEmpty else { return nil }

    let parts = duration.split(separator: ":")
    guard parts.count >= 3 else { return duration }

    let hours = Int(parts[0]) ?? 0
    let minutes = Int(parts[1]) ?? 0
    let secondsPart = parts[2].split(separator: ".").first ?? parts[2]
    let seconds = Int(secondsPart) ?? 0

    var components: [String] = []
    if hours > 0 { components.append("\(hours) Std.") }
    if minutes > 0 { components.append("\(minutes) Min.") }
    if seconds > 0 || components.isEmpty { components.append("\(seconds) Sek.") }

    return components.joined(separator: " ")
}

func formatInterval(_ interval: String?) -> String? {
    guard let interval, !interval.isEmpty else { return nil }

    switch interval {
    case "1D": return "Täglich"
    case "1W": return "Wöchentlich"
    case "1M": return "Monatlich"
    default:
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
        return interval
    }
}
