import ArgumentParser
import core
import Foundation

public struct CleanCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Delete all completed reminders"
    )

    @Option(name: .shortAndLong, help: "Clean only this list")
    public var list: String?

    @Flag(
        name: [.customShort("y"), .customLong("force")],
        help: "Skip confirmation prompt"
    )
    public var force: Bool = false

    public init() {}

    public func run() async throws {
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
