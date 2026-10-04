import OSLog

/// Available in optimized Profile builds as well as Debug. Names and operation
/// labels must be static code identifiers; never attach user or domain data.
nonisolated enum PerformanceSignposts {
    private static let signposter = OSSignposter(
        subsystem: "com.nithusan.MatLogg", category: "Performance"
    )

    struct Interval: Sendable {
        fileprivate let name: StaticString
        fileprivate let state: OSSignpostIntervalState
    }

    static func begin(_ name: StaticString, operation: StaticString = #function) -> Interval {
        let state = signposter.beginInterval(
            name, id: signposter.makeSignpostID(), "operation=\(operation, privacy: .public)"
        )
        return Interval(name: name, state: state)
    }

    static func event(_ name: StaticString) {
        signposter.emitEvent(name, id: signposter.makeSignpostID())
    }

    static func end(_ interval: Interval) {
        signposter.endInterval(interval.name, interval.state)
    }

    static func measure<Value>(_ name: StaticString, _ work: () throws -> Value) rethrows -> Value {
        let interval = begin(name)
        defer { end(interval) }
        return try work()
    }
}
