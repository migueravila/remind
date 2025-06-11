import ArgumentParser

@main struct Remind: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remind",
        abstract: "A CLI tool for managing Apple Reminders", version: "1.0.0",
        subcommands: [
            ShowCommand.self, ListCommand.self, ShowListsCommand.self
        ], defaultSubcommand: ShowCommand.self)
}
