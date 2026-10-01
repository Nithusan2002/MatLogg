import Testing
@testable import MatLogg

@MainActor
struct MeasurementPickerTests {
    @Test func openingAndConfirmingPreservesExactInput() {
        let picker = MeasurementPickerViewModel(measurement: .weight, initialText: "72,25")
        picker.select(tick: picker.selectedTick)
        #expect(picker.confirmedText() == "72,25")
    }

    @Test func rulerSelectionUsesMeasurementStep() {
        let weight = MeasurementPickerViewModel(measurement: .weight, initialText: "70")
        weight.select(tick: 525)
        #expect(weight.confirmedText() == "72,5")
        let height = MeasurementPickerViewModel(measurement: .height, initialText: "170")
        height.select(tick: 98)
        #expect(height.confirmedText() == "178")
    }

    @Test func manualInputOutsideRulerRangeIsPreserved() {
        let picker = MeasurementPickerViewModel(measurement: .weight, initialText: "350,25")
        picker.select(tick: picker.selectedTick)
        #expect(picker.confirmedText() == "350,25")
        picker.text = "15,75"
        picker.select(tick: picker.selectedTick)
        #expect(picker.confirmedText() == "15,75")
    }

    @Test(arguments: ["0", "-5", "nan", "inf", "feil", ""])
    func invalidManualValuesCannotBeApplied(value: String) {
        let picker = MeasurementPickerViewModel(measurement: .height, initialText: "170")
        picker.text = value
        #expect(picker.confirmedText() == nil)
        #expect(picker.error != nil)
        picker.text = "178,5"
        #expect(picker.error == nil)
        #expect(picker.confirmedText() == "178,5")
    }

    @Test func accessibleAdjustmentsStayWithinRulerBounds() {
        let picker = MeasurementPickerViewModel(measurement: .weight, initialText: "300")
        picker.adjust(by: 1)
        #expect(picker.confirmedText() == "300,0")
        picker.text = "20"
        picker.adjust(by: -1)
        #expect(picker.confirmedText() == "20,0")
        picker.adjust(by: 1)
        #expect(picker.confirmedText() == "20,1")
    }
}
