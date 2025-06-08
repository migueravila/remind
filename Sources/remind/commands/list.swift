import ArgumentParser
import Foundation

struct ListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "Manage reminder lists",
        subcommands: [ShowListsCommand.self, CreateListCommand.self]
    )
}

struct ShowListsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Show all reminder lists"
    )
    
    func run() async throws {
        let cli = RemindCLI()
        try await cli.initialize()
        let lists = try await cli.getAllLists()
        
        OutputUtils.printTable(
            lists,
            headers: ["List Name", "Reminders"],
            valueExtractor: { [$0.title, "\($0.reminderCount)"] }
        )
    }
}

struct CreateListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a new reminder list"
    )
    
    @Argument(help: "Name of the new list")
    var name: String
    
    func run() async throws {
        let cli = RemindCLI()
        try await cli.initialize()
        let list = try await cli.createList(name: name)
        OutputUtils.printSuccess("Created list: \(list.title)")
    }
}

