import ArgumentParser
import Foundation

struct HelpCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "help",
        abstract: "Show help"
    )

    func run() throws {
        HelpRenderer.render()
    }
}

enum HelpRenderer {
    static let version = "1.0.0"

    private static let banner = """
           ▘   ▌
    ▛▘█▌▛▛▌▌▛▌▛▌
    ▌ ▙▖▌▌▌▌▌▌▙▌
    """

    private static let subtitle =
        "Apple Reminders for terminal natives  v\(version)"

    static func render() {
        printBanner()
        printBlank()
        printSection(
            title: "USAGE",
            entries: [
                (
                    "remind [list] [command] [arguments] [flags]",
                    ""
                )
            ]
        )
        printSection(
            title: "FILTERS",
            entries: [
                ("remind", "Show today's reminders (default)"),
                ("remind today", "Show today's reminders"),
                ("remind tomorrow", "Show tomorrow's reminders"),
                ("remind upcoming", "Show upcoming reminders"),
                ("remind flag", "Show flagged reminders"),
                ("remind done", "Show completed reminders"),
                ("remind all", "Show every reminder"),
            ]
        )
        printSection(
            title: "LISTS",
            entries: [
                ("remind lists", "Show all reminder lists"),
                ("remind <list>", "Show reminders in a list"),
                ("remind close <list>", "Archive a list"),
                ("remind rename <list> <name>", "Rename a list"),
                (
                    "remind clean <list>",
                    "Remove completed reminders from a list"
                ),
            ]
        )
        printSection(
            title: "REMINDERS",
            entries: [
                ("remind add \"<title>\"", "Add a reminder"),
                ("remind edit <id>", "Edit a reminder"),
                (
                    "remind complete <id...>",
                    "Mark reminders complete (alias: done)"
                ),
                (
                    "remind delete <id...>",
                    "Delete reminders (aliases: d, rm)"
                ),
            ]
        )
        printSection(
            title: "OUTPUT",
            entries: [
                ("--json", "Output as JSON"),
                ("--plain", "Plain text without colors"),
                ("--quiet", "Minimal output (count only)"),
            ]
        )
        printSection(
            title: "MISC",
            entries: [
                ("remind help", "Show this help screen"),
                ("remind --version, -v", "Show version"),
            ]
        )
        printSection(
            title: "EXAMPLES",
            entries: [
                (
                    "remind Work",
                    "# reminders in \"Work\""
                ),
                (
                    "remind Work add \"ship it\"",
                    "# add to \"Work\""
                ),
                (
                    "remind add \"buy milk\" -d tomorrow -f",
                    ""
                ),
                (
                    "remind edit 1 -t \"buy milk and bread\"",
                    ""
                ),
                (
                    "remind done 1 2 3",
                    "# complete by id"
                ),
                (
                    "remind clean Work -y",
                    "# purge completed in \"Work\""
                ),
            ]
        )
    }

    private static func printBanner() {
        print(banner)
        print(subtitle)
    }

    private static func printBlank() {
        print("")
    }

    private static func printSection(
        title: String,
        entries: [(String, String)]
    ) {
        print("")
        print(title)
        let maxWidth = entries
            .map { $0.0.count }
            .max() ?? 0
        for (invocation, description) in entries {
            let padding = String(
                repeating: " ",
                count: maxWidth - invocation.count
            )
            if description.isEmpty {
                print("  \(invocation)")
            } else {
                print("  \(invocation)\(padding)   \(description)")
            }
        }
    }
}
