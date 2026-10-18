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

enum MealShareFormat: String, CaseIterable, Identifiable {
    case portrait, story
    var id: String { rawValue }
    var title: String { self == .portrait ? "3:4" : "9:16" }
    var canvasSize: CGSize { CGSize(width: 360, height: self == .portrait ? 480 : 640) }
    var aspectRatio: CGFloat { canvasSize.width / canvasSize.height }
}

struct MealShareContent: Codable, Equatable {
    var calories = true
    var protein = true
    var carbs = true
    var fat = true
    var logo = true

    enum CodingKeys: String, CodingKey { case calories, protein, carbs, fat, logo }

    var hasMacros: Bool { protein || carbs || fat }
    var hasNutrition: Bool { calories || hasMacros }
    var selectedCount: Int { [calories, protein, carbs, fat, logo].filter { $0 }.count }
}

extension MealShareContent {
    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        calories = try values.decodeIfPresent(Bool.self, forKey: .calories) ?? true
        protein = try values.decodeIfPresent(Bool.self, forKey: .protein) ?? true
        carbs = try values.decodeIfPresent(Bool.self, forKey: .carbs) ?? true
        fat = try values.decodeIfPresent(Bool.self, forKey: .fat) ?? true
        // Existing nutrient preferences predate the optional logo.
        logo = try values.decodeIfPresent(Bool.self, forKey: .logo) ?? true
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
    var format: MealShareFormat { get set }
    var content: MealShareContent { get set }
}

@MainActor
final class LocalMealSharePreferences: MealSharePreferences {
    private let defaults: UserDefaults
    init(defaults: UserDefaults) { self.defaults = defaults }
    var style: MealShareStyle {
        get { MealShareStyle(rawValue: defaults.string(forKey: "mealShareStyle") ?? "") ?? .light }
        set { defaults.set(newValue.rawValue, forKey: "mealShareStyle") }
    }
    var format: MealShareFormat {
        get { MealShareFormat(rawValue: defaults.string(forKey: "mealShareFormat") ?? "") ?? .story }
        set { defaults.set(newValue.rawValue, forKey: "mealShareFormat") }
    }
    var content: MealShareContent {
        get {
            guard let data = defaults.data(forKey: "mealShareContent"),
                  let content = try? JSONDecoder().decode(MealShareContent.self, from: data) else {
                return MealShareContent()
            }
            return content
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: "mealShareContent")
        }
    }
}

@MainActor
protocol MealShareRendering {
    func render(snapshot: MealShareSnapshot, style: MealShareStyle, photo: UIImage?, content: MealShareContent, format: MealShareFormat) async throws -> UIImage
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
    @Published private(set) var format: MealShareFormat = .story
    @Published private(set) var content = MealShareContent()
    @Published private(set) var isPreparing = false
    @Published private(set) var isExporting = false
    @Published private(set) var isSaving = false
    var isWorking: Bool { isExporting || isSaving }
    @Published var saveNotice: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var photoWarning: String?
    @Published var sharedImage: SharedImage?
    private let renderer: any MealShareRendering
    private let photoSaver: any MealSharePhotoSaving
    private var preferences: any MealSharePreferences
    private var generation = UUID()

    init(renderer: any MealShareRendering, preferences: any MealSharePreferences, photoSaver: any MealSharePhotoSaving) {
        self.renderer = renderer
        self.preferences = preferences
        self.photoSaver = photoSaver
    }

    func open(meal: SavedMeal, preview: SavedMealNutritionPreview, showSource: Bool) async {
        reset()
        style = preferences.style
        format = preferences.format
        content = preferences.content
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
        guard !isWorking else { return }
        self.style = style
        preferences.style = style
        errorMessage = nil
    }

    func export() async {
        guard let snapshot, !isPreparing, !isWorking else { return }
        let request = generation
        defer { if request == generation { isExporting = false } }
        isExporting = true
        errorMessage = nil
        do {
            let image = try await renderer.render(snapshot: snapshot, style: style, photo: photo, content: content, format: format)
            guard request == generation, !Task.isCancelled else { return }
            sharedImage = SharedImage(image: image)
        } catch {
            guard request == generation, !Task.isCancelled else { return }
            errorMessage = "Kunne ikke lage kortet. Prøv igjen."
        }
    }

    func setContent(_ content: MealShareContent) {
        guard !isWorking else { return }
        self.content = content
        preferences.content = content
        errorMessage = nil
    }

    func selectFormat(_ format: MealShareFormat) {
        guard !isWorking else { return }
        self.format = format
        preferences.format = format
        errorMessage = nil
    }

    func saveToPhotos() async {
        guard let snapshot, !isPreparing, !isWorking else { return }
        let request = generation
        isSaving = true
        saveNotice = nil
        errorMessage = nil
        defer { if request == generation { isSaving = false } }
        do {
            try await photoSaver.requestAuthorization()
            guard request == generation, !Task.isCancelled else { return }
            let image = try await renderer.render(snapshot: snapshot, style: style, photo: photo, content: content, format: format)
            guard request == generation, !Task.isCancelled else { return }
            try await photoSaver.save(image)
            guard request == generation, !Task.isCancelled else { return }
            saveNotice = "Bildet er lagret i Bilder."
        } catch {
            guard request == generation, !Task.isCancelled else { return }
            if let error = error as? MealSharePhotoSaveError, case .accessDenied = error {
                saveNotice = "MatLogg har ikke tillatelse til å lagre bilder. Du kan gi tilgang til å legge til bilder i Innstillinger."
            } else {
                saveNotice = "Kunne ikke lagre bildet. Prøv igjen."
            }
        }
    }

    func reset() {
        generation = UUID()
        snapshot = nil
        photo = nil
        sharedImage = nil
        isPreparing = false
        isExporting = false
        isSaving = false
        saveNotice = nil
        errorMessage = nil
        photoWarning = nil
    }
}
