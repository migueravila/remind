import ArgumentParser
import Foundation

struct AddReminderCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add", abstract: "Add a new reminder", aliases: ["a"]
    )

    @Argument(
        parsing: .remaining,
        help: "Reminder description"
    ) var description: [String] = []
    @Option(name: .shortAndLong, help: "List name") var list: String?
    @Option(
        name: .shortAndLong,
        help: "Due date (YYYY-MM-DD, 'today', 'tomorrow', etc.)"
    ) var due: String?

    func run() async throws {
        let manager = Manager()
        try await manager.requestAccess()

        let title: String
        if description.isEmpty {
            guard let inputTitle = InputUtils.input(
                message: "Reminder title",
                required: true
            ) else {
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
            let availableLists = try await manager.getAllLists()
            if availableLists.isEmpty {
                OutputUtils
                    .printError("No lists available. Create a list first.")
                return
            }

            let listOptions = availableLists.map { ($0.title, $0.title) }
            guard let selectedList = InputUtils.select(
                message: "Select a list:", options: listOptions, defaultIndex: 0
            ) else {
                OutputUtils.printError("No list selected")
                return
            }
            targetList = selectedList
        }

        let dueDate: Date?
        if let due = due {
            dueDate = DateUtils.parseNaturalDate(due)
            if dueDate == nil {
                OutputUtils
                    .printWarning(
                        "Invalid date format, continuing without due date"
                    )
            }
        } else {
            dueDate = nil
        }

        let reminder = Reminder(
            id: nil, title: title, notes: nil, isCompleted: false,
            priority: .none, dueDate: dueDate, listName: targetList
        )

        try await manager.createReminder(reminder, in: targetList)
        OutputUtils.printSuccess("Added reminder: \(title)")
    }
}

struct CompleteReminderCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "complete", abstract: "Complete one or more reminders",
        aliases: ["c"]
    )

    @Argument(
        parsing: .remaining,
        help: "Reminder number(s) or ID(s) to complete"
    ) var inputs: [String]

    func run() async throws {
        guard !inputs.isEmpty else {
            OutputUtils
                .printError("Please provide at least one reminder number or ID")
            print("Examples:")
            print("  remind complete 1        # Complete reminder [1]")
            print("  remind complete 1 2 3    # Complete multiple reminders")
            print("  remind complete 4A83     # Complete by partial ID")
            return
        }

        let manager = Manager()
        try await manager.requestAccess()
        let allReminders = try await manager.getReminders(from: nil)
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
            OutputUtils
                .printWarning(
                    "Only \(resolvedCount) of \(totalCount) inputs could be resolved"
                )
        }

        try await manager.completeReminders(ids: validIDs)
        let message = validIDs
            .count == 1 ? "Completed reminder" :
            "Completed \(validIDs.count) reminders"
        OutputUtils.printSuccess(message)
    }
}

struct DeleteReminderCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete", abstract: "Delete one or more reminders",
        aliases: ["d"]
    )

    @Argument(
        parsing: .remaining,
        help: "Reminder number(s) or ID(s) to delete"
    ) var inputs: [String]

    func run() async throws {
        guard !inputs.isEmpty else {
            OutputUtils
                .printError("Please provide at least one reminder number or ID")
            print("Examples:")
            print("  remind delete 1          # Delete reminder [1]")
            print("  remind delete 1 2 3      # Delete multiple reminders")
            print("  remind delete 4A83       # Delete by partial ID")
            return
        }

        let manager = Manager()
        try await manager.requestAccess()
        let allReminders = try await manager.getReminders(from: nil)
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
            OutputUtils
                .printWarning(
                    "Only \(resolvedCount) of \(totalCount) inputs could be resolved"
                )
        }

        let shouldDelete = InputUtils.confirm(
            message: "Are you sure you want to delete \(validIDs.count) reminder(s)?",
            defaultValue: false
        )

        guard shouldDelete else {
            OutputUtils.printInfo("Delete operation cancelled")
            return
        }

        try await manager.deleteReminders(ids: validIDs)
        let message = validIDs
            .count == 1 ? "Deleted reminder" :
            "Deleted \(validIDs.count) reminders"
        OutputUtils.printSuccess(message)
    }
}
