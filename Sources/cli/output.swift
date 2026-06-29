import ArgumentParser
import core
import Foundation

public struct OutputOptions: ParsableArguments {
    @Flag(name: .long, help: "Output as JSON")
    public var json: Bool = false

    @Flag(name: .long, help: "Plain text without colors")
    public var plain: Bool = false

    @Flag(name: .long, help: "Minimal output (count only)")
    public var quiet: Bool = false

    public var format: OutputFormat {
        if json { return .json }
        if plain { return .plain }
        if quiet { return .quiet }
        return .standard
    }

    public init() {}
}
