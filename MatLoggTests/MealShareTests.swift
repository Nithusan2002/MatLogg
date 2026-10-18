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
        let model = MealShareViewModel(renderer: renderer, preferences: preferences)
        let meal = makeMeal()
        await model.open(meal: meal, preview: SavedMealNutritionPreviewViewModel(meal: meal).preview, showSource: false)
        #expect(model.snapshot?.sourceText == nil)
        model.select(.dark)
        #expect(preferences.style == .dark)
        renderer.shouldFail = true
        await model.export()
        #expect(model.errorMessage != nil)
        #expect(!model.isExporting)
        renderer.shouldFail = false
        await model.export()
        #expect(model.sharedImage != nil)
        #expect(renderer.lastStyle == .dark)
        #expect(model.errorMessage == nil)
        model.reset()
        #expect(model.snapshot == nil)
        #expect(model.sharedImage == nil)
    }

    @Test func resetDiscardsInFlightExport() async {
        let renderer = ShareRendererSpy()
        renderer.suspend = true
        let model = MealShareViewModel(renderer: renderer, preferences: MemorySharePreferences())
        let meal = makeMeal()
        await model.open(meal: meal, preview: SavedMealNutritionPreviewViewModel(meal: meal).preview, showSource: true)
        let task = Task { await model.export() }
        while renderer.continuation == nil { await Task.yield() }
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
    }

    @Test func corruptPhotoHasExplicitFallback() async {
        var meal = makeMeal()
        meal.localImageData = Data([0, 1, 2])
        let model = MealShareViewModel(renderer: ShareRendererSpy(), preferences: MemorySharePreferences())
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
}

@MainActor
private final class ShareRendererSpy: MealShareRendering {
    var shouldFail = false
    var lastStyle: MealShareStyle?
    var suspend = false
    var continuation: CheckedContinuation<UIImage, any Error>?
    func render(snapshot: MealShareSnapshot, style: MealShareStyle, photo: UIImage?) async throws -> UIImage {
        lastStyle = style
        if shouldFail { throw CocoaError(.fileWriteUnknown) }
        if suspend { return try await withCheckedThrowingContinuation { continuation = $0 } }
        return UIImage()
    }
}
