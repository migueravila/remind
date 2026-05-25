import ArgumentParser
import core
import Foundation

public struct DeleteReminderCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete one or more reminders",
        aliases: ["d", "rm"]
    )

    @Argument(
        parsing: .remaining,
        help: "Reminder number(s) or ID(s) to delete"
    )
    public var inputs: [String] = []

    @Option(name: .shortAndLong, help: "Scope ID resolution to this list")
    public var list: String?

    @Option(name: .long, help: "Scope ID resolution to this filter")
    public var filter: String?

    @Flag(
        name: [.customShort("y"), .customLong("force")],
        help: "Skip confirmation prompt"
    )
    public var force: Bool = false

    public init() {}

    public func run() async throws {
        let examples = [
            "  remind delete 1          # Delete reminder [1]",
            "  remind delete 1 2 3      # Delete multiple reminders",
            "  remind delete 4A83       # Delete by partial ID"
        ]

        guard let result = try await resolveReminderIDs(
            inputs,
            listScope: list,
            filterScope: filter,
            examples: examples
        ) else {
            return
        }

        let config = Config.load()
        let shouldConfirm = !force && config.confirmDelete

        if shouldConfirm {
            let shouldDelete = InputUtils.confirm(
                message: "Are you sure you want to delete \(result.ids.count) reminder(s)?",
                defaultValue: false
            )

            guard shouldDelete else {
                OutputUtils.printInfo("Delete operation cancelled")
                return
            }
        }

        try await result.manager.deleteReminders(ids: result.ids)
        let message = result.ids.count == 1
            ? "Deleted reminder"
            : "Deleted \(result.ids.count) reminders"
        OutputUtils.printSuccess(message)
    }
}
