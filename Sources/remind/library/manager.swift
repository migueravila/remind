import EventKit
import Foundation

class Manager {
    private let eventStore = EKEventStore()

    func requestAccess() async throws {
        let authStatus = EKEventStore.authorizationStatus(for: .reminder)

        switch authStatus {
        case .notDetermined:
            let granted = try await eventStore.requestAccess(to: .reminder)
            if !granted { throw ProgramError.accessDenied }
        case .denied, .restricted: throw ProgramError.accessDenied
        case .authorized, .fullAccess, .writeOnly: break
        @unknown default: throw ProgramError.unknownAuthorizationStatus
        }
    }

    func getAllLists() async throws -> [ReminderList] {
        let calendars = eventStore.calendars(for: .reminder)
        var lists: [ReminderList] = []

        for calendar in calendars {
            let reminderCount = await getRemindersCount(for: calendar)
            lists.append(
                ReminderList(
                    id: calendar.calendarIdentifier, title: calendar.title,
                    color: calendar.cgColor?.components?.description,
                    reminderCount: reminderCount
                )
            )
        }

        return lists
    }

    func createList(name: String) async throws -> ReminderList {
        let calendar = EKCalendar(for: .reminder, eventStore: eventStore)
        calendar.title = name
        calendar.source = eventStore.defaultCalendarForNewReminders()?.source

        try eventStore.saveCalendar(calendar, commit: true)

        return ReminderList(
            id: calendar.calendarIdentifier, title: calendar.title,
            reminderCount: 0
        )
    }

    func deleteList(name: String) async throws {
        let calendars = eventStore.calendars(for: .reminder).filter {
            $0.title == name
        }
        guard let calendar = calendars.first else {
            throw ProgramError.listNotFound
        }
        guard calendar.allowsContentModifications else {
            throw ProgramError.operationFailed("Cannot delete system calendar")
        }
        try eventStore.removeCalendar(calendar, commit: true)
    }

    func renameList(oldName: String, newName: String) async throws {
        let calendars = eventStore.calendars(for: .reminder).filter {
            $0.title == oldName
        }
        guard let calendar = calendars.first else {
            throw ProgramError.listNotFound
        }
        guard calendar.allowsContentModifications else {
            throw ProgramError.operationFailed("Cannot modify system calendar")
        }
        calendar.title = newName
        try eventStore.saveCalendar(calendar, commit: true)
    }

    func getReminders(from listName: String? = nil) async throws -> [Reminder] {
        let calendars: [EKCalendar]

        if let listName {
            calendars = eventStore.calendars(for: .reminder).filter {
                $0.title == listName
            }
            if calendars.isEmpty { throw ProgramError.listNotFound }
        } else {
            calendars = eventStore.calendars(for: .reminder)
        }

        return await withCheckedContinuation { continuation in
            let predicate = eventStore.predicateForReminders(in: calendars)

            eventStore.fetchReminders(matching: predicate) { ekReminders in
                let reminders = (ekReminders ?? []).map { ekReminder in
                    Reminder(
                        id: ekReminder.calendarItemIdentifier,
                        title: ekReminder.title ?? "", notes: ekReminder.notes,
                        isCompleted: ekReminder.isCompleted,
                        priority: Reminder
                            .Priority(rawValue: ekReminder.priority) ?? .none,
                        dueDate: ekReminder.dueDateComponents?.date,
                        listName: ekReminder.calendar.title
                    )
                }
                continuation.resume(returning: reminders)
            }
        }
    }

    func getReminders(filter: ShowOptions) async throws -> [Reminder] {
        let allReminders = try await getReminders(from: nil)
        let calendar = Calendar.current
        let now = Date()

        switch filter {
        case .today:
            return allReminders.filter { reminder in
                !reminder.isCompleted
                    &&
                    (reminder.dueDate
                        .map { calendar.isDateInToday($0) } ?? false
                        || reminder.dueDate
                        .map { $0 < calendar.startOfDay(for: now) } ??
                        false)
            }
        case .tomorrow:
            return allReminders.filter { reminder in
                !reminder.isCompleted
                    && reminder.dueDate
                    .map { calendar.isDateInTomorrow($0) } ?? false
            }
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?
                .start ?? now
            let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?
                .end ?? now
            return allReminders.filter { reminder in
                !reminder.isCompleted
                    && reminder.dueDate.map { dueDate in
                        dueDate >= startOfWeek && dueDate <= endOfWeek
                    } ?? false
            }
        case .overdue:
            return allReminders.filter { reminder in
                !reminder.isCompleted
                    && reminder.dueDate
                    .map { $0 < calendar.startOfDay(for: now) } ?? false
            }
        case .flagged:
            return allReminders.filter { reminder in
                !reminder.isCompleted && reminder.priority != .none
            }
        case .upcoming:
            return allReminders.filter { !$0.isCompleted && $0.dueDate != nil }
                .sorted {
                    ($0.dueDate ?? Date.distantFuture) <
                        ($1.dueDate ?? Date.distantFuture)
                }
        case let .specificDate(date):
            return allReminders.filter { reminder in
                !reminder.isCompleted
                    && reminder.dueDate.map { calendar.isDate(
                        $0,
                        inSameDayAs: date
                    ) } ?? false
            }
        }
    }

    func createReminder(_ reminder: Reminder,
                        in listName: String) async throws
    {
        let calendars = eventStore.calendars(for: .reminder).filter {
            $0.title == listName
        }
        guard let calendar = calendars.first else {
            throw ProgramError.listNotFound
        }

        let ekReminder = EKReminder(eventStore: eventStore)
        ekReminder.title = reminder.title
        ekReminder.notes = reminder.notes
        ekReminder.calendar = calendar
        ekReminder.priority = reminder.priority.rawValue

        if let dueDate = reminder.dueDate {
            ekReminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: dueDate
            )
        }

        try eventStore.save(ekReminder, commit: true)
    }

    func completeReminders(ids: [String]) async throws {
        let allCalendars = eventStore.calendars(for: .reminder)
        let predicate = eventStore.predicateForReminders(in: allCalendars)

        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { ekReminders in
                guard let reminders = ekReminders else {
                    continuation.resume()
                    return
                }

                for reminder in reminders
                    where ids.contains(reminder.calendarItemIdentifier)
                {
                    reminder.isCompleted = true
                    do {
                        try self.eventStore.save(reminder, commit: false)
                    } catch {
                        print(
                            "Failed to complete reminder: \(reminder.title ?? "Unknown")"
                        )
                    }
                }

                do { try self.eventStore.commit() } catch {
                    print("Failed to save changes")
                }
                continuation.resume()
            }
        }
    }

    func deleteReminders(ids: [String]) async throws {
        let allCalendars = eventStore.calendars(for: .reminder)
        let predicate = eventStore.predicateForReminders(in: allCalendars)

        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { ekReminders in
                guard let reminders = ekReminders else {
                    continuation.resume()
                    return
                }

                for reminder in reminders
                    where ids.contains(reminder.calendarItemIdentifier)
                {
                    do {
                        try self.eventStore.remove(reminder, commit: false)
                    } catch {
                        print(
                            "Failed to delete reminder: \(reminder.title ?? "Unknown")"
                        )
                    }
                }

                do { try self.eventStore.commit() } catch {
                    print("Failed to save changes")
                }
                continuation.resume()
            }
        }
    }

    private func getRemindersCount(for calendar: EKCalendar) async -> Int {
        await withCheckedContinuation { continuation in
            let predicate = eventStore.predicateForReminders(in: [calendar])
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders?.count ?? 0)
            }
        }
    }
}
