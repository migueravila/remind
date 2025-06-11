import ArgumentParser
import Foundation

struct ReminderCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reminder", abstract: "Manage reminders",
        subcommands: [
            ShowRemindersCommand.self, CreateReminderCommand.self,
            CreateInteractiveReminderCommand.self,
        ])
}

struct ShowRemindersCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show", abstract: "Show reminders")

    @Option(name: .shortAndLong, help: "List name to filter reminders")
    var list: String?
    @Flag(name: .shortAndLong, help: "Show only completed reminders")
    var completed: Bool = false
    @Flag(name: .shortAndLong, help: "Show only pending reminders") var pending:
        Bool = false

    func run() async throws {
        let cli = RemindCLI()
        try await cli.initialize()
        var reminders = try await cli.getReminders(from: list)
        if completed {
            reminders = reminders.filter { $0.isCompleted }
        } else if pending {
            reminders = reminders.filter { !$0.isCompleted }
        }
        OutputUtils.printReminders(reminders)
    }
}

struct CreateReminderCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create", abstract: "Create a new reminder")

    @Argument(help: "Title of the reminder") var title: String

    @Option(name: .shortAndLong, help: "List name") var list: String

    @Option(name: .shortAndLong, help: "Notes for the reminder") var notes:
        String?

    @Option(name: .shortAndLong, help: "Due date (YYYY-MM-DD or MM/DD/YYYY)")
    var dueDate: String?

    @Option(name: .shortAndLong, help: "Priority (none, low, medium, high)")
    var priority: String = "none"

    func run() async throws {
        let cli = RemindCLI()
        try await cli.initialize()

        let priorityValue =
            ReminderItem.Priority.allCases.first {
                $0.displayName.lowercased() == priority.lowercased()
            } ?? .none

        let parsedDate = dueDate.flatMap(DateUtils.parseDate)

        let reminder = ReminderItem(
            id: nil, title: title, notes: notes, isCompleted: false,
            priority: priorityValue, dueDate: parsedDate, listName: list)

        try await cli.createReminder(reminder, in: list)
        OutputUtils.printSuccess("Created reminder: \(title)")
    }
}

struct CreateInteractiveReminderCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "new", abstract: "Create a new reminder interactively")

    func run() async throws {
        let cli = RemindCLI()
        try await cli.initialize()
        OutputUtils.printInfo("Creating a new reminder")
        print()
        guard
            let title = InputUtils.input(
                message: "Reminder title", required: true)
        else {
            OutputUtils.printError("Title is required")
            return
        }
        let availableLists = try await cli.getAllLists()
        let listOptions =
            availableLists.map { ($0.title, $0.title) } + [
                ("Create new list", "new")
            ]
        guard
            let selectedListAction = InputUtils.select(
                message: "\nSelect a list:", options: listOptions,
                defaultIndex: 0)
        else {
            OutputUtils.printError("No list selected")
            return
        }
        let targetList: String
        if selectedListAction == "new" {
            guard
                let newListName = InputUtils.input(
                    message: "New list name", required: true)
            else {
                OutputUtils.printError("List name is required")
                return
            }
            targetList = newListName
        } else {
            targetList = selectedListAction
        }
        let notes = InputUtils.input(message: "Notes (optional)")
        let dueDateString = InputUtils.input(
            message: "Due date (YYYY-MM-DD, MM/DD/YYYY, or leave empty)")
        let dueDate: Date?
        if let dueDateString = dueDateString, !dueDateString.isEmpty {
            dueDate = DateUtils.parseDate(dueDateString)
            if dueDate == nil {
                OutputUtils.printWarning(
                    "Invalid date format, continuing without due date")
            }
        } else {
            dueDate = nil
        }
        let priorityOptions = ReminderItem.Priority.allCases.map {
            ($0.displayName, $0)
        }
        guard
            let priority = InputUtils.select(
                message: "\nSelect priority:", options: priorityOptions,
                defaultIndex: 0)
        else {
            OutputUtils.printError("No priority selected")
            return
        }
        print("\n" + String(repeating: "-", count: 40))
        OutputUtils.printInfo("Reminder Summary:")
        print("  Title: \(title)")
        print("  List: \(targetList)")
        if let notes = notes, !notes.isEmpty { print("  Notes: \(notes)") }
        if let dueDate = dueDate {
            print("  Due: \(DateUtils.formatDate(dueDate))")
        }
        print("  Priority: \(priority.displayName)")
        print(String(repeating: "-", count: 40))
        let shouldCreate = InputUtils.confirm(
            message: "Create this reminder?", defaultValue: true)
        guard shouldCreate else {
            OutputUtils.printInfo("Reminder creation cancelled")
            return
        }
        let reminder = ReminderItem(
            id: nil, title: title, notes: notes?.isEmpty == true ? nil : notes,
            isCompleted: false, priority: priority, dueDate: dueDate,
            listName: targetList)
        try await cli.createReminder(reminder, in: targetList)
        OutputUtils.printSuccess("Created reminder: \(title)")
    }
}
