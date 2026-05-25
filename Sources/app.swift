import ArgumentParser
import cli
import commands
import Foundation

@main struct Remind: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remind",
        abstract: "Apple Reminders for terminal natives",
        version: HelpRenderer.version,
        subcommands: [
            ShowCommand.self,
            ListsCommand.self,
            AddReminderCommand.self,
            EditReminderCommand.self,
            DoneReminderCommand.self,
            DeleteReminderCommand.self,
            ArchiveCommand.self,
            RenameCommand.self,
            CleanCommand.self,
            PurgeCommand.self,
            HelpCommand.self,
        ],
        defaultSubcommand: ShowCommand.self
    )

    static func main() async {
        let rawArgs = Array(CommandLine.arguments.dropFirst())

        if shouldShowHelp(rawArgs) {
            HelpRenderer.render()
            return
        }

        let args = ArgDispatcher.rewrite(rawArgs)
        do {
            try await runRoot(args: args)
        } catch {
            exit(withError: error)
        }
    }

    private nonisolated static func runRoot(args: [String]) async throws {
        let command = try parseAsRoot(args)
        if var command = command as? AsyncParsableCommand {
            try await command.run()
        } else {
            var command = command
            try command.run()
        }
    }

    private static func shouldShowHelp(_ args: [String]) -> Bool {
        guard let first = args.first else { return false }
        let lowerFirst = first.lowercased()
        return lowerFirst == "help" || lowerFirst == "--help"
            || lowerFirst == "-h"
    }
}
