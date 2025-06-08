import EventKit
import Foundation

class ReminderService {
    private let eventStore = EKEventStore()
    
    func requestAccess() async throws {
        let authStatus = EKEventStore.authorizationStatus(for: .reminder)
        
        switch authStatus {
        case .notDetermined:
            let granted = try await eventStore.requestAccess(to: .reminder)
            if !granted {
                throw RemindError.accessDenied
            }
        case .denied, .restricted:
            throw RemindError.accessDenied
        case .authorized, .fullAccess, .writeOnly:
            break
        @unknown default:
            throw RemindError.unknownAuthorizationStatus
        }
    }
    
    func getAllLists() async throws -> [ReminderList] {
        let calendars = eventStore.calendars(for: .reminder)
        var lists: [ReminderList] = []
        
        for calendar in calendars {
            let reminderCount = await getRemindersCount(for: calendar)
            lists.append(ReminderList(
                id: calendar.calendarIdentifier,
                title: calendar.title,
                color: calendar.cgColor?.components?.description,
                reminderCount: reminderCount
            ))
        }
        
        return lists
    }
    
    func createList(name: String) async throws -> ReminderList {
        let calendar = EKCalendar(for: .reminder, eventStore: eventStore)
        calendar.title = name
        calendar.source = eventStore.defaultCalendarForNewReminders()?.source
        
        try eventStore.saveCalendar(calendar, commit: true)
        
        return ReminderList(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            reminderCount: 0
        )
    }
    
    func getReminders(from listName: String? = nil) async throws -> [ReminderItem] {
        let calendars: [EKCalendar]
        
        if let listName = listName {
            calendars = eventStore.calendars(for: .reminder).filter { $0.title == listName }
            if calendars.isEmpty {
                throw RemindError.listNotFound
            }
        } else {
            calendars = eventStore.calendars(for: .reminder)
        }
        
        return await withCheckedContinuation { continuation in
            let predicate = eventStore.predicateForReminders(in: calendars)
            
            eventStore.fetchReminders(matching: predicate) { ekReminders in
                let reminders = (ekReminders ?? []).map { ekReminder in
                    ReminderItem(
                        id: ekReminder.calendarItemIdentifier,
                        title: ekReminder.title ?? "",
                        notes: ekReminder.notes,
                        isCompleted: ekReminder.isCompleted,
                        priority: ReminderItem.Priority(rawValue: ekReminder.priority) ?? .none,
                        dueDate: ekReminder.dueDateComponents?.date,
                        listName: ekReminder.calendar.title
                    )
                }
                continuation.resume(returning: reminders)
            }
        }
    }
    
    func createReminder(_ reminder: ReminderItem, in listName: String) async throws {
        let calendars = eventStore.calendars(for: .reminder).filter { $0.title == listName }
        guard let calendar = calendars.first else {
            throw RemindError.listNotFound
        }
        
        let ekReminder = EKReminder(eventStore: eventStore)
        ekReminder.title = reminder.title
        ekReminder.notes = reminder.notes
        ekReminder.calendar = calendar
        ekReminder.priority = reminder.priority.rawValue
        
        if let dueDate = reminder.dueDate {
            ekReminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        }
        
        try eventStore.save(ekReminder, commit: true)
    }
    
    private func getRemindersCount(for calendar: EKCalendar) async -> Int {
        return await withCheckedContinuation { continuation in
            let predicate = eventStore.predicateForReminders(in: [calendar])
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders?.count ?? 0)
            }
        }
    }
}

