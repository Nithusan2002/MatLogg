import Combine
import Foundation
import UIKit

enum MealShareStyle: String, CaseIterable, Identifiable {
    case light, dark, photo
    var id: String { rawValue }
    var title: String {
        switch self { case .light: return "Lys"; case .dark: return "Mørk"; case .photo: return "Foto" }
    }
}

struct MealShareSnapshot {
    let name: String
    let imageData: Data?
    let nutrition: NutritionBreakdown
    let sourceText: String?

    @MainActor
    init?(meal: SavedMeal, preview: SavedMealNutritionPreview, showSource: Bool) {
        guard preview.validAmounts != nil, let total = preview.total,
              [total.calories, total.protein, total.carbs, total.fat].allSatisfy({ $0.isFinite && $0 >= 0 }) else { return nil }
        name = meal.name
        imageData = meal.localImageData
        nutrition = total
        let sources = Set(meal.items.map { $0.nutritionSource.rawValue }).sorted().map {
            switch $0 { case "matvaretabellen": return "Matvaretabellen"
            case "openFoodFacts": return "Open Food Facts"
            default: return "Brukeroppgitt" }
        }
        sourceText = showSource ? "Kilder: " + sources.joined(separator: " · ") : nil
    }
}

@MainActor
protocol MealSharePreferences {
    var style: MealShareStyle { get set }
}

@MainActor
final class LocalMealSharePreferences: MealSharePreferences {
    private let defaults: UserDefaults
    init(defaults: UserDefaults) { self.defaults = defaults }
    var style: MealShareStyle {
        get { MealShareStyle(rawValue: defaults.string(forKey: "mealShareStyle") ?? "") ?? .light }
        set { defaults.set(newValue.rawValue, forKey: "mealShareStyle") }
    }
}

@MainActor
protocol MealShareRendering {
    func render(snapshot: MealShareSnapshot, style: MealShareStyle, photo: UIImage?) async throws -> UIImage
}

@MainActor
final class MealShareViewModel: ObservableObject {
    struct SharedImage: Identifiable {
        let id = UUID()
        let image: UIImage
    }
    @Published private(set) var snapshot: MealShareSnapshot?
    @Published private(set) var photo: UIImage?
    @Published private(set) var style: MealShareStyle = .light
    @Published private(set) var isPreparing = false
    @Published private(set) var isExporting = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var photoWarning: String?
    @Published var sharedImage: SharedImage?
    private let renderer: any MealShareRendering
    private var preferences: any MealSharePreferences
    private var generation = UUID()

    init(renderer: any MealShareRendering, preferences: any MealSharePreferences) {
        self.renderer = renderer
        self.preferences = preferences
    }

    func open(meal: SavedMeal, preview: SavedMealNutritionPreview, showSource: Bool) async {
        reset()
        style = preferences.style
        guard let value = MealShareSnapshot(meal: meal, preview: preview, showSource: showSource) else {
            errorMessage = "Kontroller mengdene og næringsgrunnlaget før du deler måltidet."
            return
        }
        snapshot = value
        isPreparing = true
        let request = generation
        let data = value.imageData
        let decoded = await Task.detached(priority: .userInitiated) { data.flatMap { UIImage(data: $0) } }.value
        guard request == generation, !Task.isCancelled else { return }
        photo = decoded
        if data != nil && decoded == nil { photoWarning = "Bildet kunne ikke leses. Kortet deles uten bilde." }
        isPreparing = false
    }

    func select(_ style: MealShareStyle) {
        guard !isExporting else { return }
        self.style = style
        preferences.style = style
        errorMessage = nil
    }

    func export() async {
        guard let snapshot, !isPreparing, !isExporting else { return }
        let request = generation
        defer { if request == generation { isExporting = false } }
        isExporting = true
        errorMessage = nil
        do {
            let image = try await renderer.render(snapshot: snapshot, style: style, photo: photo)
            guard request == generation, !Task.isCancelled else { return }
            sharedImage = SharedImage(image: image)
        } catch {
            guard request == generation, !Task.isCancelled else { return }
            errorMessage = "Kunne ikke lage kortet. Prøv igjen."
        }
    }

    func reset() {
        generation = UUID()
        snapshot = nil
        photo = nil
        sharedImage = nil
        isPreparing = false
        isExporting = false
        errorMessage = nil
        photoWarning = nil
    }
}
