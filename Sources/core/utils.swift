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

        let fullYear = year < 50 ? 2000 + year :
            (year < 100 ? 1900 + year : year)

        var dateComponents = DateComponents()
        dateComponents.day = day
        dateComponents.month = month
        dateComponents.year = fullYear

        return Calendar.current.date(from: dateComponents)
    }

    public static func parseNaturalDate(_ input: String) -> Date? {
        let lowercased = input.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let calendar = Calendar.current
        let now = Date()

        switch lowercased {
        case "today":
            return calendar.startOfDay(for: now)
        case "tomorrow":
            return calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: now)
            )
        case "yesterday":
            return calendar.date(
                byAdding: .day,
                value: -1,
                to: calendar.startOfDay(for: now)
            )
        default:
            return parseDate(input)
        }
    }

    public static func formatDate(_ date: Date) -> String {
        return mediumFormatter.string(from: date)
    }
}

public enum IDResolver {
    public static func resolveIDs(_ inputs: [String],
                                  from reminders: [Reminder]) -> [String]
    {
        var resolvedIDs: [String] = []
        for input in inputs {
            if let id = resolveID(input, from: reminders) {
                resolvedIDs.append(id)
            }
        }
        return resolvedIDs
    }

    public static func resolveIDs(_ inputs: [String],
                                  snapshot: [String],
                                  reminders: [Reminder]) -> [String]
    {
        var resolvedIDs: [String] = []
        for input in inputs {
            if let id = resolveID(
                input,
                snapshot: snapshot,
                reminders: reminders
            ) {
                resolvedIDs.append(id)
            }
        }
        return resolvedIDs
    }

    private static func resolveID(_ input: String,
                                  snapshot: [String],
                                  reminders: [Reminder]) -> String?
    {
        let existingIDs = Set(reminders.compactMap(\.id))

        if let index = Int(input), index > 0, index <= snapshot.count {
            let candidate = snapshot[index - 1]
            if existingIDs.contains(candidate) { return candidate }
        }

        return resolveID(input, from: reminders)
    }

    private static func resolveID(_ input: String,
                                  from reminders: [Reminder]) -> String?
    {
        if let index = Int(input), index > 0, index <= reminders.count {
            let sortedReminders = OutputUtils.sortReminders(reminders)
            return sortedReminders[index - 1].id
        }

        if let reminder = reminders.first(where: { $0.id == input }) {
            return reminder.id
        }

        if input.count >= Constants.minPrefixLength {
            let matches = reminders.filter { reminder in
                reminder.id?.lowercased().hasPrefix(input.lowercased()) ?? false
            }

            if matches.count == 1 {
                return matches.first?.id
            } else if matches.count > 1 {
                print("Ambiguous ID '\(input)' matches multiple reminders:")
                for match in matches.prefix(Constants.maxAmbiguousMatches) {
                    print(
                        "  - \(match.id?.prefix(8) ?? "Unknown"): \(match.title)"
                    )
                }
                return nil
            }
        }

        return nil
    }
}
