import Foundation
import Combine

@MainActor
final class AmountSelectionViewModel: ObservableObject {
    @Published var text: String
    @Published private(set) var selectedServing: ServingOption?
    @Published private(set) var servings: [ServingOption]
    let unit: AmountUnit
    private var hasChosenPortion = false

    init(unit: AmountUnit, servings: [ServingOption] = [], amount: Double = 100,
         portion: PortionSelection? = nil) {
        self.unit = unit
        self.servings = Self.compatible(servings, unit: unit)
        if let portion, portion.matches(amount: amount, unit: unit) {
            selectedServing = portion.serving
            text = Self.input(portion.count)
            hasChosenPortion = true
        } else {
            text = Self.input(amount)
        }
    }

    private static func compatible(_ servings: [ServingOption], unit: AmountUnit) -> [ServingOption] {
        var seen = Set<UUID>()
        return servings.filter {
            $0.amountUnit == unit && $0.selectableKind != nil && $0.grams.isFinite
                && $0.grams > 0 && $0.grams <= 10_000 && seen.insert($0.id).inserted
        }
    }

    private static func input(_ value: Double) -> String {
        value.formatted(.number.grouping(.never).precision(.significantDigits(1...17)).locale(Locale(identifier: "nb_NO")))
    }

    var value: Double? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard normalized.range(of: #"^[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil,
              let value = Double(normalized), value.isFinite, value > 0 else { return nil }
        return value
    }

    var amount: Double? {
        guard let value else { return nil }
        let total = value * (selectedServing?.grams ?? 1)
        return total.isFinite && total > 0 && total <= 10_000 && Float(total) > 0 ? total : nil
    }

    var portion: PortionSelection? {
        guard let serving = selectedServing, let kind = serving.selectableKind,
              let count = value, let amount else { return nil }
        let snapshot = PortionSelection(servingId: serving.id, label: serving.portionLabel,
                                        count: count, amountPerServing: serving.grams,
                                        unit: unit, source: serving.source, kind: kind)
        return snapshot.matches(amount: amount, unit: unit) ? snapshot : nil
    }

    var isValid: Bool { amount != nil && (selectedServing == nil || portion != nil) }
    var amountSummary: String? {
        guard isValid, let amount else { return nil }
        return PortionDisplay.amount(amount, unit: unit, portion: portion)
    }
    var canDecrease: Bool { isValid && (value ?? 0) > 1 }
    var canIncrease: Bool {
        guard isValid, let value, let serving = selectedServing else { return false }
        return (value + 1) * serving.grams <= 10_000
    }

    func select(_ serving: ServingOption?) {
        if let serving {
            guard serving.amountUnit == unit, serving.selectableKind != nil,
                  serving.grams.isFinite, serving.grams > 0, serving.grams <= 10_000 else { return }
        }
        let previousAmount = amount
        let preserveTotal = hasChosenPortion
        selectedServing = serving
        if let serving {
            // First explicit portion choice starts at one. Subsequent switches preserve total.
            text = Self.input(preserveTotal ? (previousAmount ?? serving.grams) / serving.grams : 1)
            hasChosenPortion = true
        } else if let previousAmount {
            text = Self.input(previousAmount)
        }
    }

    func step(_ delta: Double) {
        guard selectedServing != nil, let value, value + delta > 0 else { return }
        let total = (value + delta) * (selectedServing?.grams ?? 1)
        guard total.isFinite, total <= 10_000 else { return }
        text = Self.input(value + delta)
    }

    func restore(amount: Double, portion: PortionSelection?) {
        if let portion, portion.matches(amount: amount, unit: unit),
           servings.contains(where: { $0.portionLabel == portion.label && $0.grams == portion.amountPerServing
               && $0.amountUnit == portion.unit && $0.source == portion.source
               && $0.selectableKind == portion.kind }) {
            selectedServing = portion.serving
            text = Self.input(portion.count)
            hasChosenPortion = true
        } else {
            selectedServing = nil
            text = Self.input(amount)
        }
    }

    func updateServings(_ servings: [ServingOption]) {
        self.servings = Self.compatible(servings, unit: unit)
        // selectedServing is intentionally a snapshot, independent of refreshed options.
    }
}
