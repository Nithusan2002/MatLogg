import SwiftUI

struct ProgressWeekCard: View {
    let areas: [ProgressHubArea]
    @ObservedObject var progress: ProgressViewModel
    @ObservedObject var steps: StepCountViewModel
    @ObservedObject var workouts: HealthWorkoutViewModel
    let onRetryNutrition: () -> Void
    let onOpenHealthSettings: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsDayTotals = false
    private let norwegian = Locale(identifier: "nb_NO")
    private let summaryWidth: CGFloat = 120
    private let columnSpacing: CGFloat = 4
    private let rowSpacing: CGFloat = 12

    var body: some View {
        let range = progress.dateRange.interval
        let overview = progress.weekOverview(steps: steps.snapshot(for: range), workouts: workouts.snapshot(for: range))
        CardContainer {
            VStack(alignment: .leading, spacing: rowSpacing) {
                Text(progress.isCurrentPeriod ? "Denne uken" : "Ukeoversikt")
                    .font(AppTypography.sectionTitle)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("progress-week-title")

                if dynamicTypeSize.isAccessibilitySize {
                    content(overview, stacked: true)
                } else {
                    ViewThatFits(in: .horizontal) {
                        content(overview, stacked: false).frame(minWidth: 318)
                        content(overview, stacked: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(AppColors.deepInk)
        .sheet(isPresented: $showsDayTotals) {
            NutritionDayTotalsSheet(periodLabel: progress.dateRange.label, days: progress.overview.recordedDays)
        }
    }

    private func content(_ overview: ProgressWeekOverview, stacked: Bool) -> some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            ForEach(areas) { area in
                if area != areas.first { Divider().overlay(AppColors.separator) }
                switch area {
                case .nutrition:
                    nutritionRow(overview, stacked: stacked)
                case .steps:
                    NavigationLink {
                        StepCountDetailView(model: steps, dateRange: progress.dateRange, onOpenHealthSettings: onOpenHealthSettings)
                    } label: {
                        stepsRow(overview, stacked: stacked)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("progress-hub-steps-open")
                case .workouts:
                    NavigationLink {
                        WorkoutDetailView(model: workouts, dateRange: progress.dateRange, onOpenHealthSettings: onOpenHealthSettings)
                    } label: {
                        workoutRow(overview, stacked: stacked)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("progress-hub-workouts-open")
                case .weight:
                    EmptyView()
                }
            }
            Divider().overlay(AppColors.separator)
            timeline(overview.days) { day in
                VStack(spacing: 2) {
                    Text(day.date.formatted(.dateTime.weekday(dynamicTypeSize.isAccessibilitySize ? .narrow : .abbreviated).locale(norwegian)))
                    Text(day.date.formatted(.dateTime.day().locale(norwegian)))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
            }
            .font(AppTypography.chartLabel)
            .foregroundStyle(AppColors.textSecondary)
            .padding(.leading, stacked ? 0 : summaryWidth + rowSpacing)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder private func nutritionRow(_ overview: ProgressWeekOverview, stacked: Bool) -> some View {
        if let total = overview.totalCalories, let average = overview.averageCalories {
            Button {
                showsDayTotals = true
            } label: {
                row(stacked: stacked) {
                    summary(.nutrition, value: "\(format(total)) kcal",
                            caption: "Totalt i uken\n\(format(average)) kcal i snitt\n\(overview.loggedDays) av \(overview.days.count) dager logget",
                            opensDetails: true)
                } plot: {
                    bars(overview.days, value: \.calories, upperBound: progress.overview.chartUpperBound,
                         color: AppColors.brand, unit: "kcal")
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("progress-hub-nutrition-daily-totals")
            .accessibilityHint("Vis dagstall")
        } else {
            row(stacked: stacked) {
                summary(.nutrition, caption: progress.isLoading ? "Henter mat …" :
                        progress.errorMessage == nil ? "Ingen mat registrert" : "Kunne ikke hente mat")
            } plot: {
                emptyPlot
            }
        }
        if progress.errorMessage != nil {
            VStack(alignment: .leading, spacing: 0) {
                if overview.totalCalories != nil {
                    Text("Kunne ikke oppdatere mat")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Button("Prøv igjen", action: onRetryNutrition)
                    .font(AppTypography.secondaryEmphasis)
                    .foregroundStyle(AppColors.actionText)
                    .frame(minHeight: 44)
                    .disabled(progress.isLoading)
            }
        }
    }

    private func stepsRow(_ overview: ProgressWeekOverview, stacked: Bool) -> some View {
        row(stacked: stacked) {
            if let total = overview.totalSteps, let average = overview.averageSteps {
                summary(.steps, value: "\(format(total)) skritt", caption: "\(format(average)) skritt per dag med data", opensDetails: true)
            } else {
                summary(.steps, caption: healthStatus(steps.state), opensDetails: true)
            }
        } plot: {
            if overview.totalSteps != nil {
                let peak = overview.days.compactMap(\.steps).max() ?? 0
                bars(overview.days, value: \.steps, upperBound: max(1_000, (peak / 1_000).rounded(.up) * 1_000),
                     color: AppColors.activityChart, unit: "skritt")
            } else {
                emptyPlot
            }
        }
    }

    private func workoutRow(_ overview: ProgressWeekOverview, stacked: Bool) -> some View {
        row(stacked: stacked) {
            if overview.workoutCount > 0 {
                let count = overview.workoutCount
                summary(.workouts, value: count == 1 ? "1 økt" : "\(format(count)) økter", opensDetails: true)
            } else {
                summary(.workouts, caption: workouts.state == .noData ? "Ingen treningsøkter tilgjengelig i perioden" : healthStatus(workouts.state),
                        opensDetails: true)
            }
        } plot: {
            if overview.workoutCount > 0 {
                timeline(overview.days) { day in
                    VStack(spacing: 2) {
                        if let workout = day.workouts.first {
                            let sameType = day.workouts.allSatisfy { $0.symbol == workout.symbol }
                            Image(systemName: sameType ? workout.symbol : "dumbbell")
                                .font(AppTypography.captionEmphasis)
                            if day.workouts.count > 1 {
                                Text(format(day.workouts.count)).font(AppTypography.chartLabelEmphasis)
                            }
                        } else {
                            Circle()
                                .fill(AppColors.textSecondary.opacity(0.5))
                                .frame(width: 5, height: 5)
                        }
                    }
                    .foregroundStyle(AppColors.actionText)
                    .frame(maxWidth: .infinity, minHeight: 40)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(overview.days.map { day in
                    let count = day.workouts.count
                    let types = day.workouts.map(\.title).joined(separator: ", ")
                    let description = count > 1 ? "\(format(count)) økter, \(types)" : types
                    return "\(spokenDay(day.date)): \(description.isEmpty ? "Ingen økter vist" : description)"
                }.joined(separator: ". "))
            } else {
                emptyPlot
            }
        }
    }

    private func summary(_ area: ProgressHubArea, value: String? = nil, caption: String? = nil, opensDetails: Bool = false) -> some View {
        let title = switch area {
        case .nutrition: "Mat"
        case .workouts: "Trening"
        case .steps, .weight: area.title
        }
        return VStack(alignment: .leading, spacing: 4) {
            ProgressCardHeading(title: title, symbol: area.symbol, compact: true, opensDetails: opensDetails)
                .accessibilityLabel(area.title)
            if let value {
                Text(value).font(AppTypography.bodyEmphasis).monospacedDigit()
            }
            if let caption {
                Text(caption).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row<Summary: View, Plot: View>(stacked: Bool, @ViewBuilder summary: () -> Summary, @ViewBuilder plot: () -> Plot) -> some View {
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: rowSpacing))
        return layout {
            summary().frame(width: stacked ? nil : summaryWidth, alignment: .leading)
            plot()
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func bars(_ days: [ProgressWeekOverview.Day], value: KeyPath<ProgressWeekOverview.Day, Double?>,
                      upperBound: Double, color: Color, unit: String) -> some View {
        let height: CGFloat = 48
        return VStack(alignment: .trailing, spacing: 2) {
            Text(upperBound.formatted(.number.precision(.fractionLength(0)).locale(norwegian)))
                .font(AppTypography.chartLabel)
                .foregroundStyle(AppColors.textSecondary)
            timeline(days) { day in
                ZStack(alignment: .bottom) {
                    Color.clear
                    if let count = day[keyPath: value], count.isFinite, count >= 0 {
                        UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3)
                            .fill(color)
                            .frame(height: max(2, height * CGFloat(min(count / upperBound, 1))))
                            .padding(.horizontal, 2)
                    }
                }
                .frame(height: height)
            }
            .background {
                VStack(spacing: 0) {
                    ForEach(0..<4) { _ in
                        Rectangle().fill(AppColors.separator.opacity(0.65)).frame(height: 0.5)
                        Spacer(minLength: 0)
                    }
                    Rectangle().fill(AppColors.separator).frame(height: 0.5)
                }
                .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(days.map { day in
            let reading = day[keyPath: value].map {
                "\($0.formatted(.number.precision(.fractionLength(0)).locale(norwegian))) \(unit)"
            } ?? "Ingen data"
            return "\(spokenDay(day.date)): \(reading)"
        }.joined(separator: ". "))
    }

    private func timeline<Content: View>(_ days: [ProgressWeekOverview.Day], @ViewBuilder cell: @escaping (ProgressWeekOverview.Day) -> Content) -> some View {
        let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: columnSpacing), count: days.count)
        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(days) { day in cell(day) }
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyPlot: some View {
        Color.clear.frame(height: 0).frame(maxWidth: .infinity).accessibilityHidden(true)
    }

    private func healthStatus<Snapshot>(_ state: HealthReadViewModel<Snapshot>.State) -> String {
        switch state {
        case .loading, .loaded: "Henter data …"
        case .notConnected: "Slå på i innstillingene i Spor Mat"
        case .noData: "Ingen data tilgjengelig"
        case .failed: "Kunne ikke hente data"
        case .unavailable: "Apple Helse er utilgjengelig"
        case .demo: "Ikke tilkoblet i demo"
        }
    }

    private func format(_ number: Int) -> String {
        number.formatted(.number.locale(norwegian))
    }

    private func spokenDay(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).locale(norwegian))
    }
}
