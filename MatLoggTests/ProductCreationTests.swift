import Foundation
import Testing
import UIKit
@testable import MatLogg

@Suite(.serialized)
@MainActor
struct ProductCreationTests {
    @Test func parsesNorwegianDecimalsAndPreservesMilliliterBasis() async throws {
        let repository = ProductCreationRepositorySpy()
        let owner = UUID()
        let viewModel = makeViewModel(owner: owner, repository: repository)
        viewModel.draft.name = "Tomatsuppe"
        viewModel.draft.brand = "MatLogg Test"
        viewModel.draft.nutritionBasis = .per100ml
        viewModel.draft.calories = "42"
        viewModel.draft.protein = "1,5"
        viewModel.draft.carbohydrates = "6,25"
        viewModel.draft.fat = "1"

        let product = await viewModel.complete()

        #expect(product?.nutritionBasis == .per100ml)
        #expect(product?.proteinGPer100g == 1.5)
        #expect(product?.carbsGPer100g == 6.25)
        #expect(repository.completed.count == 1)
    }

    @Test func incompleteDraftCanPersistButCannotBecomeProduct() async {
        let repository = ProductCreationRepositorySpy()
        let viewModel = makeViewModel(owner: UUID(), repository: repository)
        viewModel.draft.name = "Uferdig vare"

        #expect(await viewModel.saveIncompleteDraft())
        #expect(repository.savedDrafts.count == 1)
        #expect(await viewModel.complete() == nil)
        #expect(repository.completed.isEmpty)
    }

    @Test func invalidNameAndMacroBoundsCannotBecomeProduct() async {
        let repository = ProductCreationRepositorySpy()
        let viewModel = makeViewModel(owner: UUID(), repository: repository)
        viewModel.draft.name = String(repeating: "a", count: CreateProductViewModel.maximumNameLength + 1)
        viewModel.draft.calories = "500"
        viewModel.draft.protein = "50"
        viewModel.draft.carbohydrates = "50"
        viewModel.draft.fat = "10"

        #expect(await viewModel.complete() == nil)
        #expect(repository.completed.isEmpty)
    }

    @Test func partialAIResultOnlyFillsDocumentedValuesAndRequiresConfirmation() async {
        let repository = ProductCreationRepositorySpy()
        let extraction = NutritionExtraction(
            basis: .per100g,
            energyKJ: field(nil), energyKcal: field(251), fat: field(4.2), saturatedFat: field(nil),
            carbohydrates: field(40), sugars: field(nil), fiber: field(nil), protein: field(9.1),
            salt: field(nil), sodium: field(nil)
        )
        let viewModel = CreateProductViewModel(
            ownerUserId: UUID(), repository: repository,
            imageStore: ProductImageStoreSpy(), ocrService: OCRServiceSpy(), aiService: AIServiceSpy(extraction: extraction),
            aiEnabled: { true }, contributionsEnabled: { false }
        )
        viewModel.draft.labelImagePath = "/private/test-label.jpg"

        await viewModel.requestAISuggestion()

        #expect(ProductDraft.number(viewModel.draft.calories) == 251)
        #expect(ProductDraft.number(viewModel.draft.protein) == 9.1)
        #expect(viewModel.draft.sugars.isEmpty)
        #expect(!viewModel.draft.aiFieldsConfirmed)
        viewModel.confirmAISuggestion()
        #expect(viewModel.draft.aiFieldsConfirmed)
    }

    @Test func draftCompletionIsAtomicWithProductEventAndDraftDeletion() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MatLoggProductDraft-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LocalStore(databaseURL: directory.appendingPathComponent("draft.sqlite"))
        let owner = UUID()
        var draft = ProductDraft(ownerUserId: owner)
        draft.name = "Egen yoghurt"
        draft.calories = "70"
        draft.protein = "4"
        draft.carbohydrates = "8"
        draft.fat = "2"
        let product = Product(
            name: draft.name, source: "user", caloriesPer100g: 70,
            proteinGPer100g: 4, carbsGPer100g: 8, fatGPer100g: 2,
            saltGPer100g: 1.2, imageUrl: URL(fileURLWithPath: "/private/product.jpg").absoluteString,
            nutritionBasis: .per100g
        )
        try store.saveProductDraft(draft)

        try store.completeProductDraft(draft, product: product, submission: nil)

        #expect(store.productDrafts(ownerUserId: owner).isEmpty)
        #expect(store.getProduct(product.id)?.id == product.id)
        #expect(store.pendingSyncCount() == 1)
        let event = try #require(store.fetchPendingEvents(limit: 1).first)
        let payload = try #require(JSONSerialization.jsonObject(with: event.payload) as? [String: Any])
        let nutrients = try #require(payload["nutrientsPer100g"] as? [String: Any])
        #expect(payload["imageUrl"] == nil)
        #expect(abs((nutrients["salt"] as? Double ?? 0) - 1.2) < 0.0001)
        #expect(nutrients["sodiumMg"] == nil)
    }

    @Test func claimedDraftPreservesNewOwnerWhenCompleted() throws {
        let store = try LocalStore(databaseURL: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("draft-claim-\(UUID()).sqlite"))
        let oldOwner = UUID()
        let newOwner = UUID()
        let draft = ProductDraft(ownerUserId: oldOwner)
        try store.saveProductDraft(draft)
        try store.claimLocalData(from: oldOwner, to: newOwner)
        #expect(store.productDrafts(ownerUserId: oldOwner).isEmpty)
        let claimed = try #require(store.productDrafts(ownerUserId: newOwner).first)
        #expect(claimed.ownerUserId == newOwner)
        try store.deleteLocalData(ownerId: newOwner)
        #expect(store.productDrafts(ownerUserId: newOwner).isEmpty)
    }

    @Test func saltIsPreservedWithoutGuessingSodium() async throws {
        let repository = ProductCreationRepositorySpy()
        let viewModel = makeViewModel(owner: UUID(), repository: repository)
        viewModel.draft.name = "Salt vare"
        viewModel.draft.calories = "100"
        viewModel.draft.protein = "2"
        viewModel.draft.carbohydrates = "10"
        viewModel.draft.fat = "5"
        viewModel.draft.salt = "1,2"
        viewModel.draft.frontImagePath = "/private/product.jpg"

        let product = await viewModel.complete()

        #expect(product?.saltGPer100g == 1.2)
        #expect(product?.sodiumMgPer100g == nil)
        #expect(product?.imageUrl?.hasPrefix("file://") == true)
    }

    private func makeViewModel(owner: UUID, repository: ProductCreationRepositorySpy) -> CreateProductViewModel {
        CreateProductViewModel(
            ownerUserId: owner, repository: repository,
            imageStore: ProductImageStoreSpy(), ocrService: OCRServiceSpy(), aiService: UnavailableNutritionLabelAIService(),
            aiEnabled: { false }, contributionsEnabled: { false }
        )
    }

    private func field(_ value: Double?) -> ExtractedNutritionField {
        ExtractedNutritionField(value: value, unit: value == nil ? nil : "g", confidence: value == nil ? 0 : 0.95, evidence: nil)
    }
}

@MainActor
private final class ProductCreationRepositorySpy: ProductCreationRepository {
    var savedDrafts: [ProductDraft] = []
    var completed: [(ProductDraft, Product, CatalogSubmission?)] = []
    func saveDraft(_ draft: ProductDraft) async throws { savedDrafts.append(draft) }
    func drafts(ownerUserId: UUID) async -> [ProductDraft] { savedDrafts.filter { $0.ownerUserId == ownerUserId } }
    func deleteDraft(_ id: UUID, ownerUserId: UUID) async throws { savedDrafts.removeAll { $0.id == id && $0.ownerUserId == ownerUserId } }
    func completeDraft(_ draft: ProductDraft, product: Product, submission: CatalogSubmission?) async throws {
        completed.append((draft, product, submission))
    }
}

private actor ProductImageStoreSpy: ProductImageStoring {
    func store(_ image: UIImage, kind: ProductImageKind, draftID: UUID) async throws -> String { "/private/\(draftID).jpg" }
    func data(at path: String) async throws -> Data { Data("image".utf8) }
}

private struct OCRServiceSpy: NutritionLabelOCRService {
    func recognizeText(in image: UIImage) async throws -> String { "Energi 251 kcal" }
}

private struct AIServiceSpy: NutritionLabelAIService {
    let extraction: NutritionExtraction
    func extract(assetID: UUID, imageData: Data, localOCRText: String, language: String) async throws -> NutritionExtraction { extraction }
}
