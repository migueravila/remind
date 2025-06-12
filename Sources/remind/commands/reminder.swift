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

struct AddReminderCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add", abstract: "Add a new reminder", aliases: ["a"])
    @Argument(parsing: .remaining, help: "Reminder description")
    var description: [String] = []
    @Option(name: .shortAndLong, help: "List name") var list: String?
    @Option(
        name: .shortAndLong,
        help: "Due date (YYYY-MM-DD, 'today', 'tomorrow', etc.)") var due:
        String?
    func run() async throws {
        let cli = RemindCLI()
        try await cli.initialize()
        let title: String
        if description.isEmpty {
            guard
                let inputTitle = InputUtils.input(
                    message: "Reminder title", required: true)
            else {
                OutputUtils.printError("Title is required")
                return
            }
            title = inputTitle
        } else {
            title = description.joined(separator: " ")
        }
        let targetList: String
        if let list = list {
            targetList = list
        } else {
            let availableLists = try await cli.getAllLists()
            if availableLists.isEmpty {
                OutputUtils.printError(
                    "No lists available. Create a list first.")
                return
            }
            let listOptions = availableLists.map { ($0.title, $0.title) }
            guard
                let selectedList = InputUtils.select(
                    message: "Select a list:", options: listOptions,
                    defaultIndex: 0)
            else {
                OutputUtils.printError("No list selected")
                return
            }
            targetList = selectedList
        }
        let dueDate: Date?
        if let due = due {
            dueDate = DateUtils.parseNaturalDate(due)
            if dueDate == nil {
                OutputUtils.printWarning(
                    "Invalid date format, continuing without due date")
            }
        } else {
            dueDate = nil
        }
        let reminder = ReminderItem(
            id: nil, title: title, notes: nil, isCompleted: false,
            priority: .none, dueDate: dueDate, listName: targetList)
        try await cli.createReminder(reminder, in: targetList)
        OutputUtils.printSuccess("Added reminder: \(title)")
    }
}


struct CompleteReminderCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "complete", abstract: "Complete one or more reminders",
        aliases: ["c"])
    @Argument(
        parsing: .remaining, help: "Reminder number(s) or ID(s) to complete")
    var inputs: [String]
    func run() async throws {
        guard !inputs.isEmpty else {
            OutputUtils.printError(
                "Please provide at least one reminder number or ID")
            print("Examples:")
            print("  remind complete 1        # Complete reminder [1]")
            print("  remind complete 1 2 3    # Complete multiple reminders")
            print("  remind complete 4A83     # Complete by partial ID")
            return
        }
        let cli = RemindCLI()
        try await cli.initialize()
        let allReminders = try await cli.getReminders(from: nil)
        let validIDs = IDResolver.resolveIDs(inputs, from: allReminders)
        guard !validIDs.isEmpty else {
            OutputUtils.printError("No valid reminder numbers or IDs found")
            print(
                "Use 'remind show' to see available reminders with their numbers"
            )
            return
        }
        if validIDs.count < inputs.count {
            let resolvedCount = validIDs.count
            let totalCount = inputs.count
            OutputUtils.printWarning(
                "Only \(resolvedCount) of \(totalCount) inputs could be resolved"
            )
        }
        try await cli.completeReminders(ids: validIDs)
        let message =
            validIDs.count == 1
            ? "Completed reminder" : "Completed \(validIDs.count) reminders"
        OutputUtils.printSuccess(message)
    }
}

struct DeleteReminderCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete", abstract: "Delete one or more reminders",
        aliases: ["d"])
    @Argument(
        parsing: .remaining, help: "Reminder number(s) or ID(s) to delete")
    var inputs: [String]
    func run() async throws {
        guard !inputs.isEmpty else {
            OutputUtils.printError(
                "Please provide at least one reminder number or ID")
            print("Examples:")
            print("  remind delete 1          # Delete reminder [1]")
            print("  remind delete 1 2 3      # Delete multiple reminders")
            print("  remind delete 4A83       # Delete by partial ID")
            return
        }
        let cli = RemindCLI()
        try await cli.initialize()
        let allReminders = try await cli.getReminders(from: nil)
        let validIDs = IDResolver.resolveIDs(inputs, from: allReminders)
        guard !validIDs.isEmpty else {
            OutputUtils.printError("No valid reminder numbers or IDs found")
            print(
                "Use 'remind show' to see available reminders with their numbers"
            )
            return
        }
        if validIDs.count < inputs.count {
            let resolvedCount = validIDs.count
            let totalCount = inputs.count
            OutputUtils.printWarning(
                "Only \(resolvedCount) of \(totalCount) inputs could be resolved"
            )
        }
        let shouldDelete = InputUtils.confirm(
            message:
                "Are you sure you want to delete \(validIDs.count) reminder(s)?",
            defaultValue: false)
        guard shouldDelete else {
            OutputUtils.printInfo("Delete operation cancelled")
            return
        }
        try await cli.deleteReminders(ids: validIDs)
        let message =
            validIDs.count == 1
            ? "Deleted reminder" : "Deleted \(validIDs.count) reminders"
        OutputUtils.printSuccess(message)
    }
}
