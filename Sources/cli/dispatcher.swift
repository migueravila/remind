import core
import Foundation

public enum ArgDispatcher {
    public static let filterVerbs: Set<String> = [
        "today",
        "tomorrow",
        "upcoming",
        "all",
    ]

    public static let listVerbs: Set<String> = [
        "list", "lists", "l",
    ]

    public static let manipulatorVerbs: Set<String> = [
        "add", "a",
        "edit", "e",
        "done",
        "delete", "d", "rm",
        "archive",
        "rename",
        "clean",
        "purge",
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

        if filterVerbs.contains(head) {
            return rewriteFilterContext(filter: head, rest: rest)
        }

        if listVerbs.contains(head) {
            return ["lists"] + rest
        }

        if DateUtils.parseSpecificDate(first) != nil {
            return rewriteFilterContext(filter: first, rest: rest)
        }

        if manipulatorVerbs.contains(head) || miscVerbs.contains(head) {
            return args
        }

        return rewriteListContext(listName: first, rest: rest)
    }

    private static func rewriteFilterContext(
        filter: String,
        rest: [String]
    ) -> [String] {
        if rest.isEmpty {
            return ["show", filter]
        }

        let verb = rest[0].lowercased()
        let after = Array(rest.dropFirst())

        switch verb {
        case "add", "a":
            if filterMapsToDueDate(filter) {
                return ["add", "--due", filter] + after
            }
            return ["add"] + after
        case "done":
            return ["done", "--filter", filter] + after
        case "delete", "d", "rm":
            return ["delete", "--filter", filter] + after
        case "edit", "e":
            return ["edit", "--filter", filter] + after
        default:
            return ["show", filter] + rest
        }
    }

    private static func filterMapsToDueDate(_ filter: String) -> Bool {
        let lower = filter.lowercased()
        if lower == "today" || lower == "tomorrow" { return true }
        return DateUtils.parseSpecificDate(filter) != nil
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
            return ["done", "--list", listName] + after
        case "delete", "d", "rm":
            return ["delete", "--list", listName] + after
        case "edit", "e":
            return ["edit", "--list", listName] + after
        default:
            return ["show", "--list", listName] + rest
        }
    }
}
