import ArgumentParser
import core
import Foundation

public struct DoneReminderCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "done",
        abstract: "Mark one or more reminders as complete"
    )

    @Argument(
        parsing: .remaining,
        help: "Reminder number(s) or ID(s) to complete"
    )
    public var inputs: [String] = []

    @Option(name: .shortAndLong, help: "Scope ID resolution to this list")
    public var list: String?

    @Option(name: .long, help: "Scope ID resolution to this filter")
    public var filter: String?

    public init() {}

    public func run() async throws {
        let examples = [
            "  remind done 1        # Complete reminder [1]",
            "  remind done 1 2 3    # Complete multiple reminders",
            "  remind done 4A83     # Complete by partial ID"
        ]

        guard let result = try await resolveReminderIDs(
            inputs,
            listScope: list,
            filterScope: filter,
            examples: examples
        ) else {
            return
        }

        try await result.manager.completeReminders(ids: result.ids)
        let message = result.ids.count == 1
            ? "Completed reminder"
            : "Completed \(result.ids.count) reminders"
        OutputUtils.printSuccess(message)
    }
}
