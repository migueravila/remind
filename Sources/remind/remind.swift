import ArgumentParser

@main struct Remind: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remind",
        abstract: "Apple Reminders for terminal natives",
        version: "1.0.0",
        subcommands: [
            ShowCommand.self,
            ListCommand.self,
            ShowListsCommand.self,
            AddReminderCommand.self,
            CompleteReminderCommand.self,
            DeleteReminderCommand.self,
        ],
        defaultSubcommand: ShowCommand.self,
    )
}
