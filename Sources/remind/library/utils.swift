import Foundation

enum OutputUtils {
    private static let bullet = ">"
    private static let arrow = ">"
    private static let dash = "-"
    private static let star = "*"
    private static let plus = "+"

    static func printLists(_ lists: [ReminderList]) {
        guard !lists.isEmpty else {
            print("No reminder lists found")
            return
        }

        let maxTitleLength = lists.map { $0.title.count }.max() ?? 0
        for list in lists {
            let paddedTitle = list.title.padding(
                toLength: maxTitleLength, withPad: " ", startingAt: 0
            )
            let reminderText = list
                .reminderCount == 1 ? "reminder" : "reminders"
            print(
                "\(paddedTitle)  \(bullet) \(list.reminderCount) \(reminderText)"
            )
        }
    }

    static func printReminders(_ reminders: [Reminder], title: String? = nil) {
        if let title = title {
            printInfo(title)
            print()
        }

        guard !reminders.isEmpty else {
            print("No reminders found")
            return
        }

        let maxTitleLength = reminders.map { $0.title.count }.max() ?? 0
        let sortedReminders = sortReminders(reminders)

        for (index, reminder) in sortedReminders.enumerated() {
            printReminder(
                reminder,
                maxTitleLength: maxTitleLength,
                index: index + 1
            )
        }
    }

    static func sortReminders(_ reminders: [Reminder]) -> [Reminder] {
        return reminders.sorted(by: { reminder1, reminder2 in
            if reminder1.isCompleted != reminder2.isCompleted {
                return !reminder1.isCompleted && reminder2.isCompleted
            }
            if let date1 = reminder1.dueDate, let date2 = reminder2.dueDate {
                return date1 < date2
            }
            if reminder1.dueDate != nil, reminder2.dueDate == nil {
                return true
            }
            if reminder1.dueDate == nil, reminder2.dueDate != nil {
                return false
            }
            return reminder1.priority.rawValue > reminder2.priority.rawValue
        })
    }

    private static func printReminder(
        _ reminder: Reminder,
        maxTitleLength: Int,
        index: Int
    ) {
        let paddedTitle = reminder.title.padding(
            toLength: maxTitleLength, withPad: " ", startingAt: 0
        )
        var info: [String] = []

        if let id = reminder.id {
            let shortId = String(id.prefix(4))
            info.append("[\(index)] \(shortId)")
        } else {
            info.append("[\(index)]")
        }

        if let dueDate = reminder.dueDate {
            let dateText = formatDateForDisplay(dueDate)
            info.append(dateText)
        } else if reminder.isCompleted {
            info.append("done")
        } else {
            info.append("pending")
        }

        if let listName = reminder.listName {
            info.append("\(arrow) \(listName)")
        }

        if reminder.priority != .none {
            info.append("\(star) \(reminder.priority.displayName.lowercased())")
        }

        if reminder.isCompleted {
            info.append("\(plus) completed")
        }

        if let notes = reminder.notes, !notes.isEmpty {
            let truncatedNotes = notes
                .count > 30 ? String(notes.prefix(30)) + "..." : notes
            info.append("\(dash) \(truncatedNotes)")
        }

        print("\(paddedTitle)  \(bullet) \(info.joined(separator: " "))")
    }

    private static func formatDateForDisplay(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "today"
        } else if calendar.isDateInTomorrow(date) {
            return "tomorrow"
        } else if calendar.isDateInYesterday(date) {
            return "yesterday"
        } else {
            let daysDifference = calendar.dateComponents(
                [.day],
                from: now,
                to: date
            ).day ?? 0
            if daysDifference > 0 && daysDifference <= 7 {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE"
                return formatter.string(from: date).lowercased()
            } else if daysDifference < 0 && daysDifference >= -7 {
                return "\(-daysDifference) days ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return formatter.string(from: date).lowercased()
            }
        }
    }

    static func printSuccess(_ message: String) { print("\(plus) \(message)") }
    static func printError(_ message: String) { print("\(dash) \(message)") }
    static func printInfo(_ message: String) { print("\(bullet) \(message)") }
    static func printWarning(_ message: String) { print("\(star) \(message)") }
}

enum IDResolver {
    static func resolveIDs(_ inputs: [String],
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

        if input.count >= 3 {
            let matches = reminders.filter { reminder in
                reminder.id?.lowercased().hasPrefix(input.lowercased()) ?? false
            }
            if matches.count == 1 {
                return matches.first?.id
            } else if matches.count > 1 {
                print("Ambiguous ID '\(input)' matches multiple reminders:")
                for match in matches.prefix(5) {
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

enum InputUtils {
    static func select<T>(
        message: String, options: [(String, T)], defaultIndex: Int = 0
    ) -> T? {
        guard !options.isEmpty else { return nil }

        print(message)
        for (index, option) in options.enumerated() {
            let marker = index == defaultIndex ? ">" : " "
            print("  \(marker) \(option.0)")
        }

        let defaultOption = options[defaultIndex].0
        print("\nSelect option [\(defaultOption)]: ", terminator: "")

        guard let input = readLine()?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        else { return options[defaultIndex].1 }

        if input.isEmpty { return options[defaultIndex].1 }

        if let matchedOption = options
            .first(where: { $0.0.lowercased() == input.lowercased() })
        {
            return matchedOption.1
        }

        if let selection = Int(input), selection >= 1,
           selection <= options.count
        {
            return options[selection - 1].1
        }

        print("Invalid selection. Using default: \(defaultOption)")
        return options[defaultIndex].1
    }

    static func input(
        message: String, defaultValue: String? = nil, required: Bool = false
    ) -> String? {
        let prompt = if let defaultValue = defaultValue {
            "\(message) [\(defaultValue)]: "
        } else if required {
            "\(message) (required): "
        } else {
            "\(message): "
        }

        print(prompt, terminator: "")

        guard let input = readLine()?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        else { return defaultValue }

        if input.isEmpty {
            if required, defaultValue == nil {
                print("This field is required.")
                return self.input(
                    message: message,
                    defaultValue: defaultValue,
                    required: required
                )
            }
            return defaultValue
        }

        return input
    }

    static func confirm(message: String, defaultValue: Bool = false) -> Bool {
        let defaultText = defaultValue ? "Y/n" : "y/N"
        print("\(message) (\(defaultText)): ", terminator: "")

        guard let input = readLine()?
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        else { return defaultValue }

        if input.isEmpty { return defaultValue }
        return input.starts(with: "y")
    }
}

enum DateUtils {
    static func parseDate(_ dateString: String) -> Date? {
        let formatters = [
            "yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy", "yyyy-MM-dd HH:mm",
            "MM/dd/yyyy HH:mm"
        ]

        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) { return date }
        }

        return nil
    }

    static func parseSpecificDate(_ dateString: String) -> Date? {
        let components = dateString.split(separator: "-")
        guard components.count == 3 else { return nil }

        guard let day = Int(components[0]), let month = Int(components[1]),
              let year = Int(components[2])
        else { return nil }

        let fullYear = year < 50 ? 2000 + year :
            (year < 100 ? 1900 + year : year)

        var dateComponents = DateComponents()
        dateComponents.day = day
        dateComponents.month = month
        dateComponents.year = fullYear

        return Calendar.current.date(from: dateComponents)
    }

    static func parseNaturalDate(_ input: String) -> Date? {
        let lowercased = input.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let calendar = Calendar.current
        let now = Date()

        switch lowercased {
        case "today": return calendar.startOfDay(for: now)
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
        default: return parseDate(input)
        }
    }

    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
