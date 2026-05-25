import ArgumentParser
import core
import Foundation

public struct EditReminderCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "edit",
        abstract: "Edit an existing reminder",
        aliases: ["e"]
    )

    @Argument(help: "Reminder number or ID")
    public var input: String

    @Option(name: .customLong("list"), help: "Scope ID resolution to this list")
    public var listScope: String?

    @Option(name: .shortAndLong, help: "New title")
    public var title: String?

    @Option(name: .customLong("move-to"), help: "Move to a different list")
    public var moveTo: String?

    @Option(name: .shortAndLong, help: "New due date")
    public var due: String?

    @Option(name: .shortAndLong, help: "New priority (none, low, medium, high)")
    public var priority: String?

    @Option(name: .shortAndLong, help: "New notes")
    public var notes: String?

    @Flag(name: .shortAndLong, help: "Toggle flag (set flagged)")
    public var flag: Bool = false

    @Flag(name: .long, help: "Unset the flag")
    public var unflag: Bool = false

    public init() {}

    public func run() async throws {
        let manager = Manager()
        try await manager.requestAccess()

        let reminders = try await manager.getReminders(from: listScope)

        let resolved: [String] = if listScope == nil,
                                    let state = ViewStateStore.load()
        {
            IDResolver.resolveIDs(
                [input],
                snapshot: state.ids,
                reminders: reminders
            )
        } else {
            IDResolver.resolveIDs([input], from: reminders)
        }

        guard let id = resolved.first else {
            OutputUtils.printError("Reminder not found: \(input)")
            return
        }

        guard let reminder = reminders.first(where: { $0.id == id }) else {
            OutputUtils.printError("Reminder not found")
            return
        }

        let hasFlags = title != nil || moveTo != nil || due != nil ||
            priority != nil || notes != nil || flag || unflag

        if hasFlags {
            try await runDirect(manager: manager, id: id)
        } else {
            try await runInteractive(
                manager: manager,
                id: id,
                current: reminder
            )
        }
    }

    private func runDirect(manager: Manager, id: String) async throws {
        var parsedPriority: Reminder.Priority? = if let priority {
            parsePriority(priority)
        } else {
            nil
        }

        if parsedPriority == nil {
            if unflag {
                parsedPriority = Reminder.Priority.none
            } else if flag {
                parsedPriority = .high
            }
        }

        let parsedDue: Date?? = if let due {
            .some(DateUtils.parseNaturalDate(due))
        } else {
            nil
        }

        try await manager.updateReminder(
            id: id,
            title: title,
            notes: notes,
            priority: parsedPriority,
            dueDate: parsedDue,
            listName: moveTo
        )

        OutputUtils.printSuccess("Updated reminder")
    }

    private func runInteractive(
        manager: Manager,
        id: String,
        current: Reminder
    ) async throws {
        let newTitle = InputUtils.input(
            message: "Title",
            defaultValue: current.title
        ) ?? current.title

        let availableLists = try await manager.getAllLists()
        let listOptions = availableLists.map { ($0.title, $0.title) }
        let currentListIndex = availableLists.firstIndex {
            $0.title == current.listName
        } ?? 0

        let selectedList = InputUtils.select(
            message: "List:",
            options: listOptions,
            defaultIndex: currentListIndex
        )

        let wantsDueDate = InputUtils.confirm(
            message: "Set a due date?",
            defaultValue: current.dueDate != nil
        )

        let newDueDate: Date?? = if wantsDueDate {
            .some(InputUtils.datePicker(
                message: "Select due date:",
                initialDate: current.dueDate ?? Date()
            ))
        } else {
            .some(nil)
        }

        let newNotes = InputUtils.input(
            message: "Notes",
            defaultValue: current.notes ?? ""
        )

        let priorityOptions: [(String, Reminder.Priority)] = [
            ("None", .none),
            ("Low", .low),
            ("Medium", .medium),
            ("High", .high)
        ]
        let currentPriorityIndex = priorityOptions.firstIndex {
            $0.1 == current.priority
        } ?? 0

        let newPriority = InputUtils.select(
            message: "Priority:",
            options: priorityOptions,
            defaultIndex: currentPriorityIndex
        )

        try await manager.updateReminder(
            id: id,
            title: newTitle,
            notes: newNotes,
            priority: newPriority,
            dueDate: newDueDate,
            listName: selectedList
        )

        OutputUtils.printSuccess("Updated reminder: \(newTitle)")
    }
}
