import Foundation

protocol FoodLoggingDraftRepository {
    func loadLoggingDraft(owner: UUID) async throws -> FoodLoggingDraft?
    func createLoggingDraft(_ draft: FoodLoggingDraft) async throws
    func updateLoggingDraft(_ draft: FoodLoggingDraft) async throws
    func discardLoggingDraft(id: UUID, owner: UUID) async throws
    func advanceLoggingDraft(_ draft: FoodLoggingDraft, product: Product) async throws
    func saveProductAndFinishDraft(_ draft: FoodLoggingDraft, product: Product) async throws
    func useExistingProduct(in draft: FoodLoggingDraft, product: Product) async throws
    func returnLoggingDraftToProduct(_ draft: FoodLoggingDraft) async throws
    func completeLoggingDraft(_ draft: FoodLoggingDraft, log: FoodLog) async throws
}

nonisolated enum LoggingDraftError: Error {
    case unavailable, conflict, invalidData
}
