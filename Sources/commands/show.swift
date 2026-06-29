import ArgumentParser
import cli
import core
import Foundation

public struct ShowCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Show reminders based on filter or list",
        shouldDisplay: false
    )

    @Argument(
        parsing: .remaining,
        help: "Filter (today, tomorrow, upcoming, all, or DD-MM-YY)"
    )
    public var timeFilter: [String] = []

    @Option(name: .shortAndLong, help: "Show reminders from this list")
    public var list: String?

    @Flag(name: .long, help: "Show completed reminders")
    public var done: Bool = false

    @OptionGroup public var output: OutputOptions

    public init() {}

    public func run() async throws {
        let manager = Manager()
        try await manager.requestAccess()

        if let listName = list {
            try await runListView(
                manager: manager,
                listName: listName
            )
            return
        }

        let filter = parseTimeFilter(timeFilter)
        let reminders = try await manager.getReminders(
            filter: filter,
            showCompleted: done
        )
        let sorted = OutputUtils.sortReminders(reminders)
        OutputUtils.printReminders(reminders, format: output.format)
        persistFilterState(filter: filter, reminders: sorted)
    }

    private func runListView(
        manager: Manager,
        listName: String
    ) async throws {
        let lists = try await manager.getAllLists()
        let listExists = lists.contains { $0.title == listName }

        if !listExists {
            if ArgDispatcher.isReserved(listName) {
                OutputUtils.printError(
                    "'\(listName)' is a reserved name and cannot be used as a list name"
                )
                return
            }

            let ok = InputUtils.confirm(
                message: "List '\(listName)' doesn't exist. Create it?",
                defaultValue: false
            )
            guard ok else {
                OutputUtils.printInfo("Cancelled")
                return
            }

            let color = InputUtils.select(
                message: "Choose a color for '\(listName)'",
                options: ListColor.allCases.map { color in
                    (
                        "\(OutputUtils.swatch(for: color)) \(color.displayName)",
                        color
                    )
                }
            )

            let created = try await manager.createList(
                name: listName,
                color: color
            )
            OutputUtils.printSuccess("Created list: \(created.title)")
            return
        }

        let all = try await manager.getReminders(from: listName)
        let filtered = done
            ? all.filter(\.isCompleted)
            : all.filter { !$0.isCompleted }
        let sorted = OutputUtils.sortReminders(filtered)
        OutputUtils.printReminders(filtered, format: output.format)
        persistListState(listName: listName, reminders: sorted)
    }

    private func parseTimeFilter(_ args: [String]) -> ShowOptions {
        guard let firstArg = args.first else { return .today }
        let arg = firstArg.lowercased()

        switch arg {
        case "today": return .today
        case "tomorrow": return .tomorrow
        case "upcoming": return .upcoming
        case "all": return .all
        default:
            if let date = DateUtils.parseSpecificDate(firstArg) {
                return .specificDate(date)
            }
            return .today
        }
    }

    private func persistFilterState(
        filter: ShowOptions,
        reminders: [Reminder]
    ) {
        let spec: ViewSpec = .filter(viewFilter(from: filter))
        let ids = reminders.compactMap(\.id)
        ViewStateStore.save(ViewState(spec: spec, ids: ids))
    }

    private func persistListState(listName: String, reminders: [Reminder]) {
        let ids = reminders.compactMap(\.id)
        ViewStateStore.save(
            ViewState(spec: .list(name: listName), ids: ids)
        )
    }

    private func viewFilter(from filter: ShowOptions) -> ViewSpec.Filter {
        switch filter {
        case .today: .today
        case .tomorrow: .tomorrow
        case .upcoming: .upcoming
        case .all: .all
        case let .specificDate(date): .specificDate(date)
        }
    }
}
