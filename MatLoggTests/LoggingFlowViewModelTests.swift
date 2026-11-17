import Foundation
import Testing
@testable import MatLogg

@MainActor
struct LoggingFlowViewModelTests {
    private func receipt(owner: UUID = UUID()) -> ReceiptPayload {
        ReceiptPayload(product: Product(name: "Testvare", caloriesPer100g: 100,
            proteinGPer100g: 2, carbsGPer100g: 10, fatGPer100g: 4),
            amountG: 75, amountUnit: .grams, mealType: "lunsj",
            loggedDate: Date(timeIntervalSince1970: 1_700_000_000), logID: UUID(), ownerID: owner)
    }

    @Test func completionClosesOnlyDestinationAndPreservesExactReceipt() {
        let model = LoggingFlowViewModel()
        let payload = receipt()
        model.destination = .scan
        model.completed(payload)
        #expect(model.destination == nil)
        #expect(model.receipt?.logID == payload.logID)
        #expect(model.receipt?.loggedDate == payload.loggedDate)
        #expect(model.receipt?.mealType == "lunsj")
        #expect(model.revision == 1)
        let second = receipt()
        model.completed(second)
        #expect(model.receipt?.id == second.id)
        #expect(model.revision == 2)
    }

    @Test func undoUsesReceiptIdentityAndKeepsReceiptForRetryAfterFailure() async {
        let model = LoggingFlowViewModel()
        let payload = receipt()
        model.completed(payload)
        await model.undo(owner: payload.ownerID) { received in
            #expect(received.logID == payload.logID)
            #expect(received.loggedDate == payload.loggedDate)
            return false
        }
        #expect(model.receipt?.id == payload.id)
        #expect(model.errorMessage != nil)
        #expect(!model.isUndoing)
        await model.undo(owner: payload.ownerID) { _ in true }
        #expect(model.receipt == nil)
        #expect(model.errorMessage == nil)
        #expect(model.revision == 2)
    }

    @Test func otherOwnerCannotUndoAndResetDiscardsOldResult() async {
        let model = LoggingFlowViewModel()
        let payload = receipt()
        model.completed(payload)
        await model.undo(owner: UUID()) { _ in
            Issue.record("A different owner must not reach persistence")
            return true
        }
        #expect(model.receipt?.id == payload.id)
        let newPayload = receipt()
        await model.undo(owner: payload.ownerID) { _ in
            model.reset()
            model.completed(newPayload)
            return false
        }
        #expect(model.receipt?.id == newPayload.id)
        #expect(model.errorMessage == nil)
        #expect(!model.isUndoing)
    }

    @Test func earlierUndoDoesNotDismissNewerReceipt() async {
        let model = LoggingFlowViewModel()
        let first = receipt()
        let next = receipt()
        model.completed(first)
        await model.undo(owner: first.ownerID) { _ in
            model.completed(next)
            return true
        }
        #expect(model.receipt?.id == next.id)
        #expect(!model.isUndoing)
    }
}
