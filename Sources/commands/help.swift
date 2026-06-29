import ArgumentParser
import Foundation

public struct HelpCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "help",
        abstract: "Show help"
    )

    public init() {}

    public func run() throws {
        HelpRenderer.render()
    }
}

public enum HelpRenderer {
    public static let version = "1.0.0"

    private static let banner = """
           ▘   ▌
    ▛▘█▌▛▛▌▌▛▌▛▌
    ▌ ▙▖▌▌▌▌▌▌▙▌
    """

    private static let subtitle =
        "Apple Reminders for terminal natives  v\(version)"

    private struct Section {
        let title: String
        let rows: [(String, String)]
        let flags: [(String, String)]

        init(
            _ title: String,
            rows: [(String, String)] = [],
            flags: [(String, String)] = []
        ) {
            self.title = title
            self.rows = rows
            self.flags = flags
        }
    }

    private static let sections: [Section] = [
        Section("USAGE", rows: [
            ("remind [list|filter] [command] [args] [flags]", ""),
        ]),
        Section(
            "FILTERS",
            rows: [
                ("remind", "Show today's reminders (default)"),
                ("remind today", "Show today's reminders"),
                ("remind tomorrow", "Show tomorrow's reminders"),
                ("remind upcoming", "Show upcoming reminders"),
                ("remind all", "Show every active reminder"),
                ("remind <DD-MM-YY>", "Show reminders due on a date"),
            ],
            flags: [
                ("--done", "Show completed reminders for this filter"),
            ]
        ),
        Section(
            "LISTS",
            rows: [
                ("remind lists", "Show all reminder lists (alias: l)"),
                ("remind <list>", "Show reminders in a list"),
                ("remind rename <list> <name>", "Rename a list"),
                (
                    "remind archive <list>",
                    "Delete a list and all its reminders"
                ),
                ("remind clean <list>", "Delete every reminder in a list"),
                (
                    "remind purge [list]",
                    "Delete completed reminders (one list or all)"
                ),
            ],
            flags: [
                ("--done", "Show completed items in a list"),
                (
                    "-y, --force",
                    "Skip confirmation prompt (archive/clean/purge)"
                ),
            ]
        ),
        Section(
            "ADD A REMINDER",
            rows: [
                ("remind add \"<title>\"", "Add a reminder (alias: a)"),
                ("remind <list> add \"<title>\"", "Add to a specific list"),
                ("remind today add \"<title>\"", "Add due today"),
                ("remind tomorrow add \"<title>\"", "Add due tomorrow"),
                ("remind <DD-MM-YY> add \"<title>\"", "Add due on a date"),
                ("remind add", "Add interactively (prompts for fields)"),
            ],
            flags: [
                ("-l, --list <name>", "Target list"),
                (
                    "-d, --due <date>",
                    "Due date (DD-MM-YY, today, tomorrow, yesterday)"
                ),
                (
                    "-p, --priority <level>",
                    "Priority (none, low, medium, high)"
                ),
                ("-n, --notes <text>", "Attach notes"),
            ]
        ),
        Section(
            "EDIT A REMINDER",
            rows: [
                (
                    "remind edit <id>",
                    "Edit a reminder (no flags = interactive)"
                ),
                ("remind <list> edit <id>", "Edit, scoping IDs to a list"),
                ("remind today edit <id>", "Edit, scoping IDs to a filter"),
            ],
            flags: [
                ("-l, --list <name>", "Scope ID resolution to a list"),
                ("--filter <name>", "Scope ID resolution to a filter"),
                ("-t, --title <text>", "New title"),
                ("-d, --due <date>", "New due date"),
                ("-p, --priority <level>", "New priority"),
                ("-n, --notes <text>", "New notes"),
            ]
        ),
        Section(
            "COMPLETE REMINDERS",
            rows: [
                ("remind done <id...>", "Mark reminders complete"),
                (
                    "remind <list> done <id...>",
                    "Complete, scoping IDs to a list"
                ),
                (
                    "remind today done <id...>",
                    "Complete, scoping IDs to a filter"
                ),
            ],
            flags: [
                ("-l, --list <name>", "Scope ID resolution to a list"),
                ("--filter <name>", "Scope ID resolution to a filter"),
            ]
        ),
        Section(
            "DELETE REMINDERS",
            rows: [
                ("remind delete <id...>", "Delete reminders (aliases: d, rm)"),
                (
                    "remind <list> delete <id...>",
                    "Delete, scoping IDs to a list"
                ),
                (
                    "remind today delete <id...>",
                    "Delete, scoping IDs to a filter"
                ),
            ],
            flags: [
                ("-l, --list <name>", "Scope ID resolution to a list"),
                ("--filter <name>", "Scope ID resolution to a filter"),
                ("-y, --force", "Skip confirmation prompt"),
            ]
        ),
        Section("OUTPUT FLAGS", flags: [
            ("--json", "Output as JSON"),
            ("--plain", "Plain text without colors"),
            ("--quiet", "Minimal output (count only)"),
        ]),
        Section("MISC", rows: [
            ("remind help", "Show this help screen"),
            ("remind --version, -v", "Show version"),
        ]),
    ]

    private static let rowIndent = "  "
    private static let flagIndent = "    "
    private static let columnGap = "  "

    public static func render() {
        let descriptionColumn = computeDescriptionColumn()
        printBanner()
        for section in sections {
            renderSection(section, descriptionColumn: descriptionColumn)
        }
    }

    private static func computeDescriptionColumn() -> Int {
        var maxLeft = 0
        for section in sections {
            for (invocation, description) in section.rows
                where !description.isEmpty
            {
                maxLeft = max(maxLeft, rowIndent.count + invocation.count)
            }
            for (flag, description) in section.flags
                where !description.isEmpty
            {
                maxLeft = max(maxLeft, flagIndent.count + flag.count)
            }
        }
        return maxLeft
    }

    private static func printBanner() {
        print(banner)
        print(subtitle)
    }

    private static func renderSection(
        _ section: Section,
        descriptionColumn: Int
    ) {
        print("")
        print(section.title)

        for (invocation, description) in section.rows {
            if description.isEmpty {
                print("\(rowIndent)\(invocation)")
            } else {
                let used = rowIndent.count + invocation.count
                let pad = String(
                    repeating: " ",
                    count: descriptionColumn - used
                )
                print(
                    "\(rowIndent)\(invocation)\(pad)\(columnGap)\(description)"
                )
            }
        }

        guard !section.flags.isEmpty else { return }
        if !section.rows.isEmpty {
            print("")
            print("\(rowIndent)Flags:")
        }

        for (flag, description) in section.flags {
            let indent = section.rows.isEmpty ? rowIndent : flagIndent
            let used = indent.count + flag.count
            let pad = String(
                repeating: " ",
                count: descriptionColumn - used
            )
            print("\(indent)\(flag)\(pad)\(columnGap)\(description)")
        }
    }
}
