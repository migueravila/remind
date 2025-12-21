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
        name: [.short, .customLong("rename")],
        help: "New name to rename the list to"
    ) var rename: String?

    @Flag(
        name: [.short, .customLong("delete")],
        help: "Delete the list"
    ) var delete: Bool = false

    @Flag(name: .long, help: "Output as JSON")
    var json: Bool = false

    @Flag(name: .long, help: "Plain text without colors")
    var plain: Bool = false

    @Flag(name: .long, help: "Minimal output (count only)")
    var quiet: Bool = false

    func run() async throws {
        let manager = Manager()
        try await manager.requestAccess()

        if delete {
            guard let listName = name else {
                OutputUtils.printError("List name required for delete operation")
                return
            }
            try await manager.deleteList(name: listName)
            OutputUtils.printSuccess("Deleted list: \(listName)")
            return
        }

        if let newName = rename {
            guard let oldName = name else {
                OutputUtils.printError("List name required for rename operation")
                return
            }
            try await manager.renameList(oldName: oldName, newName: newName)
            OutputUtils.printSuccess("Renamed list '\(oldName)' to '\(newName)'")
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
