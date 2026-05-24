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

    private static let allSections: [(String, [(String, String)])] = [
        (
            "USAGE",
            [
                (
                    "remind [list] [command] [arguments] [flags]",
                    ""
                )
            ]
        ),
        (
            "FILTERS",
            [
                ("remind", "Show today's reminders (default)"),
                ("remind today", "Show today's reminders"),
                ("remind tomorrow", "Show tomorrow's reminders"),
                ("remind upcoming", "Show upcoming reminders"),
                ("remind done", "Show completed reminders"),
                ("remind all", "Show every reminder"),
            ]
        ),
        (
            "LISTS",
            [
                ("remind lists", "Show all reminder lists"),
                ("remind <list>", "Show reminders in a list"),
                ("remind close <list>", "Archive a list"),
                ("remind rename <list> <name>", "Rename a list"),
                (
                    "remind clean <list>",
                    "Remove completed reminders from a list"
                ),
            ]
        ),
        (
            "REMINDERS",
            [
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
        ),
        (
            "OUTPUT",
            [
                ("--json", "Output as JSON"),
                ("--plain", "Plain text without colors"),
                ("--quiet", "Minimal output (count only)"),
            ]
        ),
        (
            "MISC",
            [
                ("remind help", "Show this help screen"),
                ("remind --version, -v", "Show version"),
            ]
        ),
    ]

    static func render() {
        let globalMaxWidth = calculateGlobalMaxWidth()
        printBanner()
        printBlank()
        for (title, entries) in allSections {
            printSection(
                title: title,
                entries: entries,
                maxWidth: globalMaxWidth
            )
        }
    }

    private static func calculateGlobalMaxWidth() -> Int {
        allSections
            .flatMap { $0.1.map { $0.0.count } }
            .max() ?? 0
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
        entries: [(String, String)],
        maxWidth: Int
    ) {
        print("")
        print(title)
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
