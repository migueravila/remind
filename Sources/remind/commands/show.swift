import ArgumentParser
import Foundation

struct ShowCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show", abstract: "Show reminders based on time filters",
        shouldDisplay: false)
    @Argument(
        parsing: .remaining,
        help:
            "Time filter (today, tomorrow, week, overdue, upcoming, flag, or DD-MM-YY)"
    ) var timeFilter: [String] = []
    func run() async throws {
        let cli = RemindCLI()
        try await cli.initialize()
        let filter = parseTimeFilter(timeFilter)
        let reminders = try await cli.getReminders(filter: filter)
        let title = getTitleForFilter(filter)
        OutputUtils.printReminders(reminders, title: title)
    }
    private func parseTimeFilter(_ args: [String]) -> TimeFilter {
        guard let firstArg = args.first else { return .today }
        let arg = firstArg.lowercased()
        switch arg {
        case "tomorrow", "t": return .tomorrow
        case "week", "w": return .thisWeek
        case "overdue", "o": return .overdue
        case "flag", "f": return .flagged
        case "upcoming", "u": return .upcoming
        default:
            if let date = DateUtils.parseSpecificDate(firstArg) {
                return .specificDate(date)
            }
            return .today
        }
    }
    private func getTitleForFilter(_ filter: TimeFilter) -> String {
        switch filter {
        case .today: return "Today's Tasks"
        case .tomorrow: return "Tomorrow's Tasks"
        case .thisWeek: return "This Week's Tasks"
        case .overdue: return "Overdue Tasks"
        case .flagged: return "Flagged Tasks"
        case .upcoming: return "Upcoming Tasks"
        case .specificDate(let date):
            return "Tasks for \(DateUtils.formatDate(date))"
        }
    }
}
