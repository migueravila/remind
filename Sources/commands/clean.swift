import ArgumentParser
import core
import Foundation

public struct CleanCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Delete every reminder in a list (keeps the list itself)"
    )

    @Argument(help: "List name to clean")
    public var name: String

    @Flag(
        name: [.customShort("y"), .customLong("force")],
        help: "Skip confirmation prompt"
    )
    public var force: Bool = false

    public init() {}

    public func run() async throws {
        let manager = Manager()
        try await manager.requestAccess()

        let reminders = try await manager.getReminders(from: name)
        guard !reminders.isEmpty else {
            OutputUtils.printInfo("List '\(name)' is already empty")
            return
        }

        let shouldConfirm = !force && Config.load().confirmDelete
        if shouldConfirm {
            let ok = InputUtils.confirm(
                message: "Delete all \(reminders.count) reminder(s) in '\(name)'?",
                defaultValue: false
            )
            guard ok else {
                OutputUtils.printInfo("Cancelled")
                return
            }
        }

        let ids = reminders.compactMap(\.id)
        try await manager.deleteReminders(ids: ids)
        OutputUtils.printSuccess(
            "Cleaned \(ids.count) reminder(s) from '\(name)'"
        )
    }
}
