import Foundation

enum KeyInput {
    case up, down, left, right, enter, escape, backspace, character(Character), unknown

    static func readKey() -> KeyInput {
        var buffer = [UInt8](repeating: 0, count: Constants.bufferSize)
        let bytesRead = read(STDIN_FILENO, &buffer, Constants.bufferSize)

        guard bytesRead > 0 else { return .unknown }

        if bytesRead == 1 {
            switch buffer[0] {
            case 13, 10: return .enter
            case 27: return .escape
            case 127, 8: return .backspace
            case let char where char >= 32 && char <= 126:
                return .character(Character(UnicodeScalar(char)))
            default: return .unknown
            }
        } else if bytesRead == 3 && buffer[0] == 27 && buffer[1] == 91 {
            switch buffer[2] {
            case 65: return .up
            case 66: return .down
            case 67: return .right
            case 68: return .left
            default: return .unknown
            }
        }
        return .unknown
    }
}

public enum InputUtils {
    public static func select<T>(
        message: String,
        options: [(String, T)],
        defaultIndex: Int = 0,
        interactive: Bool = true
    ) -> T? {
        guard !options.isEmpty else { return nil }

        if !interactive || !isTerminalInteractive() {
            return selectSimple(
                message: message,
                options: options,
                defaultIndex: defaultIndex
            )
        }

        return selectInteractive(
            message: message,
            options: options,
            defaultIndex: defaultIndex
        )
    }

    public static func input(
        message: String,
        defaultValue: String? = nil,
        required: Bool = false
    ) -> String? {
        let hint = if let defaultValue = defaultValue {
            " (\(defaultValue))"
        } else if required {
            " (required)"
        } else {
            ""
        }

        print("\(Constants.promptIcon) \(message)\(hint): ", terminator: "")

        guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return handleEmptyInput(message: message, defaultValue: defaultValue)
        }

        if input.isEmpty {
            if required, defaultValue == nil {
                OutputUtils.printError("This field is required.")
                return self.input(message: message, defaultValue: defaultValue, required: required)
            }
            return handleEmptyInput(message: message, defaultValue: defaultValue)
        }

        showSuccessfulInput(message: message, value: input)
        return input
    }

    public static func confirm(message: String, defaultValue: Bool = false) -> Bool {
        let defaultText = defaultValue ? "Y/n" : "y/N"
        print("\(Constants.promptIcon) \(message) (\(defaultText)): ", terminator: "")

        guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else {
            return handleConfirmDefault(message: message, defaultValue: defaultValue)
        }

        if input.isEmpty {
            return handleConfirmDefault(message: message, defaultValue: defaultValue)
        }

        let result = input.starts(with: "y")
        let resultText = result ? "yes" : "no"
        Terminal.clearPreviousLine()
        print("\(OutputUtils.green(Constants.successIcon)) \(message): \(OutputUtils.dim(resultText))")
        return result
    }

    public static func datePicker(
        message: String,
        initialDate: Date = Date(),
        interactive: Bool = true
    ) -> Date? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: initialDate)

        if !interactive || !isTerminalInteractive() {
            return datePickerSimple(message: message, initialDate: startOfDay)
        }

        return datePickerInteractive(message: message, initialDate: startOfDay)
    }

    private static func isTerminalInteractive() -> Bool {
        return isatty(STDIN_FILENO) == 1 && isatty(STDOUT_FILENO) == 1
    }

    private static func handleEmptyInput(message: String, defaultValue: String?) -> String? {
        if let defaultValue = defaultValue, !defaultValue.isEmpty {
            Terminal.clearPreviousLine()
            print("\(OutputUtils.green(Constants.successIcon)) \(message): \(OutputUtils.dim(defaultValue))")
            return defaultValue
        }
        Terminal.clearPreviousLine()
        return nil
    }

    private static func showSuccessfulInput(message: String, value: String) {
        Terminal.clearPreviousLine()
        print("\(OutputUtils.green(Constants.successIcon)) \(message): \(OutputUtils.dim(value))")
    }

    private static func handleConfirmDefault(message: String, defaultValue: Bool) -> Bool {
        let result = defaultValue ? "yes" : "no"
        Terminal.clearPreviousLine()
        print("\(OutputUtils.green(Constants.successIcon)) \(message): \(OutputUtils.dim(result))")
        return defaultValue
    }

    private static func selectSimple<T>(
        message: String,
        options: [(String, T)],
        defaultIndex: Int
    ) -> T? {
        print(message)
        for (index, option) in options.enumerated() {
            let marker = index == defaultIndex ? ">" : " "
            print("  \(marker) \(option.0)")
        }

        let defaultOption = options[defaultIndex].0
        print("\nSelect option [\(defaultOption)]: ", terminator: "")

        guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return options[defaultIndex].1
        }

        if input.isEmpty { return options[defaultIndex].1 }

        if let matchedOption = options.first(where: {
            $0.0.lowercased() == input.lowercased()
        }) {
            return matchedOption.1
        }

        if let selection = Int(input), selection >= 1, selection <= options.count {
            return options[selection - 1].1
        }

        print("Invalid selection. Using default: \(defaultOption)")
        return options[defaultIndex].1
    }

    private static func selectInteractive<T>(
        message: String,
        options: [(String, T)],
        defaultIndex: Int
    ) -> T? {
        var selectedIndex = defaultIndex
        var searchQuery = ""
        var filteredOptions = options
        var lastRenderedLines = 0

        Terminal.enableRawMode()
        Terminal.hideCursor()
        defer {
            Terminal.disableRawMode()
            Terminal.showCursor()
        }

        func updateFilteredOptions() {
            if searchQuery.isEmpty {
                filteredOptions = options
            } else {
                filteredOptions = options.filter { option in
                    option.0.lowercased().contains(searchQuery.lowercased())
                }
            }
            selectedIndex = min(selectedIndex, max(0, filteredOptions.count - 1))
        }

        func render() {
            clearRenderedLines(lastRenderedLines)
            var lineCount = 0

            if searchQuery.isEmpty {
                print("\(Constants.promptIcon) \(message)")
            } else {
                print("\(Constants.promptIcon) \(message) \(OutputUtils.green(searchQuery))")
            }
            lineCount += 1

            if filteredOptions.isEmpty && !searchQuery.isEmpty {
                print("  No matches found")
                lineCount += 1
            } else {
                for (index, option) in filteredOptions.enumerated() {
                    let marker = index == selectedIndex ? "› " : "  "
                    let style = index == selectedIndex
                        ? OutputUtils.green(option.0)
                        : option.0
                    print("\(marker)\(style)")
                    lineCount += 1
                }
            }

            print(OutputUtils.dim(
                "Type to search, arrows to navigate, Enter to select, Esc to cancel"
            ))
            lineCount += 1

            lastRenderedLines = lineCount
        }

        func clearRenderedLines(_ lines: Int) {
            if lines > 0 {
                for _ in 0..<lines {
                    Terminal.moveCursor(up: 1)
                    Terminal.clearLine()
                }
            }
        }

        updateFilteredOptions()
        render()

        while true {
            let input = KeyInput.readKey()

            switch input {
            case .up:
                if !filteredOptions.isEmpty {
                    selectedIndex = max(0, selectedIndex - 1)
                    render()
                }
            case .down:
                if !filteredOptions.isEmpty {
                    selectedIndex = min(filteredOptions.count - 1, selectedIndex + 1)
                    render()
                }
            case .enter:
                guard !filteredOptions.isEmpty else { continue }
                clearRenderedLines(lastRenderedLines)
                print(
                    "\(OutputUtils.green(Constants.successIcon)) \(message): " +
                    "\(OutputUtils.dim(filteredOptions[selectedIndex].0))"
                )
                return filteredOptions[selectedIndex].1
            case .escape:
                clearRenderedLines(lastRenderedLines)
                return nil
            case .backspace:
                if !searchQuery.isEmpty {
                    searchQuery.removeLast()
                    updateFilteredOptions()
                    render()
                }
            case let .character(char):
                searchQuery.append(char)
                updateFilteredOptions()
                render()
            default:
                break
            }
        }
    }

    private static func datePickerSimple(message: String, initialDate: Date) -> Date? {
        print("\(message)")
        print("Enter date (YYYY-MM-DD) or 'today', 'tomorrow': ", terminator: "")

        guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }

        if input.isEmpty { return initialDate }

        if let parsedDate = DateUtils.parseNaturalDate(input) {
            return Calendar.current.startOfDay(for: parsedDate)
        }

        return initialDate
    }

    private static func datePickerInteractive(message: String, initialDate: Date) -> Date? {
        var selectedDate = initialDate
        var lastRenderedLines = 0

        Terminal.enableRawMode()
        Terminal.hideCursor()
        defer {
            Terminal.disableRawMode()
            Terminal.showCursor()
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none

        func render() {
            if lastRenderedLines > 0 {
                for _ in 0..<lastRenderedLines {
                    Terminal.moveCursor(up: 1)
                    Terminal.clearLine()
                }
            }

            var lineCount = 0

            print("\(Constants.promptIcon) \(message)")
            lineCount += 1

            print("> \(OutputUtils.cyan(formatter.string(from: selectedDate)))")
            lineCount += 1

            print(OutputUtils.dim(
                "Use arrows for days/weeks, Enter to select, Esc to cancel"
            ))
            lineCount += 1

            lastRenderedLines = lineCount
        }

        render()

        while true {
            let input = KeyInput.readKey()

            switch input {
            case .up:
                selectedDate = Calendar.current.date(
                    byAdding: .day,
                    value: 1,
                    to: selectedDate
                ) ?? selectedDate
                render()
            case .down:
                selectedDate = Calendar.current.date(
                    byAdding: .day,
                    value: -1,
                    to: selectedDate
                ) ?? selectedDate
                render()
            case .right:
                selectedDate = Calendar.current.date(
                    byAdding: .weekOfYear,
                    value: 1,
                    to: selectedDate
                ) ?? selectedDate
                render()
            case .left:
                selectedDate = Calendar.current.date(
                    byAdding: .weekOfYear,
                    value: -1,
                    to: selectedDate
                ) ?? selectedDate
                render()
            case .enter:
                for _ in 0..<lastRenderedLines {
                    Terminal.moveCursor(up: 1)
                    Terminal.clearLine()
                }

                print(
                    "\(OutputUtils.green(Constants.successIcon)) \(message): " +
                    "\(OutputUtils.dim(formatter.string(from: selectedDate)))"
                )
                return selectedDate
            case .escape:
                for _ in 0..<lastRenderedLines {
                    Terminal.moveCursor(up: 1)
                    Terminal.clearLine()
                }
                return nil
            default:
                break
            }
        }
    }
}
