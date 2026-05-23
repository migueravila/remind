import ArgumentParser
import core
import Foundation

struct CloseCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "close",
        abstract: "Close (delete) a list and all its reminders"
    )

    @Argument(help: "List name to close")
    var name: String

    @Flag(
        name: [.customShort("y"), .customLong("force")],
        help: "Skip confirmation prompt"
    )
    var force: Bool = false

    func run() async throws {
        let manager = Manager()
        try await manager.requestAccess()

        let shouldConfirm = !force && Config.load().confirmDelete
        if shouldConfirm {
            let ok = InputUtils.confirm(
                message: "Close list '\(name)' and delete all its reminders?",
                defaultValue: false
            )
            guard ok else {
                OutputUtils.printInfo("Cancelled")
                return
            }
        }

        try await manager.deleteList(name: name)
        OutputUtils.printSuccess("Closed list: \(name)")
    }
}

struct RenameCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rename",
        abstract: "Rename a list"
    )

    @Argument(help: "Current list name") var oldName: String
    @Argument(help: "New list name") var newName: String

    func run() async throws {
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

struct CleanCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Delete all completed reminders"
    )

    @Option(name: .shortAndLong, help: "Clean only this list")
    var list: String?

    @Flag(
        name: [.customShort("y"), .customLong("force")],
        help: "Skip confirmation prompt"
    )
    var force: Bool = false

    func run() async throws {
        let manager = Manager()
        try await manager.requestAccess()

        let all = try await manager.getReminders(from: list)
        let completed = all.filter(\.isCompleted)

        guard !completed.isEmpty else {
            OutputUtils.printInfo("No completed reminders to clean")
            return
        }

        let scope = list.map { "in list '\($0)'" } ?? "across all lists"
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

        let deleted = try await manager.cleanCompleted(in: list)
        OutputUtils.printSuccess(
            "Cleaned \(deleted) completed reminder(s)"
        )
    }
}
