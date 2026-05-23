import Foundation
import Yams

public struct Config: Codable, Sendable {
    public var defaultList: String?
    public var dateFormat: String?
    public var color: String?
    public var confirmDelete: Bool

    public init(
        defaultList: String? = nil,
        dateFormat: String? = nil,
        color: String? = nil,
        confirmDelete: Bool = true
    ) {
        self.defaultList = defaultList
        self.dateFormat = dateFormat
        self.color = color
        self.confirmDelete = confirmDelete
    }

    enum CodingKeys: String, CodingKey {
        case defaultList = "default_list"
        case dateFormat = "date_format"
        case color
        case confirmDelete = "confirm_delete"
    }

    public static func load() -> Config {
        var config = Config()

        if let fileConfig = loadFromFile() {
            config.merge(with: fileConfig)
        }

        config.applyEnvironmentOverrides()

        return config
    }

    private static func loadFromFile() -> Config? {
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/remind/config.yaml")

        guard FileManager.default.fileExists(atPath: configPath.path) else {
            return nil
        }

        guard let contents = try? String(contentsOf: configPath,
                                         encoding: .utf8)
        else {
            return nil
        }

        return try? YAMLDecoder().decode(Config.self, from: contents)
    }

    private mutating func merge(with other: Config) {
        if let value = other.defaultList { defaultList = value }
        if let value = other.dateFormat { dateFormat = value }
        if let value = other.color { color = value }
        confirmDelete = other.confirmDelete
    }

    private mutating func applyEnvironmentOverrides() {
        if let value = ProcessInfo.processInfo
            .environment["REMIND_DEFAULT_LIST"]
        {
            defaultList = value
        }
        if let value = ProcessInfo.processInfo
            .environment["REMIND_DATE_FORMAT"]
        {
            dateFormat = value
        }
        if let value = ProcessInfo.processInfo.environment["REMIND_COLOR"] {
            color = value
        }
    }

    public var shouldUseColors: Bool {
        switch color?.lowercased() {
        case "always": return true
        case "never": return false
        default: return isatty(STDOUT_FILENO) == 1
        }
    }
}

public enum ViewStateStore {
    private static var stateURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/remind/state.json")
    }

    public static func load() -> ViewState? {
        let url = stateURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ViewState.self, from: data)
    }

    public static func save(_ state: ViewState) {
        let url = stateURL
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: url, options: .atomic)
    }

    public static func clear() {
        let url = stateURL
        try? FileManager.default.removeItem(at: url)
    }
}
