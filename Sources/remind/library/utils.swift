import Foundation

struct DateUtils {
    static func parseDate(_ dateString: String) -> Date? {
        let formatters = ["yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy", "yyyy-MM-dd HH:mm", "MM/dd/yyyy HH:mm"]

        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) { return date }
        }

        return nil
    }

    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct OutputUtils {
    static func printTable<T>(_ items: [T], headers: [String], valueExtractor: (T) -> [String]) {
        guard !items.isEmpty else {
            print("No items to display")
            return
        }

        let rows = items.map(valueExtractor)
        let allRows = [headers] + rows

        let columnWidths = (0..<headers.count).map { columnIndex in allRows.map { $0[columnIndex].count }.max() ?? 0 }

        for (index, row) in allRows.enumerated() {
            let formattedRow = zip(row, columnWidths).map { value, width in
                value.padding(toLength: width, withPad: " ", startingAt: 0)
            }.joined(separator: " | ")

            print(formattedRow)

            if index == 0 {
                let separator = columnWidths.map { String(repeating: "-", count: $0) }.joined(separator: "-|-")
                print(separator)
            }
        }
    }

    static func printSuccess(_ message: String) { print("✅ \(message)") }

    static func printError(_ message: String) { print("❌ \(message)") }

    static func printInfo(_ message: String) { print("ℹ️  \(message)") }
}
