import Foundation
import Testing
import UIKit
@testable import MatLogg

@MainActor
struct MealShareTests {
    @Test func snapshotUsesAdjustedAmountsWithoutChangingMeal() throws {
        let meal = makeMeal()
        let preview = SavedMealNutritionPreviewViewModel(meal: meal)
        preview.setAmount(itemID: meal.items[0].id, text: "150")
        let snapshot = try #require(MealShareSnapshot(meal: meal, preview: preview.preview, showSource: true))
        #expect(snapshot.nutrition.calories == 150)
        #expect(snapshot.nutrition.protein == 15)
        #expect(snapshot.sourceText == "Kilder: Brukeroppgitt")
        #expect(meal.items[0].amountG == 100)
        preview.setAmount(itemID: meal.items[0].id, text: "")
        #expect(MealShareSnapshot(meal: meal, preview: preview.preview, showSource: true) == nil)
    }

    @Test func stylePreferenceAndFailureRetry() async throws {
        let preferences = MemorySharePreferences()
        let renderer = ShareRendererSpy()
        let model = MealShareViewModel(renderer: renderer, preferences: preferences, photoSaver: SharePhotoSaverSpy())
        let meal = makeMeal()
        await model.open(meal: meal, preview: SavedMealNutritionPreviewViewModel(meal: meal).preview, showSource: false)
        #expect(model.snapshot?.sourceText == nil)
        model.select(.dark)
        let content = MealShareContent(calories: false, protein: true, carbs: false, fat: false, logo: false)
        model.setContent(content)
        #expect(preferences.style == .dark)
        #expect(preferences.content == content)
        renderer.shouldFail = true
        await model.export()
        #expect(model.errorMessage != nil)
        #expect(!model.isExporting)
        renderer.shouldFail = false
        await model.export()
        #expect(model.sharedImage != nil)
        #expect(renderer.lastStyle == .dark)
        #expect(renderer.lastContent == content)
        #expect(model.errorMessage == nil)
        model.reset()
        #expect(model.snapshot == nil)
        #expect(model.sharedImage == nil)
        await model.open(meal: meal, preview: SavedMealNutritionPreviewViewModel(meal: meal).preview, showSource: false)
        #expect(model.content == content)
    }

    @Test func resetDiscardsInFlightExport() async {
        let renderer = ShareRendererSpy()
        renderer.suspend = true
        let model = MealShareViewModel(renderer: renderer, preferences: MemorySharePreferences(), photoSaver: SharePhotoSaverSpy())
        let meal = makeMeal()
        await model.open(meal: meal, preview: SavedMealNutritionPreviewViewModel(meal: meal).preview, showSource: true)
        let task = Task { await model.export() }
        while renderer.continuation == nil { await Task.yield() }
        model.setContent(MealShareContent(calories: false))
        #expect(model.content.calories)
        model.reset()
        renderer.continuation?.resume(returning: UIImage())
        await task.value
        #expect(model.sharedImage == nil)
        #expect(!model.isExporting)
    }

    @Test func localStylePreferenceSurvivesRecreationAndUnknownValuesFallBack() throws {
        let name = "MealShareTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("removed-style", forKey: "mealShareStyle")
        #expect(LocalMealSharePreferences(defaults: defaults).style == .light)
        LocalMealSharePreferences(defaults: defaults).style = .photo
        #expect(LocalMealSharePreferences(defaults: defaults).style == .photo)
        #expect(LocalMealSharePreferences(defaults: defaults).content == MealShareContent())
        let content = MealShareContent(calories: false, protein: false, carbs: false, fat: false, logo: false)
        LocalMealSharePreferences(defaults: defaults).content = content
        #expect(LocalMealSharePreferences(defaults: defaults).content == content)
        defaults.set(Data(#"{"calories":false,"protein":true,"carbs":false,"fat":false}"#.utf8), forKey: "mealShareContent")
        #expect(LocalMealSharePreferences(defaults: defaults).content == MealShareContent(
            calories: false, protein: true, carbs: false, fat: false, logo: true))
        defaults.set(Data("invalid".utf8), forKey: "mealShareContent")
        #expect(LocalMealSharePreferences(defaults: defaults).content == MealShareContent())
    }

    @Test func corruptPhotoHasExplicitFallback() async {
        var meal = makeMeal()
        meal.localImageData = Data([0, 1, 2])
        let model = MealShareViewModel(renderer: ShareRendererSpy(), preferences: MemorySharePreferences(), photoSaver: SharePhotoSaverSpy())
        await model.open(meal: meal, preview: SavedMealNutritionPreviewViewModel(meal: meal).preview, showSource: false)
        #expect(model.photo == nil)
        #expect(model.photoWarning != nil)
        #expect(model.snapshot != nil)
        #expect(!model.isPreparing)
    }

    @Test func allStylesRenderFullResolutionWithAndWithoutPhoto() async throws {
        let meal = makeMeal(name: String(repeating: "Langt måltidsnavn ", count: 5))
        let snapshot = try #require(MealShareSnapshot(meal: meal,
            preview: SavedMealNutritionPreviewViewModel(meal: meal).preview, showSource: true))
        let fixtures: [(String, UIImage?)] = [
            ("none", nil),
            ("landscape", makePhoto(size: CGSize(width: 160, height: 90), color: .white)),
            ("portrait", makePhoto(size: CGSize(width: 90, height: 160), color: .darkGray)),
            ("square", makePhoto(size: CGSize(width: 100, height: 100), color: .orange))
        ]
        for style in MealShareStyle.allCases {
            for (name, input) in fixtures {
                let image = try await MealShareRenderingService().render(snapshot: snapshot, style: style, photo: input)
                #expect(image.cgImage?.width == 1080)
                #expect(image.cgImage?.height == 1920)
                if style == .photo && name == "landscape" {
                    // The photo between the header and footer must keep its original brightness.
                    let cgImage = try #require(image.cgImage)
                    let sample = try #require(cgImage.cropping(to: CGRect(x: 540, y: 480, width: 1, height: 1)))
                    var pixel = [UInt8](repeating: 0, count: 4)
                    try pixel.withUnsafeMutableBytes { bytes in
                        let context = try #require(CGContext(data: bytes.baseAddress, width: 1, height: 1,
                            bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                        context.draw(sample, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                    }
                    #expect(pixel[0] > 245 && pixel[1] > 245 && pixel[2] > 245)
                }
                if name == "landscape" || name == "none" {
                    Attachment.record(try #require(image.pngData()), named: "meal-share-\(style.rawValue)-\(name).png")
                }
            }
        }
    }

    @Test(arguments: [
        MealShareContent(calories: false),
        MealShareContent(protein: false),
        MealShareContent(carbs: false),
        MealShareContent(fat: false),
        MealShareContent(calories: false, protein: false, carbs: false, fat: false)
    ])
    func hiddenValuesDoNotAffectExportedPixels(content: MealShareContent) async throws {
        let meal = makeMeal()
        var changed = meal
        if !content.calories { changed.items[0].calories = 987 }
        if !content.protein { changed.items[0].proteinG = 87 }
        if !content.carbs { changed.items[0].carbsG = 76 }
        if !content.fat { changed.items[0].fatG = 65 }
        let original = try #require(MealShareSnapshot(meal: meal,
            preview: SavedMealNutritionPreviewViewModel(meal: meal).preview, showSource: true))
        let updated = try #require(MealShareSnapshot(meal: changed,
            preview: SavedMealNutritionPreviewViewModel(meal: changed).preview, showSource: true))
        let photo = makePhoto(size: CGSize(width: 100, height: 100), color: .orange)
        for style in MealShareStyle.allCases {
            let renderer = MealShareRenderingService()
            let first = try await renderer.render(snapshot: original, style: style, photo: photo, content: content)
            let second = try await renderer.render(snapshot: updated, style: style, photo: photo, content: content)
            #expect(try #require(first.pngData()) == #require(second.pngData()))
            if !content.hasNutrition {
                Attachment.record(try #require(first.pngData()), named: "meal-share-\(style.rawValue)-no-nutrition.png")
            }
        }
    }

    @Test func logoCanBeHiddenInEveryStyle() async throws {
        let meal = makeMeal()
        let snapshot = try #require(MealShareSnapshot(meal: meal,
            preview: SavedMealNutritionPreviewViewModel(meal: meal).preview, showSource: false))
        let photo = makePhoto(size: CGSize(width: 100, height: 100), color: .white)
        for style in MealShareStyle.allCases {
            for input in [photo, nil] {
                let renderer = MealShareRenderingService()
                let visible = try await renderer.render(snapshot: snapshot, style: style, photo: input)
                let hidden = try await renderer.render(snapshot: snapshot, style: style, photo: input,
                                                       content: MealShareContent(logo: false))
                #expect(try #require(visible.pngData()) != #require(hidden.pngData()))
                #expect(hidden.cgImage?.width == 1080)
                #expect(hidden.cgImage?.height == 1920)
                if input != nil {
                    Attachment.record(try #require(hidden.pngData()), named: "meal-share-\(style.rawValue)-no-logo.png")
                }
            }
        }
    }

    @Test func saveUsesSelectionAndHandlesDeniedAccessAndRetry() async {
        let renderer = ShareRendererSpy()
        let saver = SharePhotoSaverSpy()
        let model = MealShareViewModel(renderer: renderer, preferences: MemorySharePreferences(), photoSaver: saver)
        let meal = makeMeal()
        await model.open(meal: meal, preview: SavedMealNutritionPreviewViewModel(meal: meal).preview, showSource: false)
        model.select(.photo)
        let content = MealShareContent(calories: false, logo: false)
        model.setContent(content)

        saver.authorizationError = MealSharePhotoSaveError.accessDenied
        await model.saveToPhotos()
        #expect(model.saveNotice?.contains("ikke tillatelse") == true)
        #expect(renderer.lastStyle == nil)
        #expect(saver.saveCount == 0)
        #expect(!model.isWorking)

        saver.authorizationError = nil
        saver.saveError = CocoaError(.fileWriteUnknown)
        await model.saveToPhotos()
        #expect(model.saveNotice == "Kunne ikke lagre bildet. Prøv igjen.")
        #expect(!model.isSaving)
        saver.saveError = nil
        await model.saveToPhotos()
        #expect(model.saveNotice == "Bildet er lagret i Bilder.")
        #expect(saver.saveCount == 2)
        #expect(renderer.lastStyle == .photo)
        #expect(renderer.lastContent == content)
        #expect(model.sharedImage == nil)
        #expect(model.snapshot?.nutrition.calories == 100)
    }

    @Test func resetDuringPhotoPermissionPreventsSavingAndBlocksOverlappingActions() async {
        let renderer = ShareRendererSpy()
        let saver = SharePhotoSaverSpy()
        saver.suspendAuthorization = true
        let model = MealShareViewModel(renderer: renderer, preferences: MemorySharePreferences(), photoSaver: saver)
        let meal = makeMeal()
        await model.open(meal: meal, preview: SavedMealNutritionPreviewViewModel(meal: meal).preview, showSource: false)
        let task = Task { await model.saveToPhotos() }
        while saver.authorizationContinuation == nil { await Task.yield() }
        #expect(model.isSaving)
        model.select(.dark)
        model.setContent(MealShareContent(logo: false))
        await model.export()
        await model.saveToPhotos()
        #expect(model.style == .light)
        #expect(model.content.logo)
        #expect(saver.authorizationCount == 1)
        model.reset()
        saver.authorizationContinuation?.resume()
        await task.value
        #expect(saver.saveCount == 0)
        #expect(renderer.lastStyle == nil)
        #expect(model.saveNotice == nil)
        #expect(!model.isWorking)
    }

    private func makePhoto(size: CGSize, color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func makeMeal(name: String = "Testmåltid") -> SavedMeal {
        SavedMeal(userId: UUID(), name: name, items: [SavedMealItem(productId: UUID(),
            productName: "Testvare", amountG: 100, calories: 100, proteinG: 10,
            carbsG: 20, fatG: 5, nutritionSource: .user, sortIndex: 0)])
    }
}

@MainActor
private final class MemorySharePreferences: MealSharePreferences {
    var style: MealShareStyle = .light
    var content = MealShareContent()
}

@MainActor
private final class ShareRendererSpy: MealShareRendering {
    var shouldFail = false
    var lastStyle: MealShareStyle?
    var lastContent: MealShareContent?
    var suspend = false
    var continuation: CheckedContinuation<UIImage, any Error>?
    func render(snapshot: MealShareSnapshot, style: MealShareStyle, photo: UIImage?, content: MealShareContent) async throws -> UIImage {
        lastStyle = style
        lastContent = content
        if shouldFail { throw CocoaError(.fileWriteUnknown) }
        if suspend { return try await withCheckedThrowingContinuation { continuation = $0 } }
        return UIImage()
    }
}

@MainActor
private final class SharePhotoSaverSpy: MealSharePhotoSaving {
    var authorizationError: (any Error)?
    var saveError: (any Error)?
    var authorizationCount = 0
    var saveCount = 0
    var suspendAuthorization = false
    var authorizationContinuation: CheckedContinuation<Void, Never>?

    func requestAuthorization() async throws {
        authorizationCount += 1
        if let authorizationError { throw authorizationError }
        if suspendAuthorization {
            await withCheckedContinuation { authorizationContinuation = $0 }
        }
    }

    func save(_ image: UIImage) async throws {
        saveCount += 1
        if let saveError { throw saveError }
    }
}
