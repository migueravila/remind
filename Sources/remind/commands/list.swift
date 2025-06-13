import ArgumentParser
import Foundation

struct ListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list", abstract: "Manage reminder lists"
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

        if let listName = name {
            let lists = try await manager.getAllLists()
            let listExists = lists.contains { $0.title == listName }

            if listExists {
                let reminders = try await manager.getReminders(from: listName)
                OutputUtils.printReminders(
                    reminders,
                    title: "Reminders in '\(listName)'"
                )
            } else {
                let list = try await manager.createList(name: listName)
                OutputUtils.printSuccess("Created list: \(list.title)")
            }
        } else {
            let lists = try await manager.getAllLists()
            OutputUtils.printLists(lists)
        }
    }
}

struct ShowListsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lists", abstract: "Show all reminder lists",
        aliases: ["l"]
    )

    func run() async throws {
        let manager = Manager()
        try await manager.requestAccess()
        let lists = try await manager.getAllLists()
        OutputUtils.printLists(lists)
    }
}
