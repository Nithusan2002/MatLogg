import Foundation
import Combine

@MainActor
final class ProductDetailViewModel: ObservableObject {
    @Published private(set) var product: Product
    @Published private(set) var isRefreshing = false
    @Published private(set) var refreshMessage: String?
    @Published private(set) var isLogging = false
    @Published private(set) var logError: String?
    private let repository: any BarcodeLookupRepository

    init(product: Product, repository: any BarcodeLookupRepository) {
        self.product = product
        self.repository = repository
    }

    var nutriScoreInfo: ProductNutriScoreInfo? {
        product.source == "openfoodfacts" ? product.nutriScoreInfo : nil
    }

    var excludedProteinValue: String? {
        guard let calculation = nutriScoreInfo?.calculation,
              calculation.proteinExclusionReason != nil,
              calculation.preparation == "as_sold",
              let basis = calculation.nutritionBasis,
              product.nutritionBasis == basis,
              product.proteinGPer100g.isFinite, product.proteinGPer100g >= 0 else { return nil }
        return "\(product.proteinGPer100g.formatted(.number.locale(Locale(identifier: "nb_NO")).precision(.fractionLength(0...2)))) g"
    }

    var processingInfo: ProductProcessingInfo? {
        guard product.source == "openfoodfacts" else { return nil }
        return product.processingInfo ?? ProductProcessingInfo(novaGroup: nil, markers: [:], ingredients: nil)
    }

    var processingPresentation: ProductProcessingPresentation? {
        processingInfo.map(ProductProcessingPresentation.init)
    }

    var processingSourceURL: URL? {
        guard let code = product.barcodeEan, !code.isEmpty,
              code.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return URL(string: "https://world.openfoodfacts.org/product/\(code)")
    }

    var canRefresh: Bool { product.canRefreshCatalogData }

    func nutrition(for amount: Double?) -> NutritionBreakdown {
        guard let amount else { return NutritionBreakdown(calories: 0, protein: 0, carbs: 0, fat: 0) }
        return product.calculateNutrition(forAmount: Float(amount))
    }

    func log(amount: AmountSelectionViewModel,
             operation: (Product, Double, PortionSelection?) async -> Bool) async -> Bool {
        guard !isLogging, amount.isValid, let total = amount.amount else { return false }
        isLogging = true
        logError = nil
        defer { isLogging = false }
        let success = await operation(product, total, amount.portion)
        if !success { logError = "Kunne ikke lagre på enheten. Prøv igjen." }
        return success
    }

    func refresh(manually: Bool) async {
        guard !isRefreshing, canRefresh else { return }
        isRefreshing = true
        refreshMessage = nil
        defer { isRefreshing = false }
        do {
            if let updated = try await repository.refresh(product, manually: manually) {
                // Keep the approved amount unit stable while this card is open.
                guard updated.amountUnit == product.amountUnit else {
                    refreshMessage = "Produktets måleenhet er endret hos kilden. Åpne produktet på nytt for å bruke de nye dataene."
                    return
                }
                let portionsChanged = updated.servings != product.servings
                product = updated
                if portionsChanged {
                    refreshMessage = "Porsjonsdata er oppdatert. Aktivt porsjonsvalg beholder sitt grunnlag til du velger på nytt."
                } else if manually { refreshMessage = "Produktdata er oppdatert." }
            }
        } catch {
            if manually { refreshMessage = BarcodeLookupFailure.classify(error).message }
        }
    }
}

/// Pure presentation mapping of source-provided calculation components.
nonisolated struct NutriScoreCalculationPresentation {
    struct Row: Identifiable {
        let id: String
        let title: String
        let value: String
        let points: String?
        let segments: NutriScoreSegments?
    }
    let calculation: NutriScoreCalculation

    private static let titles = ["energy": "Energi", "sugars": "Sukkerarter", "saturated_fat": "Mettet fett",
        "salt": "Salt", "fiber": "Fiber", "proteins": "Protein", "fruits_vegetables_legumes": "Frukt, grønnsaker og belgvekster"]

    func rows(_ components: [NutriScoreComponent]) -> [Row] {
        var seen = Set<String>()
        return components.compactMap { component in
            guard !(component.id == "proteins" && calculation.proteinExclusionReason != nil),
                  let title = Self.titles[component.id], seen.insert(component.id).inserted else { return nil }
            let value: String
            if let number = component.value, number.isFinite, number >= 0,
               let unit = component.unit, ["g", "kJ", "%"].contains(unit) {
                value = "\(number.formatted(.number.locale(Locale(identifier: "nb_NO")).precision(.fractionLength(0...2)))) \(unit)"
            } else { value = "Verdi ikke tilgjengelig" }
            return Row(id: component.id, title: title, value: value,
                       points: Self.points(component.points, maximum: component.points_max),
                       segments: NutriScoreSegments(points: component.points, maximum: component.points_max))
        }
    }

    static func points(_ points: Int?, maximum: Int?) -> String? {
        guard let points, let maximum, maximum > 0, points >= 0, points <= maximum else { return nil }
        return "\(points) av \(maximum)"
    }

    var incomplete: Bool {
        (calculation.positive + calculation.negative).contains { Self.titles[$0.id] == nil }
    }

    var proteinExplanation: String? {
        guard let reason = calculation.proteinExclusionReason else { return nil }
        if reason == "negative_points_greater_than_or_equal_to_11" {
            return "Nutri-Score har regler for når protein gir plusspoeng. I denne beregningen er minuspoengene høye nok til at protein ikke tas med. Proteinmengden i produktet er fortsatt den samme."
        }
        return "Nutri-Score har regler for når protein gir plusspoeng. Open Food Facts oppgir at protein ikke er medregnet i denne beregningen. Proteinmengden i produktet er fortsatt den samme."
    }
}

/// Bounds untrusted source counts before allocating visual segments.
nonisolated struct NutriScoreSegments: Equatable {
    let filled: Int
    let count: Int

    init?(points: Int?, maximum: Int?) {
        guard let points, let maximum, (1...100).contains(maximum),
              (0...maximum).contains(points) else { return nil }
        filled = points
        count = maximum
    }
}


/// Source-based presentation only; missing groups never imply a negative answer.
nonisolated struct ProductProcessingPresentation {
    let status: String
    let isUltraProcessed: Bool?
    let explanation: String
    let basis: String

    init(info: ProductProcessingInfo) {
        let descriptions = [
            1: "minimalt bearbeidet mat",
            2: "matlagingsingredienser som salt, sukker og olje",
            3: "bearbeidet mat. Gruppen omfatter blant annet mat der salt, sukker eller olje er tilsatt råvarer",
            4: "ultraprosessert mat"
        ]
        guard let group = info.novaGroup, let description = descriptions[group] else {
            isUltraProcessed = nil
            status = "Klassifisering mangler"
            explanation = "Open Food Facts har ingen tilgjengelig NOVA-klassifisering for dette produktet. Vi kan derfor ikke si om det er ultraprosessert."
            basis = "Grunnlag for klassifiseringen er ikke tilgjengelig."
            return
        }
        isUltraProcessed = group == 4
        status = group == 4 ? "Klassifisert som ultraprosessert" : "Ikke klassifisert som ultraprosessert"
        explanation = "Open Food Facts plasserer produktet i NOVA \(group): \(description)."
        if info.markerNames.isEmpty {
            basis = "Open Food Facts oppgir en klassifisering, men vi har ikke en detaljert forklaring for dette produktet."
        } else {
            basis = "Open Food Facts oppgir \(info.markerNames.joined(separator: " og ")) som grunnlag for NOVA \(group)."
                + (info.hasUntranslatedMarkers ? " Noe av grunnlaget kan ikke vises med en forståelig forklaring ennå." : "")
        }
    }
}
