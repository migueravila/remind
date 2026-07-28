import ArgumentParser
import core
import Foundation

public struct QuickCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "quick",
        abstract: "Add a reminder in one line",
        aliases: ["q"]
    )

    @Argument(help: "Reminder title")
    public var title: String

    @Argument(
        parsing: .remaining,
        help: "@list, priority (!, !!, !!!) and date (today, tomorrow, weekend, YYYY-MM-DD)"
    )
    public var tokens: [String] = []

    public init() {}

    public func run() async throws {
        var listName: String?
        var priority: Reminder.Priority = .none
        var dueDate: Date?

        for token in tokens {
            if token.hasPrefix("@"), token.count > 1 {
                listName = String(token.dropFirst())
            } else if token.allSatisfy({ $0 == "!" }) {
                guard let parsed = parseBangPriority(token) else {
                    OutputUtils.printError(
                        "Invalid priority '\(token)'. Use ! (low), !! (medium) or !!! (high)"
                    )
                    return
                }
                priority = parsed
            } else if let date = parseQuickDate(token) {
                dueDate = date
            } else {
                OutputUtils.printError(
                    "Unrecognized argument '\(token)'. Expected @list, !, !!, !!! or a date (today, tomorrow, weekend, YYYY-MM-DD)"
                )
                return
            }
        }

        let manager = Manager()
        try await manager.requestAccess()

        guard let targetList = try await resolveList(
            manager: manager,
            explicit: listName
        ) else {
            OutputUtils.printError("No list selected")
            return
        }

        let reminder = Reminder(
            id: nil,
            title: title,
            notes: nil,
            isCompleted: false,
            priority: priority,
            dueDate: dueDate,
            listName: targetList
        )

        try await manager.createReminder(reminder, in: targetList)
        OutputUtils.printSuccess("Added reminder: \(title)")
    }

    private func parseBangPriority(_ token: String) -> Reminder.Priority? {
        switch token.count {
        case 1: .low
        case 2: .medium
        case 3: .high
        default: nil
        }
    }

    private func parseQuickDate(_ input: String) -> Date? {
        guard input.lowercased() == "weekend" else {
            return DateUtils.parseNaturalDate(input)
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if calendar.component(.weekday, from: today) == 7 {
            return today
        }
        return calendar.nextDate(
            after: today,
            matching: DateComponents(weekday: 7),
            matchingPolicy: .nextTime
        )
    }
}
