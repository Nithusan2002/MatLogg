import Foundation

/// Explicit executor boundary for CPU work and synchronous file IO.
nonisolated enum BackgroundWork {
    static func run<Value: Sendable>(
        priority: TaskPriority = .userInitiated,
        _ operation: @escaping @Sendable () throws -> Value
    ) async throws -> Value {
        let task = Task.detached(priority: priority) {
            try Task.checkCancellation()
            return try operation()
        }
        return try await withTaskCancellationHandler {
            let value = try await task.value
            try Task.checkCancellation()
            return value
        } onCancel: {
            task.cancel()
        }
    }
}
