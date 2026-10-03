import Foundation

nonisolated enum ServingKind: String, Codable, Sendable {
    case portion, piece, package, baseAmount
}

/// Immutable, historical conversion basis; never resolved through current catalog data.
nonisolated struct PortionSelection: Codable, Equatable, Sendable {
    let servingId: UUID
    let label: String
    var count: Double
    let amountPerServing: Double
    let unit: AmountUnit
    let source: ServingSource
    let kind: ServingKind

    var total: Double { count * amountPerServing }

    func matches(amount: Double, unit: AmountUnit) -> Bool {
        self.unit == unit && kind != .baseAmount && !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && label.count <= 200 && count.isFinite && count > 0
            && amountPerServing.isFinite && amountPerServing > 0 && amountPerServing <= 10_000
            && total.isFinite && total > 0 && total <= 10_000 && amount.isFinite
            && abs(total - amount) <= max(0.0001, abs(amount) * 0.000001)
    }

    func scaled(to amount: Float) -> PortionSelection? {
        var copy = self
        copy.count = Double(amount) / amountPerServing
        return copy.matches(amount: Double(amount), unit: unit) ? copy : nil
    }

    var displayText: String { "\(PortionDisplay.number(count)) \(label)" }
    var serving: ServingOption {
        ServingOption(id: servingId, label: label, grams: amountPerServing, unit: unit,
                      source: source, kind: kind, shortLabel: label)
    }
}

nonisolated enum PortionDisplay {
    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...6)).locale(Locale(identifier: "nb_NO")))
    }

    static func amount(_ amount: Double, unit: AmountUnit, portion: PortionSelection?) -> String {
        let total = "\(number(amount)) \(unit.rawValue)"
        guard let portion, portion.matches(amount: amount, unit: unit) else { return total }
        return "\(portion.displayText) · \(total)"
    }
}

extension ServingOption {
    /// Explicit metadata or a documented legacy portion. Old heuristic cache is not a piece weight.
    nonisolated var selectableKind: ServingKind? {
        if let kind { return kind == .baseAmount ? nil : kind }
        return source == .heuristic ? nil : .portion
    }

    nonisolated var portionLabel: String {
        if let shortLabel { return shortLabel }
        return Self.documentedLabel(label)
    }

    nonisolated static func documentedLabel(_ raw: String) -> String {
        // Only an explicit singular unit prefix is normalized; plural/multiple units stay generic.
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("1 ") else { return "porsjon" }
        let name = trimmed.dropFirst(2).split(whereSeparator: { $0 == "(" || $0 == "·" }).first
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        guard !name.isEmpty, !name.contains(where: { $0.isNumber }), name.count <= 80 else { return "porsjon" }
        return name
    }
}
