import Foundation

public enum DateUtils {
    private static let dateFormatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "dd/MM/yyyy",
            "yyyy-MM-dd HH:mm",
            "MM/dd/yyyy HH:mm"
        ]
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            return formatter
        }
    }()

    private static let mediumFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    public static func parseDate(_ dateString: String) -> Date? {
        for formatter in dateFormatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        return nil
    }

    public static func parseSpecificDate(_ dateString: String) -> Date? {
        let components = dateString.split(separator: "-")
        guard components.count == 3 else { return nil }

        guard let day = Int(components[0]),
              let month = Int(components[1]),
              let year = Int(components[2]) else { return nil }

        let fullYear = year < 50 ? 2000 + year : (year < 100 ? 1900 + year : year)

        var dateComponents = DateComponents()
        dateComponents.day = day
        dateComponents.month = month
        dateComponents.year = fullYear

        return Calendar.current.date(from: dateComponents)
    }

    public static func parseNaturalDate(_ input: String) -> Date? {
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let calendar = Calendar.current
        let now = Date()

        switch lowercased {
        case "today":
            return calendar.startOfDay(for: now)
        case "tomorrow":
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        case "yesterday":
            return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))
        default:
            return parseDate(input)
        }
    }

    public static func formatDate(_ date: Date) -> String {
        return mediumFormatter.string(from: date)
    }
}
