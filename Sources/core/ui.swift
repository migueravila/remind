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

    public static func printReminders(
        _ reminders: [Reminder],
        format: OutputFormat = .standard
    ) {
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
           let json = String(data: data, encoding: .utf8)
        {
            print(json)
        }
    }

    private static func printListsPlain(
        _ lists: [ReminderList],
        reminders: [Reminder]
    ) {
        guard !lists.isEmpty else {
            print("No reminder lists found")
            return
        }
        for list in lists {
            let overdueCount = calculateOverdueCount(
                for: list,
                reminders: reminders
            )
            let overdueText = overdueCount > 0 ? " (\(overdueCount) overdue)" :
                ""
            print("\(list.title) - \(list.reminderCount) tasks\(overdueText)")
        }
    }

    private static func printListsStandard(
        _ lists: [ReminderList],
        reminders: [Reminder]
    ) {
        guard !lists.isEmpty else {
            print("No reminder lists found")
            return
        }

        for list in lists {
            let taskText = list.reminderCount == 1 ? "task" : "tasks"
            let overdueCount = calculateOverdueCount(
                for: list,
                reminders: reminders
            )

            let title = truncateTitle(list.title, maxLength: maxTitleLength)
            let paddedTitle = title.padding(
                toLength: maxTitleLength,
                withPad: " ",
                startingAt: 0
            )

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
           let json = String(data: data, encoding: .utf8)
        {
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
            let flag = reminder.isFlagged ? " *" : ""
            let dateStr = reminder.dueDate.map { formatDateForDisplay(
                $0
            ) } ?? "no date"
            print(
                "\(status) \(reminder.title)\(flag) | \(reminder.listName ?? "") | \(dateStr)"
            )
        }
    }

    private static func printRemindersStandard(_ reminders: [Reminder]) {
        guard !reminders.isEmpty else {
            print("No reminders found")
            return
        }

        let sortedReminders = sortReminders(reminders)

        let maxListNameWidth =
            calculateMaxListNameWidth(reminders: sortedReminders)
        let maxPriorityWidth =
            calculateMaxPriorityWidth(reminders: sortedReminders)

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

    private static func calculateMaxListNameWidth(reminders: [Reminder])
        -> Int
    {
        let maxListName = reminders.compactMap { $0.listName }
            .max { $0.count < $1.count }
        return maxListName?.count ?? 0
    }

    private static func calculateMaxPriorityWidth(reminders: [Reminder])
        -> Int
    {
        let maxPriority = reminders
            .map { "!\($0.priority.displayName.lowercased())" }
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
        let paddedTitle = title.padding(
            toLength: maxTitleLength,
            withPad: " ",
            startingAt: 0
        )

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
            String(id.prefix(4)).padding(
                toLength: 4,
                withPad: " ",
                startingAt: 0
            )
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

        if reminder.isFlagged {
            components.append(red("⚑"))
        }

        let infoText = components.joined(separator: " \(bullet) ")

        print(
            "\(paddedTitle) \(statusIcon) \(dim(shortId)) \(bullet) \(infoText)"
        )
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
                return DateFormatters.weekday.string(from: date).lowercased()
            } else if daysDifference < 0 && daysDifference >= -7 {
                return "\(-daysDifference) days ago"
            } else {
                return DateFormatters.shortDate.string(from: date).lowercased()
            }
        }
    }

    private static func truncateTitle(_ title: String,
                                      maxLength: Int) -> String
    {
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

enum KeyInput {
    case up, down, left, right, enter, escape, backspace, character(Character),
         unknown

    static func readKey() -> KeyInput {
        var buffer = [UInt8](repeating: 0, count: Constants.bufferSize)
        let bytesRead = read(STDIN_FILENO, &buffer, Constants.bufferSize)

        guard bytesRead > 0 else { return .unknown }

        if bytesRead == 1 {
            switch buffer[0] {
            case 13, 10: return .enter
            case 27: return .escape
            case 127, 8: return .backspace
            case let char where char >= 32 && char <= 126:
                return .character(Character(UnicodeScalar(char)))
            default: return .unknown
            }
        } else if bytesRead == 3 && buffer[0] == 27 && buffer[1] == 91 {
            switch buffer[2] {
            case 65: return .up
            case 66: return .down
            case 67: return .right
            case 68: return .left
            default: return .unknown
            }
        }
        return .unknown
    }
}

public enum InputUtils {
    public static func select<T>(
        message: String,
        options: [(String, T)],
        defaultIndex: Int = 0,
        interactive: Bool = true
    ) -> T? {
        guard !options.isEmpty else { return nil }

        if !interactive || !isTerminalInteractive() {
            return selectSimple(
                message: message,
                options: options,
                defaultIndex: defaultIndex
            )
        }

        return selectInteractive(
            message: message,
            options: options,
            defaultIndex: defaultIndex
        )
    }

    public static func input(
        message: String,
        defaultValue: String? = nil,
        required: Bool = false
    ) -> String? {
        let hint = if let defaultValue = defaultValue {
            " (\(defaultValue))"
        } else if required {
            " (required)"
        } else {
            ""
        }

        print("\(Constants.promptIcon) \(message)\(hint): ", terminator: "")

        guard let input = readLine()?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        else {
            return handleEmptyInput(
                message: message,
                defaultValue: defaultValue
            )
        }

        if input.isEmpty {
            if required, defaultValue == nil {
                OutputUtils.printError("This field is required.")
                return self.input(
                    message: message,
                    defaultValue: defaultValue,
                    required: required
                )
            }
            return handleEmptyInput(
                message: message,
                defaultValue: defaultValue
            )
        }

        showSuccessfulInput(message: message, value: input)
        return input
    }

    public static func confirm(message: String,
                               defaultValue: Bool = false) -> Bool
    {
        let defaultText = defaultValue ? "Y/n" : "y/N"
        print(
            "\(Constants.promptIcon) \(message) (\(defaultText)): ",
            terminator: ""
        )

        guard let input = readLine()?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        else {
            return handleConfirmDefault(
                message: message,
                defaultValue: defaultValue
            )
        }

        if input.isEmpty {
            return handleConfirmDefault(
                message: message,
                defaultValue: defaultValue
            )
        }

        let result = input.starts(with: "y")
        let resultText = result ? "yes" : "no"
        Terminal.clearPreviousLine()
        print(
            "\(OutputUtils.green(Constants.successIcon)) \(message): \(OutputUtils.dim(resultText))"
        )
        return result
    }

    public static func datePicker(
        message: String,
        initialDate: Date = Date(),
        interactive: Bool = true
    ) -> Date? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: initialDate)

        if !interactive || !isTerminalInteractive() {
            return datePickerSimple(message: message, initialDate: startOfDay)
        }

        return datePickerInteractive(message: message, initialDate: startOfDay)
    }

    private static func isTerminalInteractive() -> Bool {
        return isatty(STDIN_FILENO) == 1 && isatty(STDOUT_FILENO) == 1
    }

    private static func handleEmptyInput(message: String,
                                         defaultValue: String?) -> String?
    {
        if let defaultValue = defaultValue, !defaultValue.isEmpty {
            Terminal.clearPreviousLine()
            print(
                "\(OutputUtils.green(Constants.successIcon)) \(message): \(OutputUtils.dim(defaultValue))"
            )
            return defaultValue
        }
        Terminal.clearPreviousLine()
        return nil
    }

    private static func showSuccessfulInput(message: String, value: String) {
        Terminal.clearPreviousLine()
        print(
            "\(OutputUtils.green(Constants.successIcon)) \(message): \(OutputUtils.dim(value))"
        )
    }

    private static func handleConfirmDefault(message: String,
                                             defaultValue: Bool) -> Bool
    {
        let result = defaultValue ? "yes" : "no"
        Terminal.clearPreviousLine()
        print(
            "\(OutputUtils.green(Constants.successIcon)) \(message): \(OutputUtils.dim(result))"
        )
        return defaultValue
    }

    private static func selectSimple<T>(
        message: String,
        options: [(String, T)],
        defaultIndex: Int
    ) -> T? {
        print(message)
        for (index, option) in options.enumerated() {
            let marker = index == defaultIndex ? ">" : " "
            print("  \(marker) \(option.0)")
        }

        let defaultOption = options[defaultIndex].0
        print("\nSelect option [\(defaultOption)]: ", terminator: "")

        guard let input = readLine()?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        else {
            return options[defaultIndex].1
        }

        if input.isEmpty { return options[defaultIndex].1 }

        if let matchedOption = options.first(where: {
            $0.0.lowercased() == input.lowercased()
        }) {
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

    private static func selectInteractive<T>(
        message: String,
        options: [(String, T)],
        defaultIndex: Int
    ) -> T? {
        var selectedIndex = defaultIndex
        var searchQuery = ""
        var filteredOptions = options
        var lastRenderedLines = 0

        Terminal.enableRawMode()
        Terminal.hideCursor()
        defer {
            Terminal.disableRawMode()
            Terminal.showCursor()
        }

        func updateFilteredOptions() {
            if searchQuery.isEmpty {
                filteredOptions = options
            } else {
                filteredOptions = options.filter { option in
                    option.0.lowercased().contains(searchQuery.lowercased())
                }
            }
            selectedIndex = min(
                selectedIndex,
                max(0, filteredOptions.count - 1)
            )
        }

        func render() {
            clearRenderedLines(lastRenderedLines)
            var lineCount = 0

            if searchQuery.isEmpty {
                print("\(Constants.promptIcon) \(message)")
            } else {
                print(
                    "\(Constants.promptIcon) \(message) \(OutputUtils.green(searchQuery))"
                )
            }
            lineCount += 1

            if filteredOptions.isEmpty, !searchQuery.isEmpty {
                print("  No matches found")
                lineCount += 1
            } else {
                for (index, option) in filteredOptions.enumerated() {
                    let marker = index == selectedIndex ? "› " : "  "
                    let style = index == selectedIndex
                        ? OutputUtils.green(option.0)
                        : option.0
                    print("\(marker)\(style)")
                    lineCount += 1
                }
            }

            print(OutputUtils.dim(
                "Type to search, arrows to navigate, Enter to select, Esc to cancel"
            ))
            lineCount += 1

            lastRenderedLines = lineCount
        }

        func clearRenderedLines(_ lines: Int) {
            if lines > 0 {
                for _ in 0 ..< lines {
                    Terminal.moveCursor(up: 1)
                    Terminal.clearLine()
                }
            }
        }

        updateFilteredOptions()
        render()

        while true {
            let input = KeyInput.readKey()

            switch input {
            case .up:
                if !filteredOptions.isEmpty {
                    selectedIndex = max(0, selectedIndex - 1)
                    render()
                }
            case .down:
                if !filteredOptions.isEmpty {
                    selectedIndex = min(
                        filteredOptions.count - 1,
                        selectedIndex + 1
                    )
                    render()
                }
            case .enter:
                guard !filteredOptions.isEmpty else { continue }
                clearRenderedLines(lastRenderedLines)
                print(
                    "\(OutputUtils.green(Constants.successIcon)) \(message): " +
                        "\(OutputUtils.dim(filteredOptions[selectedIndex].0))"
                )
                return filteredOptions[selectedIndex].1
            case .escape:
                clearRenderedLines(lastRenderedLines)
                return nil
            case .backspace:
                if !searchQuery.isEmpty {
                    searchQuery.removeLast()
                    updateFilteredOptions()
                    render()
                }
            case let .character(char):
                searchQuery.append(char)
                updateFilteredOptions()
                render()
            default:
                break
            }
        }
    }

    private static func datePickerSimple(message: String,
                                         initialDate: Date) -> Date?
    {
        print("\(message)")
        print(
            "Enter date (YYYY-MM-DD) or 'today', 'tomorrow': ",
            terminator: ""
        )

        guard let input = readLine()?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        else {
            return nil
        }

        if input.isEmpty { return initialDate }

        if let parsedDate = DateUtils.parseNaturalDate(input) {
            return Calendar.current.startOfDay(for: parsedDate)
        }

        return initialDate
    }

    private static func datePickerInteractive(message: String,
                                              initialDate: Date) -> Date?
    {
        var selectedDate = initialDate
        var lastRenderedLines = 0

        Terminal.enableRawMode()
        Terminal.hideCursor()
        defer {
            Terminal.disableRawMode()
            Terminal.showCursor()
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none

        func render() {
            if lastRenderedLines > 0 {
                for _ in 0 ..< lastRenderedLines {
                    Terminal.moveCursor(up: 1)
                    Terminal.clearLine()
                }
            }

            var lineCount = 0

            print("\(Constants.promptIcon) \(message)")
            lineCount += 1

            print("> \(OutputUtils.cyan(formatter.string(from: selectedDate)))")
            lineCount += 1

            print(OutputUtils.dim(
                "Use arrows for days/weeks, Enter to select, Esc to cancel"
            ))
            lineCount += 1

            lastRenderedLines = lineCount
        }

        render()

        while true {
            let input = KeyInput.readKey()

            switch input {
            case .up:
                selectedDate = Calendar.current.date(
                    byAdding: .day,
                    value: 1,
                    to: selectedDate
                ) ?? selectedDate
                render()
            case .down:
                selectedDate = Calendar.current.date(
                    byAdding: .day,
                    value: -1,
                    to: selectedDate
                ) ?? selectedDate
                render()
            case .right:
                selectedDate = Calendar.current.date(
                    byAdding: .weekOfYear,
                    value: 1,
                    to: selectedDate
                ) ?? selectedDate
                render()
            case .left:
                selectedDate = Calendar.current.date(
                    byAdding: .weekOfYear,
                    value: -1,
                    to: selectedDate
                ) ?? selectedDate
                render()
            case .enter:
                for _ in 0 ..< lastRenderedLines {
                    Terminal.moveCursor(up: 1)
                    Terminal.clearLine()
                }

                print(
                    "\(OutputUtils.green(Constants.successIcon)) \(message): " +
                        "\(OutputUtils.dim(formatter.string(from: selectedDate)))"
                )
                return selectedDate
            case .escape:
                for _ in 0 ..< lastRenderedLines {
                    Terminal.moveCursor(up: 1)
                    Terminal.clearLine()
                }
                return nil
            default:
                break
            }
        }
    }
}
