import Foundation
import Testing
import UIKit
import ImageIO
@testable import MatLogg

@MainActor
struct SavedMealsTests {
    @Test func detailSaveReturnsToUpdatedView() async throws {
        let fixture = SavedMealsFixture()
        fixture.repository.savedMeals = [fixture.meal]
        await fixture.vm.load(userId: fixture.userId)
        let detail = SavedMealDetailViewModel(meal: fixture.meal)
        detail.beginEditing()
        fixture.vm.beginPhotoEditing(data: fixture.meal.localImageData)
        detail.name = "Ny frokost"
        detail.nutrition.setAmount(itemID: fixture.meal.items[0].id, text: "75")
        #expect(await detail.save(using: fixture.vm))
        #expect(!detail.isEditing)
        #expect(detail.meal.name == "Ny frokost")
        #expect(detail.meal.items[0].amountG == 75)
        #expect(detail.meal.items[0].calories == 300)
    }

    @Test func rejectedDetailSaveKeepsDraft() async {
        let fixture = SavedMealsFixture()
        await fixture.vm.load(userId: UUID())
        let detail = SavedMealDetailViewModel(meal: fixture.meal)
        detail.beginEditing()
        detail.name = "Behold kladden"
        #expect(!(await detail.save(using: fixture.vm)))
        #expect(detail.isEditing)
        #expect(detail.name == "Behold kladden")
        #expect(detail.meal == fixture.meal)
        #expect(fixture.vm.errorMessage != nil)
    }

    @Test func previewNutritionMatchesLoggedSnapshotAfterAmountChange() async throws {
        let fixture = SavedMealsFixture()
        await fixture.vm.load(userId: fixture.userId)
        let previewModel = SavedMealNutritionPreviewViewModel(meal: fixture.meal)
        previewModel.setAmount(itemID: fixture.meal.items[0].id, text: "12,5")
        let amounts = try #require(previewModel.preview.validAmounts)
        let preview = try #require(previewModel.preview.total)
        #expect(await fixture.vm.log(fixture.meal, mealType: "lunsj", date: Date(),
                                     amounts: amounts, userId: fixture.userId))
        let logged = NutritionCalculator.totals(for: fixture.repository.savedLogs)
        #expect(logged.calories == preview.calories)
        #expect(logged.protein == preview.protein)
        #expect(logged.carbs == preview.carbs)
        #expect(logged.fat == preview.fat)
    }

    @Test func previewLoadsProductImagesWithoutChangingMealSnapshot() async {
        let fixture = SavedMealsFixture()
        let data = Data([1, 2, 3])
        let url = "https://example.invalid/product.jpg"
        fixture.repository.products[fixture.product.id] = Product(
            id: fixture.product.id, name: "Oppdatert produkt", source: "manual",
            caloriesPer100g: 999, proteinGPer100g: 0, carbsGPer100g: 0, fatGPer100g: 0,
            localImageData: data, imageUrl: url
        )
        let model = fixture.vm.makeItemsViewModel(meal: fixture.meal)
        await model.loadProductImages()
        #expect(model.imageProducts[fixture.product.id]?.localImageData == data)
        #expect(model.imageProducts[fixture.product.id]?.imageUrl == url)
        #expect(model.sortedItems == fixture.meal.items)

        fixture.repository.products = [:]
        await model.loadProductImages()
        #expect(model.imageProducts.isEmpty)
        #expect(model.sortedItems == fixture.meal.items)
    }

    @Test func photoPersistsOnCreationAndCanBeRemovedOnEdit() async throws {
        let fixture = SavedMealsFixture()
        await fixture.vm.load(userId: fixture.userId)
        let data = try #require(UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in
            UIColor.red.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: 8, height: 8)).fill()
        }.jpegData(compressionQuality: 0.75))
        await fixture.vm.importPhoto { data }
        #expect(await fixture.vm.saveFromLogs(name: "Med bilde", mealType: "frokost", logs: [fixture.log], userId: fixture.userId))
        let meal = try #require(fixture.repository.savedMeals.first)
        #expect(meal.localImageData == data)
        fixture.vm.beginPhotoEditing(data: data)
        await fixture.vm.importPhoto { throw CocoaError(.fileReadCorruptFile) }
        #expect(fixture.vm.photoData == data)
        #expect(fixture.vm.photoError != nil)
        fixture.vm.beginPhotoEditing()
        #expect(await fixture.vm.update(meal, name: meal.name, amounts: [meal.items[0].id: meal.items[0].amountG], removedItemIDs: []))
        #expect(fixture.repository.savedMeals.first?.localImageData == nil)
    }

    @Test func removedPhotoCannotBeRestoredByLateImport() async {
        let fixture = SavedMealsFixture()
        await fixture.vm.importPhoto {
            fixture.vm.beginPhotoEditing()
            return Data([1, 2, 3])
        }
        #expect(fixture.vm.photoData == nil)
        #expect(!fixture.vm.isLoadingPhoto)
        #expect(fixture.vm.photoError == nil)
    }

    @Test func photoProcessorLimitsSizeAndStripsOriginalMetadata() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1600, height: 800)).image { _ in
            UIColor.blue.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: 1600, height: 800)).fill()
        }
        let original = try #require(image.jpegData(compressionQuality: 1))
        let originalSource = try #require(CGImageSourceCreateWithData(original as CFData, nil))
        let pixels = try #require(CGImageSourceCreateImageAtIndex(originalSource, 0, nil))
        let withMetadata = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(withMetadata, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, pixels, [
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 1.0, kCGImagePropertyGPSLatitudeRef: "N"]
        ] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        let processed = try LocalMealPhotoRepository.prepare(withMetadata as Data)
        let source = try #require(CGImageSourceCreateWithData(processed as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect((properties[kCGImagePropertyPixelWidth] as? Int ?? 0) <= 1200)
        #expect((properties[kCGImagePropertyPixelHeight] as? Int ?? 0) <= 1200)
        #expect(properties[kCGImagePropertyGPSDictionary] == nil)
        #expect(processed.count <= 2 * 1024 * 1024)
    }

    @Test func invalidImageIsRejectedByProcessor() {
        #expect(throws: (any Error).self) { try LocalMealPhotoRepository.prepare(Data([1, 2, 3])) }
    }

    @Test func savesExistingMealWithExactNutritionSnapshot() async throws {
        let fixture = SavedMealsFixture()
        await fixture.vm.load(userId: fixture.userId)

        #expect(await fixture.vm.saveFromLogs(
            name: "  Vanlig frokost  ",
            mealType: "frokost",
            logs: [fixture.log],
            userId: fixture.userId
        ))

        let saved = try #require(fixture.repository.savedMeals.first)
        #expect(saved.name == "Vanlig frokost")
        #expect(saved.suggestedMealType == "frokost")
        #expect(saved.items.count == 1)
        #expect(saved.items[0].amountG == fixture.log.amountG)
        #expect(saved.items[0].calories == fixture.log.calories)
        #expect(saved.items[0].nutritionSource == .matvaretabellen)
    }

    @Test func loggingAdjustedMealUsesSnapshotAndUndoDeletesOnlyCreatedLogs() async throws {
        let fixture = SavedMealsFixture()
        await fixture.vm.load(userId: fixture.userId)
        let meal = fixture.meal
        fixture.repository.savedMeals = [meal]
        let targetDate = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(await fixture.vm.log(
            meal,
            mealType: "middag",
            date: targetDate,
            amounts: [meal.items[0].id: 100],
            userId: fixture.userId
        ))

        let log = try #require(fixture.repository.savedLogs.first)
        #expect(log.mealType == "middag")
        #expect(log.amountG == 100)
        #expect(log.calories == 400)
        #expect(log.proteinG == 20)
        #expect(Calendar.current.isDate(log.loggedDate, inSameDayAs: targetDate))

        #expect(await fixture.vm.undo())
        #expect(fixture.repository.deletedLogIDs == [log.id])
        #expect(fixture.vm.receipt == nil)
    }

    @Test func missingProductAndInvalidAmountNeverPartiallyLogMeal() async {
        let fixture = SavedMealsFixture()
        await fixture.vm.load(userId: fixture.userId)
        let missingItem = SavedMealItem(
            productId: UUID(), productName: "Mangler", amountG: 50, calories: 100,
            proteinG: 2, carbsG: 3, fatG: 4, nutritionSource: .user, sortIndex: 1
        )
        var meal = fixture.meal
        meal.items.append(missingItem)

        #expect(await fixture.vm.log(
            meal, mealType: "lunsj", date: Date(),
            amounts: [meal.items[0].id: 0, missingItem.id: 50], userId: fixture.userId
        ) == false)
        #expect(fixture.repository.savedLogs.isEmpty)

        #expect(await fixture.vm.log(
            meal, mealType: "lunsj", date: Date(),
            amounts: [meal.items[0].id: 50, missingItem.id: 50], userId: fixture.userId
        ) == false)
        #expect(fixture.repository.savedLogs.isEmpty)
    }

    @Test func editingTemplateDoesNotChangePastLogs() async throws {
        let fixture = SavedMealsFixture()
        fixture.repository.logs = [fixture.log]
        await fixture.vm.load(userId: fixture.userId)
        let meal = fixture.meal
        fixture.repository.savedMeals = [meal]

        #expect(await fixture.vm.update(
            meal,
            name: "Ny frokost",
            amounts: [meal.items[0].id: 75],
            removedItemIDs: []
        ))

        #expect(fixture.repository.logs.map(\.id) == [fixture.log.id])
        #expect(fixture.repository.savedMeals.last?.name == "Ny frokost")
        #expect(fixture.repository.savedMeals.last?.items[0].amountG == 75)
    }

    @Test func repeatedSaveWhileSuspendedWritesOnlyOnce() async {
        let fixture = SavedMealsFixture()
        await fixture.vm.load(userId: fixture.userId)
        fixture.repository.suspendSavedMealSave = true

        let firstSave = Task { @MainActor in
            await fixture.vm.saveFromLogs(
                name: "Frokost",
                mealType: "frokost",
                logs: [fixture.log],
                userId: fixture.userId
            )
        }
        await fixture.repository.waitForSuspendedSave()

        #expect(await fixture.vm.saveFromLogs(
            name: "Frokost",
            mealType: "frokost",
            logs: [fixture.log],
            userId: fixture.userId
        ) == false)

        fixture.repository.resumeSavedMealSave()
        #expect(await firstSave.value)
        #expect(fixture.repository.savedMeals.count == 1)
    }

    @Test func resetDuringSaveCannotPublishPreviousAccountsMeal() async {
        let fixture = SavedMealsFixture()
        await fixture.vm.load(userId: fixture.userId)
        fixture.repository.suspendSavedMealSave = true

        let save = Task { @MainActor in
            await fixture.vm.saveFromLogs(
                name: "Frokost",
                mealType: "frokost",
                logs: [fixture.log],
                userId: fixture.userId
            )
        }
        await fixture.repository.waitForSuspendedSave()
        fixture.vm.reset()
        fixture.repository.resumeSavedMealSave()

        #expect(await save.value)
        #expect(fixture.vm.meals.isEmpty)
        #expect(fixture.vm.receipt == nil)
    }
}

@MainActor
private final class SavedMealsFixture {
    let userId = UUID()
    let product = Product(
        name: "Havregryn", source: "matvaretabellen", kind: .genericFood,
        caloriesPer100g: 400, proteinGPer100g: 20, carbsGPer100g: 60, fatGPer100g: 8,
        nutritionSource: .matvaretabellen, verificationStatus: .verified, isVerified: true
    )
    let repository = SavedMealsRepositorySpy()
    lazy var vm = SavedMealsViewModel(savedMealRepository: repository, foodLogRepository: repository, photoRepository: LocalMealPhotoRepository())
    lazy var log = FoodLog(
        userId: userId, productId: product.id, mealType: "frokost", amountG: 50,
        loggedDate: Calendar.current.startOfDay(for: Date()), calories: 200,
        proteinG: 10, carbsG: 30, fatG: 4
    )
    lazy var meal = SavedMeal(
        userId: userId,
        name: "Frokost",
        suggestedMealType: "frokost",
        items: [SavedMealItem(
            productId: product.id, productName: product.name, amountG: 50,
            calories: 200, proteinG: 10, carbsG: 30, fatG: 4,
            nutritionSource: .matvaretabellen, sortIndex: 0
        )]
    )

    init() {
        repository.products[product.id] = product
    }
}

@MainActor
private final class SavedMealsRepositorySpy: SavedMealRepository, FoodLogRepository {
    var savedMeals: [SavedMeal] = []
    var logs: [FoodLog] = []
    var products: [UUID: Product] = [:]
    var savedLogs: [FoodLog] = []
    var deletedLogIDs: [UUID] = []
    var suspendSavedMealSave = false
    private var saveContinuation: CheckedContinuation<Void, Never>?
    private var saveWaiters: [CheckedContinuation<Void, Never>] = []

    func saveSavedMeal(_ meal: SavedMeal) async throws {
        if suspendSavedMealSave {
            saveWaiters.forEach { $0.resume() }
            saveWaiters.removeAll()
            await withCheckedContinuation { saveContinuation = $0 }
        }
        savedMeals.removeAll { $0.id == meal.id }
        savedMeals.append(meal)
    }

    func waitForSuspendedSave() async {
        if saveContinuation != nil { return }
        await withCheckedContinuation { saveWaiters.append($0) }
    }

    func resumeSavedMealSave() {
        suspendSavedMealSave = false
        saveContinuation?.resume()
        saveContinuation = nil
    }
    func deleteSavedMeal(_ id: UUID, userId: UUID) async throws {
        savedMeals.removeAll { $0.id == id && $0.userId == userId }
    }
    func getSavedMeals(userId: UUID) async -> [SavedMeal] { savedMeals.filter { $0.userId == userId } }
    func saveLogs(_ logs: [FoodLog]) async throws { savedLogs.append(contentsOf: logs); self.logs.append(contentsOf: logs) }
    func deleteLogs(_ ids: [UUID]) async throws { deletedLogIDs.append(contentsOf: ids); logs.removeAll { ids.contains($0.id) } }
    func saveLog(_ log: FoodLog) async throws { try await saveLogs([log]) }
    func deleteLog(_ id: UUID) async throws { try await deleteLogs([id]) }
    func getAllLogs(userId: UUID) async -> [FoodLog] { logs.filter { $0.userId == userId } }
    func getProduct(_ id: UUID) -> Product? { products[id] }
    func getSummary(userId: UUID, date: Date) async -> DailySummary {
        DailySummary(date: date, totalCalories: 0, totalProtein: 0, totalCarbs: 0, totalFat: 0, logs: [])
    }
    func getTodaysSummary(userId: UUID) async -> DailySummary { await getSummary(userId: userId, date: Date()) }
}
