import Foundation
import Combine

/// Owns the presentation session; persistence stays in the existing feature models.
@MainActor
final class LoggingFlowViewModel: ObservableObject {
    enum Destination: String, Identifiable {
        case search, scan, manual
        var id: String { rawValue }
    }

    @Published var destination: Destination?
    @Published private(set) var receipt: ReceiptPayload?
    @Published private(set) var isUndoing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var revision = 0
    private var session = UUID()

    func completed(_ payload: ReceiptPayload) {
        destination = nil
        receipt = payload
        errorMessage = nil
        revision += 1
    }

    func savedMealCompleted() {
        destination = nil
        dismissReceipt()
        revision += 1
    }

    func dismissReceipt() { receipt = nil; errorMessage = nil }

    func reset() {
        session = UUID()
        destination = nil
        dismissReceipt()
        isUndoing = false
    }

    func undo(owner: UUID?, operation: @MainActor (ReceiptPayload) async -> Bool) async {
        guard !isUndoing, let receipt, let owner,
              receipt.ownerID == nil || receipt.ownerID == owner else { return }
        let request = session
        isUndoing = true
        let succeeded = await operation(receipt)
        guard request == session else { return }
        isUndoing = false
        guard self.receipt?.id == receipt.id else { return }
        if succeeded {
            dismissReceipt()
            revision += 1
        } else {
            errorMessage = "Kunne ikke angre. Prøv igjen."
        }
    }
}
