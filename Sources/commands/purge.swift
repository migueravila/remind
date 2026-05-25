import ArgumentParser
import core
import Foundation

public struct PurgeCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "purge",
        abstract: "Delete completed reminders (in a list or across all lists)"
    )

    @Argument(help: "List name to purge (omit for all lists)")
    public var name: String?

    @Flag(
        name: [.customShort("y"), .customLong("force")],
        help: "Skip confirmation prompt"
    )
    public var force: Bool = false

    public init() {}

    public func run() async throws {
        let manager = Manager()
        try await manager.requestAccess()

        let all = try await manager.getReminders(from: name)
        let completed = all.filter(\.isCompleted)

        guard !completed.isEmpty else {
            OutputUtils.printInfo("No completed reminders to purge")
            return
        }

        let scope = name.map { "in list '\($0)'" } ?? "across all lists"
        let shouldConfirm = !force && Config.load().confirmDelete
        if shouldConfirm {
            let ok = InputUtils.confirm(
                message: "Delete \(completed.count) completed reminder(s) \(scope)?",
                defaultValue: false
            )
            guard ok else {
                OutputUtils.printInfo("Cancelled")
                return
            }
        }

        let deleted = try await manager.purgeCompleted(in: name)
        OutputUtils.printSuccess(
            "Purged \(deleted) completed reminder(s)"
        )
    }
}
