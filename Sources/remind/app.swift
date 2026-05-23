import ArgumentParser
import core
import Foundation

@main struct Remind: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remind",
        abstract: "Apple Reminders for terminal natives",
        version: "1.0.0",
        subcommands: [
            ShowCommand.self,
            ListsCommand.self,
            AddReminderCommand.self,
            EditReminderCommand.self,
            CompleteReminderCommand.self,
            DeleteReminderCommand.self,
            CloseCommand.self,
            RenameCommand.self,
            CleanCommand.self,
        ],
        defaultSubcommand: ShowCommand.self
    )

    static func main() async {
        let rawArgs = Array(CommandLine.arguments.dropFirst())
        let args = ArgDispatcher.rewrite(rawArgs)
        do {
            let command = try parseAsRoot(args)
            if var command = command as? AsyncParsableCommand {
                try await command.run()
            } else {
                var command = command
                try command.run()
            }
        } catch {
            exit(withError: error)
        }
    }
}

struct OutputOptions: ParsableArguments {
    @Flag(name: .long, help: "Output as JSON")
    var json: Bool = false

    @Flag(name: .long, help: "Plain text without colors")
    var plain: Bool = false

    @Flag(name: .long, help: "Minimal output (count only)")
    var quiet: Bool = false

    var format: OutputFormat {
        if json { return .json }
        if plain { return .plain }
        if quiet { return .quiet }
        return .standard
    }
}

enum ArgDispatcher {
    static let filterVerbs: Set<String> = [
        "today",
        "tomorrow",
        "upcoming",
        "flag",
        "done",
        "all",
    ]

    static let listVerbs: Set<String> = [
        "list", "lists", "l",
    ]

    static let manipulatorVerbs: Set<String> = [
        "add", "a",
        "edit", "e",
        "complete", "c",
        "delete", "d", "rm",
        "close",
        "rename",
        "clean",
    ]

    static let miscVerbs: Set<String> = [
        "help", "version",
    ]

    static var reservedWords: Set<String> {
        filterVerbs
            .union(listVerbs)
            .union(manipulatorVerbs)
            .union(miscVerbs)
    }

    static func isReserved(_ name: String) -> Bool {
        reservedWords.contains(name.lowercased())
    }

    static func rewrite(_ args: [String]) -> [String] {
        guard let first = args.first else { return args }

        if first == "-v" { return ["--version"] }
        if first.hasPrefix("-") { return args }

        let head = first.lowercased()
        let rest = Array(args.dropFirst())

        if head == "version" { return ["--version"] }

        if head == "done" {
            return rewriteDone(rest: rest)
        }

        if filterVerbs.contains(head) {
            return ["show", head] + rest
        }

        if listVerbs.contains(head) {
            return ["lists"] + rest
        }

        if DateUtils.parseSpecificDate(first) != nil {
            return ["show", first] + rest
        }

        if manipulatorVerbs.contains(head) || miscVerbs.contains(head) {
            return args
        }

        return rewriteListContext(listName: first, rest: rest)
    }

    private static func rewriteDone(rest: [String]) -> [String] {
        if rest.isEmpty {
            return ["show", "done"]
        }
        return ["complete"] + rest
    }

    private static func rewriteListContext(
        listName: String,
        rest: [String]
    ) -> [String] {
        if rest.isEmpty {
            return ["show", "--list", listName]
        }

        let verb = rest[0].lowercased()
        let after = Array(rest.dropFirst())

        switch verb {
        case "add", "a":
            return ["add", "--list", listName] + after
        case "done":
            if after.isEmpty {
                return ["show", "--list", listName, "--completed"]
            }
            return ["complete", "--list", listName] + after
        case "complete", "c":
            return ["complete", "--list", listName] + after
        case "delete", "d", "rm":
            return ["delete", "--list", listName] + after
        case "edit", "e":
            return ["edit", "--list", listName] + after
        default:
            return ["show", "--list", listName] + rest
        }
    }
}
