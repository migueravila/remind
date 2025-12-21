import ArgumentParser
import core

@main struct Remind: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remind",
        abstract: "Apple Reminders for terminal natives",
        version: "1.0.0",
        subcommands: [
            ShowCommand.self,
            ListCommand.self,
            AddReminderCommand.self,
            EditReminderCommand.self,
            CompleteReminderCommand.self,
            DeleteReminderCommand.self,
        ],
        defaultSubcommand: ShowCommand.self
    )
}
