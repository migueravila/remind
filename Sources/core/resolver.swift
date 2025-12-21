import Foundation

public enum IDResolver {
    public static func resolveIDs(_ inputs: [String], from reminders: [Reminder]) -> [String] {
        var resolvedIDs: [String] = []
        for input in inputs {
            if let id = resolveID(input, from: reminders) {
                resolvedIDs.append(id)
            }
        }
        return resolvedIDs
    }

    private static func resolveID(_ input: String, from reminders: [Reminder]) -> String? {
        if let index = Int(input), index > 0, index <= reminders.count {
            let sortedReminders = OutputUtils.sortReminders(reminders)
            return sortedReminders[index - 1].id
        }

        if let reminder = reminders.first(where: { $0.id == input }) {
            return reminder.id
        }

        if input.count >= Constants.minPrefixLength {
            let matches = reminders.filter { reminder in
                reminder.id?.lowercased().hasPrefix(input.lowercased()) ?? false
            }

            if matches.count == 1 {
                return matches.first?.id
            } else if matches.count > 1 {
                print("Ambiguous ID '\(input)' matches multiple reminders:")
                for match in matches.prefix(Constants.maxAmbiguousMatches) {
                    print("  - \(match.id?.prefix(8) ?? "Unknown"): \(match.title)")
                }
                return nil
            }
        }

        return nil
    }
}
