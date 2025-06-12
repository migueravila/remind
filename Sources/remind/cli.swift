import Foundation

class RemindCLI {
    private let reminderService = ReminderService()

    func initialize() async throws { try await reminderService.requestAccess() }

    func getAllLists() async throws -> [ReminderList] {
        return try await reminderService.getAllLists()
    }

    func createList(name: String) async throws -> ReminderList {
        return try await reminderService.createList(name: name)
    }
    func deleteList(name: String) async throws {
        try await reminderService.deleteList(name: name)
    }
    func renameList(oldName: String, newName: String) async throws {
        try await reminderService.renameList(oldName: oldName, newName: newName)
    }

    func completeReminders(ids: [String]) async throws {
        try await reminderService.completeReminders(ids: ids)
    }

    func deleteReminders(ids: [String]) async throws {
        try await reminderService.deleteReminders(ids: ids)
    }

    func findReminderById(_ id: String) async throws -> ReminderItem? {
        return try await reminderService.findReminderById(id)
    }

    func getReminders(
        from listName: String? = nil
    ) async throws -> [ReminderItem] {
        return try await reminderService.getReminders(from: listName)
    }
    func getReminders(filter: TimeFilter) async throws -> [ReminderItem] {
        return try await reminderService.getReminders(filter: filter)
    }

    func createReminder(
        _ reminder: ReminderItem, in listName: String
    ) async throws {
        try await reminderService.createReminder(reminder, in: listName)
    }
}
