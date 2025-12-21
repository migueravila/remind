import ArgumentParser
import core
import Foundation

struct ListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "Manage reminder lists",
        aliases: ["l"]
    )

    @Argument(help: "List name") var name: String?
    @Option(
        name: [.short, .customLong("delete")],
        help: "Delete a list"
    ) var delete: String?
    @Option(
        name: [.short, .customLong("rename")],
        help: "Rename a list (provide old name)"
    ) var rename: String?
    @Argument(
        parsing: .remaining,
        help: "New name for rename operation"
    ) var remainingArgs: [String] = []

    @Flag(name: .long, help: "Output as JSON")
    var json: Bool = false

    @Flag(name: .long, help: "Plain text without colors")
    var plain: Bool = false

    @Flag(name: .long, help: "Minimal output (count only)")
    var quiet: Bool = false

    func run() async throws {
        let manager = Manager()
        try await manager.requestAccess()

        if let deleteListName = delete {
            try await manager.deleteList(name: deleteListName)
            OutputUtils.printSuccess("Deleted list: \(deleteListName)")
            return
        }

        if let oldName = rename {
            guard let newName = remainingArgs.first else {
                OutputUtils.printError("New name required for rename operation")
                return
            }
            try await manager.renameList(oldName: oldName, newName: newName)
            OutputUtils
                .printSuccess("Renamed list '\(oldName)' to '\(newName)'")
            return
        }

        let format = resolveOutputFormat()

        if let listName = name {
            let lists = try await manager.getAllLists()
            let listExists = lists.contains { $0.title == listName }

            if listExists {
                let reminders = try await manager.getReminders(from: listName)
                OutputUtils.printReminders(reminders, format: format)
            } else {
                let list = try await manager.createList(name: listName)
                OutputUtils.printSuccess("Created list: \(list.title)")
            }
        } else {
            let lists = try await manager.getAllLists()
            let reminders = try await manager.getReminders(from: nil)
            OutputUtils.printLists(lists, reminders: reminders, format: format)
        }
    }

    private func resolveOutputFormat() -> OutputFormat {
        if json { return .json }
        if plain { return .plain }
        if quiet { return .quiet }
        return .standard
    }
}
