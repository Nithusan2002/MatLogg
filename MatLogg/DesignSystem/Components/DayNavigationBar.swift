import SwiftUI

struct DayNavigationBar: View {
    @Binding var selection: Date
    @State private var isShowingDatePicker = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass

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
                    .contentShape(Rectangle())
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
            .popover(isPresented: $isShowingDatePicker, arrowEdge: .top) {
                datePickerContent
                    .presentationCompactAdaptation(.popover)
            }

            Spacer(minLength: 0)

            Button {
                shiftSelection(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Neste dag")
        }
        .foregroundColor(AppColors.ink)
    }

    @ViewBuilder
    private var datePickerContent: some View {
        if dynamicTypeSize.isAccessibilitySize || verticalSizeClass == .compact {
            ScrollView {
                calendarPicker
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
            }
            .frame(width: 340, height: verticalSizeClass == .compact ? 240 : 480)
            .presentationBackground(AppColors.background)
        } else {
            calendarPicker
                .padding(12)
                .frame(width: 340)
                .fixedSize(horizontal: false, vertical: true)
                .presentationBackground(AppColors.background)
        }
    }

    private var calendarPicker: some View {
        DatePicker(
            "Velg dato",
            selection: $selection,
            displayedComponents: [.date]
        )
        .datePickerStyle(.graphical)
        .labelsHidden()
        .environment(\.locale, Locale(identifier: "nb_NO"))
        .environment(\.calendar, calendar)
        .tint(AppColors.action)
        .accessibilityIdentifier("day-navigation-calendar")
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
