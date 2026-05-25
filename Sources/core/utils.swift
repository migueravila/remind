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
            return parseDate(input) ?? parseSpecificDate(input)
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

public func resolveList(
    manager: Manager,
    explicit: String?
) async throws -> String? {
    if let explicit { return explicit }

    if case let .list(name) = ViewStateStore.load()?.spec {
        return name
    }

    let config = Config.load()
    if let defaultList = config.defaultList { return defaultList }

    let available = try await manager.getAllLists()
    guard !available.isEmpty else {
        OutputUtils.printError("No lists available. Create a list first.")
        return nil
    }
    let options = available.map { ($0.title, $0.title) }
    return InputUtils.select(message: "Select a list:", options: options)
}

public func resolveReminderIDs(
    _ inputs: [String],
    listScope: String? = nil,
    filterScope: String? = nil,
    examples: [String]
) async throws -> (manager: Manager, ids: [String])? {
    guard !inputs.isEmpty else {
        OutputUtils
            .printError("Please provide at least one reminder number or ID")
        print("Examples:")
        examples.forEach { print($0) }
        return nil
    }

    if listScope != nil, filterScope != nil {
        OutputUtils.printError(
            "--list and --filter cannot be combined"
        )
        return nil
    }

    let manager = Manager()
    try await manager.requestAccess()

    let reminders: [Reminder]
    if let filterScope {
        guard let options = parseFilter(filterScope) else {
            OutputUtils.printError("Invalid filter: \(filterScope)")
            return nil
        }
        reminders = try await manager.getReminders(filter: options)
    } else {
        reminders = try await manager.getReminders(from: listScope)
    }

    let validIDs: [String]
    if listScope == nil, filterScope == nil,
       let state = ViewStateStore.load()
    {
        validIDs = IDResolver.resolveIDs(
            inputs,
            snapshot: state.ids,
            reminders: reminders
        )
    } else {
        validIDs = IDResolver.resolveIDs(inputs, from: reminders)
    }

    guard !validIDs.isEmpty else {
        OutputUtils.printError("No valid reminder numbers or IDs found")
        print("Use a view command to see reminders with their numbers")
        return nil
    }

    if validIDs.count < inputs.count {
        OutputUtils.printWarning(
            "Only \(validIDs.count) of \(inputs.count) inputs could be resolved"
        )
    }

    return (manager, validIDs)
}

public func parseFilter(_ input: String) -> ShowOptions? {
    switch input.lowercased() {
    case "today": return .today
    case "tomorrow": return .tomorrow
    case "upcoming": return .upcoming
    case "all": return .all
    default:
        if let date = DateUtils.parseSpecificDate(input) {
            return .specificDate(date)
        }
        return nil
    }
}

public func parsePriority(_ input: String?) -> Reminder.Priority {
    guard let input = input?.lowercased() else { return .none }
    switch input {
    case "low", "l": return .low
    case "medium", "med", "m": return .medium
    case "high", "h": return .high
    default: return .none
    }
}
