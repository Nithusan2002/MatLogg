import SwiftUI

struct DayNavigationBar: View {
    @Binding var selection: Date
    @State private var isShowingDatePicker = false

    private let calendar: Calendar

    init(
        selection: Binding<Date>,
        calendar: Calendar = .current
    ) {
        _selection = selection
        self.calendar = calendar
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                shiftSelection(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Forrige dag")

            Spacer(minLength: 0)

            Button {
                isShowingDatePicker = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "calendar")
                    Text(title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .font(AppTypography.bodyEmphasis)
                .frame(minHeight: 44)
                .padding(.horizontal, 12)
                .background(AppColors.surface, in: Capsule())
                .overlay(Capsule().stroke(AppColors.separator, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Velg dato. Valgt dato er \(accessibilityDate)")
            .accessibilityIdentifier("day-navigation-date")

            Spacer(minLength: 0)

            Button {
                shiftSelection(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Neste dag")
        }
        .foregroundColor(AppColors.ink)
        .sheet(isPresented: $isShowingDatePicker) {
            NavigationStack {
                VStack(spacing: 16) {
                    Text("Velg dato")
                        .font(AppTypography.title)
                        .foregroundColor(AppColors.ink)

                    DatePicker(
                        "Velg dato",
                        selection: $selection,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                }
                .padding(16)
                .background(AppColors.background.ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Ferdig") { isShowingDatePicker = false }
                            .foregroundColor(AppColors.action)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var title: String {
        if calendar.isDateInToday(selection) { return "I dag" }
        if calendar.isDateInYesterday(selection) { return "I går" }
        if calendar.isDateInTomorrow(selection) { return "I morgen" }

        return selection.formatted(
            .dateTime
                .weekday(.abbreviated)
                .day()
                .month(.abbreviated)
                .locale(Locale(identifier: "nb_NO"))
        ).capitalized
    }

    private var accessibilityDate: String {
        selection.formatted(
            .dateTime
                .weekday(.wide)
                .day()
                .month(.wide)
                .year()
                .locale(Locale(identifier: "nb_NO"))
        )
    }

    private func shiftSelection(by days: Int) {
        guard let candidate = calendar.date(byAdding: .day, value: days, to: selection) else { return }
        selection = candidate
    }
}
