import core
import Foundation

public enum ArgDispatcher {
    public static let filterVerbs: Set<String> = [
        "today",
        "tomorrow",
        "upcoming",
        "done",
        "all",
    ]

    public static let listVerbs: Set<String> = [
        "list", "lists", "l",
    ]

    public static let manipulatorVerbs: Set<String> = [
        "add", "a",
        "edit", "e",
        "complete", "c",
        "delete", "d", "rm",
        "close",
        "rename",
        "clean",
    ]

    public static let miscVerbs: Set<String> = [
        "help", "version",
    ]

    public static var reservedWords: Set<String> {
        filterVerbs
            .union(listVerbs)
            .union(manipulatorVerbs)
            .union(miscVerbs)
    }

    public static func isReserved(_ name: String) -> Bool {
        reservedWords.contains(name.lowercased())
    }

    public static func rewrite(_ args: [String]) -> [String] {
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
