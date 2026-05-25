import ArgumentParser
import core
import Foundation

public struct ArchiveCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "archive",
        abstract: "Archive (delete) a list and all its reminders"
    )

    @Argument(help: "List name to archive")
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

        let shouldConfirm = !force && Config.load().confirmDelete
        if shouldConfirm {
            let ok = InputUtils.confirm(
                message: "Archive list '\(name)' and delete all its reminders?",
                defaultValue: false
            )
            guard ok else {
                OutputUtils.printInfo("Cancelled")
                return
            }
        }

        try await manager.deleteList(name: name)
        OutputUtils.printSuccess("Archived list: \(name)")
    }
}
