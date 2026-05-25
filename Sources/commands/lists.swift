import ArgumentParser
import cli
import core
import Foundation

public struct ListsCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "lists",
        abstract: "Show all reminder lists"
    )

    @OptionGroup public var output: OutputOptions

    public init() {}

    public func run() async throws {
        let manager = Manager()
        try await manager.requestAccess()

        let lists = try await manager.getAllLists()
        let reminders = try await manager.getReminders(from: nil)
        OutputUtils.printLists(
            lists,
            reminders: reminders,
            format: output.format
        )
        ViewStateStore.save(ViewState(spec: .lists, ids: []))
    }
}
