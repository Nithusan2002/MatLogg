import Foundation

/// Owned by a ViewModel; short operations never publish visible activity.
@MainActor
final class DelayedActivity {
    private var task: Task<Void, Never>?

    func update(isActive: Bool, publish: @escaping @MainActor (Bool) -> Void) {
        task?.cancel()
        task = nil
        publish(false)
        guard isActive else { return }
        task = Task {
            do { try await Task.sleep(for: .milliseconds(180)) }
            catch { return }
            guard !Task.isCancelled else { return }
            publish(true)
        }
    }

    deinit { task?.cancel() }
}
