import Foundation
import Combine

enum PersonalMeasurement: String, Identifiable {
    case weight, height

    var id: String { rawValue }
    var title: String { self == .weight ? "Vekt" : "Høyde" }
    var unit: String { self == .weight ? "kg" : "cm" }
    var step: Double { self == .weight ? 0.1 : 1 }
    var lowerBound: Double { self == .weight ? 20 : 80 }
    var upperBound: Double { self == .weight ? 300 : 250 }
    var startingValue: Double { self == .weight ? 70 : 170 }
    var tickCount: Int { Int(((upperBound - lowerBound) / step).rounded()) + 1 }
    var majorInterval: Int { 10 }

    func value(at tick: Int) -> Double { lowerBound + Double(tick) * step }

    func text(at tick: Int) -> String {
        value(at: tick).formatted(.number.locale(Locale(identifier: "nb_NO"))
            .precision(.fractionLength(self == .weight ? 1 : 0)))
    }
}

/// A temporary editing snapshot. Applying it updates the parent draft, never storage.
@MainActor
final class MeasurementPickerViewModel: ObservableObject {
    let measurement: PersonalMeasurement
    @Published var text: String {
        didSet {
            selectedTick = tick(for: parsedValue ?? measurement.startingValue)
            error = nil
        }
    }
    @Published private(set) var selectedTick: Int
    @Published private(set) var error: String?

    init(measurement: PersonalMeasurement, initialText: String) {
        self.measurement = measurement
        let initial = initialText.trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = initial.isEmpty ? String(measurement.startingValue).replacingOccurrences(of: ".", with: ",") : initialText
        text = draft
        let value = Double(draft.replacingOccurrences(of: ",", with: ".")) ?? measurement.startingValue
        let finiteValue = value.isFinite ? value : measurement.startingValue
        selectedTick = Int(((min(max(finiteValue, measurement.lowerBound), measurement.upperBound)
            - measurement.lowerBound) / measurement.step).rounded())
    }

    private var parsedValue: Double? {
        guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")), value.isFinite, value > 0 else { return nil }
        return value
    }

    private func tick(for value: Double) -> Int {
        Int(((min(max(value, measurement.lowerBound), measurement.upperBound)
            - measurement.lowerBound) / measurement.step).rounded())
    }

    func select(tick: Int) {
        guard (0..<measurement.tickCount).contains(tick), tick != selectedTick else { return }
        text = measurement.text(at: tick)
    }

    func adjust(by direction: Int) {
        let current = parsedValue ?? measurement.startingValue
        let adjusted = min(max(current + Double(direction) * measurement.step,
                               measurement.lowerBound), measurement.upperBound)
        text = measurement.text(at: tick(for: adjusted))
    }

    func confirmedText() -> String? {
        guard parsedValue != nil else {
            error = "Skriv et gyldig tall over 0 \(measurement.unit)."
            return nil
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
