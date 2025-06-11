import ArgumentParser
import Foundation

@main struct Remind: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remind",
        abstract: "A CLI tool for managing Apple Reminders", version: "1.0.0",
        subcommands: [ListCommand.self, ReminderCommand.self])
    @Argument(
        parsing: .remaining,
        help:
            "Time filter (today, tomorrow, week, overdue, upcoming, inbox, flag, or DD-MM-YY)"
    ) var timeFilter: [String] = []
    func run() async throws {
        let cli = RemindCLI()
        try await cli.initialize()
        let filter = parseTimeFilter(timeFilter)
        let reminders = try await cli.getReminders(filter: filter)
        OutputUtils.printReminders(reminders)
    }
    private func parseTimeFilter(_ args: [String]) -> TimeFilter {
        guard let firstArg = args.first else { return .today }
        let arg = firstArg.lowercased()
        switch arg {
        case "inbox": return .inbox
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
}
