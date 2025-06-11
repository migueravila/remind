import ArgumentParser
import Foundation

struct ReminderCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "reminder",
    abstract: "Manage reminders",
    subcommands: [ShowRemindersCommand.self, CreateReminderCommand.self]
  )
}

struct ShowRemindersCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "show",
    abstract: "Show reminders"
  )

  @Option(name: .shortAndLong, help: "List name to filter reminders")
  var list: String?

  func run() async throws {
    let cli = RemindCLI()
    try await cli.initialize()
    let reminders = try await cli.getReminders(from: list)

    OutputUtils.printTable(
      reminders,
      headers: ["Title", "List", "Due Date", "Priority", "Status"],
      valueExtractor: { reminder in
        [
          reminder.title,
          reminder.listName ?? "Unknown",
          reminder.dueDate.map(DateUtils.formatDate) ?? "No date",
          reminder.priority.displayName,
          reminder.isCompleted ? "✅" : "⏳",
        ]
      }
    )
  }
}

struct CreateReminderCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "create",
    abstract: "Create a new reminder"
  )

  @Argument(help: "Title of the reminder")
  var title: String

  @Option(name: .shortAndLong, help: "List name")
  var list: String

  @Option(name: .shortAndLong, help: "Notes for the reminder")
  var notes: String?

  @Option(name: .shortAndLong, help: "Due date (YYYY-MM-DD or MM/DD/YYYY)")
  var dueDate: String?

  @Option(name: .shortAndLong, help: "Priority (none, low, medium, high)")
  var priority: String = "none"

  func run() async throws {
    let cli = RemindCLI()
    try await cli.initialize()

    let priorityValue =
      ReminderItem.Priority.allCases.first {
        $0.displayName.lowercased() == priority.lowercased()
      } ?? .none

    let parsedDate = dueDate.flatMap(DateUtils.parseDate)

    let reminder = ReminderItem(
      id: nil,
      title: title,
      notes: notes,
      isCompleted: false,
      priority: priorityValue,
      dueDate: parsedDate,
      listName: list
    )

    try await cli.createReminder(reminder, in: list)
    OutputUtils.printSuccess("Created reminder: \(title)")
  }
}
