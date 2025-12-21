import Foundation

enum Constants {
    static let maxNotesPreviewLength = 30
    static let maxAmbiguousMatches = 5
    static let minPrefixLength = 3
    static let bufferSize = 3

    static let successIcon = "✔"
    static let errorIcon = "✗"
    static let warningIcon = "⚠"
    static let infoIcon = "ℹ"
    static let promptIcon = "➤"

    static let bullet = "›"
    static let arrow = "›"
    static let dash = "-"
    static let star = "*"
    static let plus = "+"
}

enum Terminal {
    static func enableRawMode() {
        var term = termios()
        tcgetattr(STDIN_FILENO, &term)
        term.c_lflag &= ~UInt(ICANON | ECHO)
        tcsetattr(STDIN_FILENO, TCSANOW, &term)
    }

    static func disableRawMode() {
        var term = termios()
        tcgetattr(STDIN_FILENO, &term)
        term.c_lflag |= UInt(ICANON | ECHO)
        tcsetattr(STDIN_FILENO, TCSANOW, &term)
    }

    static func hideCursor() {
        print("\u{001B}[?25l", terminator: "")
    }

    static func showCursor() {
        print("\u{001B}[?25h", terminator: "")
    }

    static func clearLine() {
        print("\u{001B}[2K\r", terminator: "")
    }

    static func moveCursor(up lines: Int) {
        print("\u{001B}[\(lines)A", terminator: "")
    }

    static func clearPreviousLine() {
        moveCursor(up: 1)
        clearLine()
    }
}

public enum OutputUtils {
    private enum Color {
        static let reset = "\u{001B}[0m"
        static let dim = "\u{001B}[2m"
        static let green = "\u{001B}[32m"
        static let red = "\u{001B}[31m"
        static let yellow = "\u{001B}[33m"
        static let cyan = "\u{001B}[36m"
        static let blue = "\u{001B}[34m"
        static let magenta = "\u{001B}[35m"
    }

    private static let bullet = "•"
    private static let maxTitleLength = 35

    public static func dim(_ text: String) -> String {
        return "\(Color.dim)\(text)\(Color.reset)"
    }

    public static func green(_ text: String) -> String {
        return "\(Color.green)\(text)\(Color.reset)"
    }

    public static func red(_ text: String) -> String {
        return "\(Color.red)\(text)\(Color.reset)"
    }

    public static func yellow(_ text: String) -> String {
        return "\(Color.yellow)\(text)\(Color.reset)"
    }

    public static func cyan(_ text: String) -> String {
        return "\(Color.cyan)\(text)\(Color.reset)"
    }

    public static func blue(_ text: String) -> String {
        return "\(Color.blue)\(text)\(Color.reset)"
    }

    public static func magenta(_ text: String) -> String {
        return "\(Color.magenta)\(text)\(Color.reset)"
    }

    public static func printSuccess(_ message: String) {
        print("\(green(Constants.successIcon)) \(message)")
    }

    public static func printError(_ message: String) {
        print("\(red(Constants.errorIcon)) \(message)")
    }

    public static func printWarning(_ message: String) {
        print("\(yellow(Constants.warningIcon)) \(message)")
    }

    public static func printInfo(_ message: String) {
        print("\(cyan(Constants.infoIcon)) \(message)")
    }

    public static func printLists(
        _ lists: [ReminderList],
        reminders: [Reminder] = [],
        format: OutputFormat = .standard
    ) {
        switch format {
        case .json:
            printListsJSON(lists)
        case .quiet:
            print("\(lists.count)")
        case .plain:
            printListsPlain(lists, reminders: reminders)
        case .standard:
            printListsStandard(lists, reminders: reminders)
        }
    }

    public static func printReminders(_ reminders: [Reminder], format: OutputFormat = .standard) {
        switch format {
        case .json:
            printRemindersJSON(reminders)
        case .quiet:
            print("\(reminders.count)")
        case .plain:
            printRemindersPlain(reminders)
        case .standard:
            printRemindersStandard(reminders)
        }
    }

    private static func printListsJSON(_ lists: [ReminderList]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(lists),
           let json = String(data: data, encoding: .utf8) {
            print(json)
        }
    }

    private static func printListsPlain(_ lists: [ReminderList], reminders: [Reminder]) {
        guard !lists.isEmpty else {
            print("No reminder lists found")
            return
        }
        for list in lists {
            let overdueCount = calculateOverdueCount(for: list, reminders: reminders)
            let overdueText = overdueCount > 0 ? " (\(overdueCount) overdue)" : ""
            print("\(list.title) - \(list.reminderCount) tasks\(overdueText)")
        }
    }

    private static func printListsStandard(_ lists: [ReminderList], reminders: [Reminder]) {
        guard !lists.isEmpty else {
            print("No reminder lists found")
            return
        }

        for list in lists {
            let taskText = list.reminderCount == 1 ? "task" : "tasks"
            let overdueCount = calculateOverdueCount(for: list, reminders: reminders)

            let title = truncateTitle(list.title, maxLength: maxTitleLength)
            let paddedTitle = title.padding(toLength: maxTitleLength, withPad: " ", startingAt: 0)

            var info: [String] = []
            info.append(dim("\(list.reminderCount) \(taskText)"))

            if overdueCount > 0 {
                info.append(red("\(overdueCount) overdue"))
            }

            let infoText = info.joined(separator: " \(bullet) ")
            print("\(paddedTitle) \(bullet) \(infoText)")
        }
    }

    private static func printRemindersJSON(_ reminders: [Reminder]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let sortedReminders = sortReminders(reminders)
        if let data = try? encoder.encode(sortedReminders),
           let json = String(data: data, encoding: .utf8) {
            print(json)
        }
    }

    private static func printRemindersPlain(_ reminders: [Reminder]) {
        guard !reminders.isEmpty else {
            print("No reminders found")
            return
        }
        let sortedReminders = sortReminders(reminders)
        for reminder in sortedReminders {
            let status = reminder.isCompleted ? "[x]" : "[ ]"
            let dateStr = reminder.dueDate.map { formatDateForDisplay($0) } ?? "no date"
            print("\(status) \(reminder.title) | \(reminder.listName ?? "") | \(dateStr)")
        }
    }

    private static func printRemindersStandard(_ reminders: [Reminder]) {
        guard !reminders.isEmpty else {
            print("No reminders found")
            return
        }

        let sortedReminders = sortReminders(reminders)

        let maxListNameWidth = calculateMaxListNameWidth(reminders: sortedReminders)
        let maxPriorityWidth = calculateMaxPriorityWidth(reminders: sortedReminders)

        for (index, reminder) in sortedReminders.enumerated() {
            printModernReminder(
                reminder,
                index: index + 1,
                maxListNameWidth: maxListNameWidth,
                maxPriorityWidth: maxPriorityWidth
            )
        }
    }

    public static func sortReminders(_ reminders: [Reminder]) -> [Reminder] {
        return reminders.sorted { reminder1, reminder2 in
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
        }
    }

    private static func calculateMaxListNameWidth(reminders: [Reminder]) -> Int {
        let maxListName = reminders.compactMap { $0.listName }.max { $0.count < $1.count }
        return maxListName?.count ?? 0
    }

    private static func calculateMaxPriorityWidth(reminders: [Reminder]) -> Int {
        let maxPriority = reminders.map { "!\($0.priority.displayName.lowercased())" }
            .max { $0.count < $1.count }
        return maxPriority?.count ?? 0
    }

    private static func printModernReminder(
        _ reminder: Reminder,
        index: Int,
        maxListNameWidth: Int,
        maxPriorityWidth: Int
    ) {
        let title = truncateTitle(reminder.title, maxLength: maxTitleLength)
        let paddedTitle = title.padding(toLength: maxTitleLength, withPad: " ", startingAt: 0)

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let isOverdue = if let dueDate = reminder.dueDate {
            dueDate < startOfToday && !reminder.isCompleted
        } else {
            false
        }

        let statusIcon = if reminder.isCompleted {
            green("✓")
        } else if isOverdue {
            red("○")
        } else {
            "○"
        }

        let shortId = if let id = reminder.id {
            String(id.prefix(4)).padding(toLength: 4, withPad: " ", startingAt: 0)
        } else {
            "    "
        }

        var components: [String] = []

        if let listName = reminder.listName {
            let paddedListName = listName.padding(
                toLength: maxListNameWidth,
                withPad: " ",
                startingAt: 0
            )
            components.append(blue(paddedListName))
        }

        let priorityText = "!\(reminder.priority.displayName.lowercased())"
        let paddedPriority = priorityText.padding(
            toLength: maxPriorityWidth,
            withPad: " ",
            startingAt: 0
        )
        components.append(yellow(paddedPriority))

        if let dueDate = reminder.dueDate {
            let dateText = formatDateForDisplay(dueDate)
            let styledDate = isOverdue ? red(dateText) : dateText
            components.append(styledDate)
        } else {
            components.append(dim("no date"))
        }

        if let notes = reminder.notes, !notes.isEmpty {
            components.append(dim("* note"))
        }

        let infoText = components.joined(separator: " \(bullet) ")

        print("\(paddedTitle) \(statusIcon) \(dim(shortId)) \(bullet) \(infoText)")
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
            let daysDifference = calendar.dateComponents([.day], from: now, to: date).day ?? 0

            if daysDifference > 0 && daysDifference <= 7 {
                return DateFormatters.weekday.string(from: date).lowercased()
            } else if daysDifference < 0 && daysDifference >= -7 {
                return "\(-daysDifference) days ago"
            } else {
                return DateFormatters.shortDate.string(from: date).lowercased()
            }
        }
    }

    private static func truncateTitle(_ title: String, maxLength: Int) -> String {
        if title.count <= maxLength {
            return title
        }
        return String(title.prefix(maxLength - 3)) + "..."
    }

    private static func calculateOverdueCount(
        for list: ReminderList,
        reminders: [Reminder]
    ) -> Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        return reminders.filter { reminder in
            reminder.listName == list.title &&
            !reminder.isCompleted &&
            (reminder.dueDate.map { $0 < startOfToday } ?? false)
        }.count
    }
}

private enum DateFormatters {
    static let weekday: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()

    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
}
