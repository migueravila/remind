import ArgumentParser
import cli
import core
import Foundation

public struct RenameCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "rename",
        abstract: "Rename a list"
    )

    @Argument(help: "Current list name") public var oldName: String
    @Argument(help: "New list name") public var newName: String

    public init() {}

    public func run() async throws {
        let manager = Manager()
        try await manager.requestAccess()

        if ArgDispatcher.isReserved(newName) {
            OutputUtils.printError(
                "'\(newName)' is a reserved name and cannot be used as a list name"
            )
            return
        }

        try await manager.renameList(oldName: oldName, newName: newName)
        OutputUtils.printSuccess("Renamed list '\(oldName)' to '\(newName)'")
    }
}
