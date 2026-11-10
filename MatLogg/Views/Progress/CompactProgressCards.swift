import SwiftUI
import Charts

struct CompactNutritionCard: View {
    @ObservedObject var model: ProgressViewModel
    let onRetry: () -> Void
    @State private var showsDailyTotals = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 8) {
                ProgressCardHeading(title: "Mat og næring", symbol: "fork.knife")
                if let calories = model.overview.averageCalories {
                    ViewThatFits(in: .horizontal) {
                        Text("\(calories.formatted(.number.locale(Locale(identifier: "nb_NO")))) kcal")
                            .font(AppTypography.hero).fixedSize(horizontal: true, vertical: false)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(calories.formatted(.number.locale(Locale(identifier: "nb_NO")))).font(AppTypography.hero)
                            Text("kcal").font(AppTypography.bodyEmphasis)
                        }
                    }
                    Text(model.period == .day ? "Totalt logget denne dagen" : "Snitt per logget dag · \(model.overview.coverage)")
                        .font(AppTypography.secondary).foregroundStyle(AppColors.textSecondary)
                    if model.period == .day {
                        dailyMacroDistribution
                    } else {
                        monthChart
                        Divider().overlay(AppColors.separator)
                        macroFooter()
                    }
                } else if model.isLoading {
                    ProgressView("Henter oversikten …").frame(maxWidth: .infinity, minHeight: 140)
                } else {
                    Text(model.errorMessage == nil ? "Ingen mat registrert" : "Kunne ikke hente oversikten")
                        .font(AppTypography.bodyEmphasis)
                    if model.errorMessage == nil {
                        Text("Registrerte måltider vises her.")
                            .font(AppTypography.body).foregroundStyle(AppColors.textSecondary)
                    }
                }
                if model.errorMessage != nil {
                    if model.overview.averageCalories != nil {
                        Text("Kunne ikke oppdatere oversikten")
                            .font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                    }
                    Button("Prøv igjen", action: onRetry)
                        .frame(minHeight: 44)
                        .disabled(model.isLoading)
                }
                if model.period != .day && !model.overview.recordedDays.isEmpty {
                    Button("Vis dagstall") { showsDailyTotals = true }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("progress-hub-nutrition-daily-totals")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(AppColors.deepInk)
        .tint(AppColors.actionText)
        .sheet(isPresented: $showsDailyTotals) {
            NutritionDayTotalsSheet(periodLabel: model.dateRange.label, days: model.overview.recordedDays)
        }
    }

    private var monthChart: some View {
        Chart(model.overview.recordedDays, id: \.date) { day in
            BarMark(x: .value("Dato", day.date, unit: .day), y: .value("kcal", day.totalCalories), width: .ratio(0.65))
                .foregroundStyle(AppColors.brand)
                .cornerRadius(5)
        }
        .chartXScale(domain: model.dateRange.interval.start...model.dateRange.interval.end)
        .chartYScale(domain: 0...model.overview.chartUpperBound)
        .chartXAxis {
            AxisMarks(values: monthAxisDates) { value in
                if let date = value.as(Date.self) {
                    let anchor: UnitPoint = date == model.dateRange.interval.start ? .topLeading : .top
                    AxisValueLabel(centered: false, anchor: anchor, collisionResolution: .greedy) {
                        Text(date.formatted(.dateTime.day().locale(Locale(identifier: "nb_NO"))))
                            .font(AppTypography.chartLabel)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(AppColors.separator)
                AxisValueLabel().font(AppTypography.chartLabel).foregroundStyle(AppColors.textSecondary)
            }
        }
        .frame(height: 88)
        .padding(.top, 4)
        .accessibilityHidden(true)
    }

    private var monthAxisDates: [Date] {
        model.dateRange.dates.enumerated().filter { $0.offset % 7 == 0 }.map(\.element)
    }

    private var dailyMacroDistribution: some View {
        let distribution = model.overview.dayMacroDistribution
        return VStack(alignment: .leading, spacing: 8) {
            Text(distribution == nil ? "Makrofordeling ikke tilgjengelig" : "Energifordeling fra makroer")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
                .accessibilityIdentifier("progress-day-macro-distribution")
            GeometryReader { geometry in
                if let distribution {
                    HStack(spacing: 0) {
                        AppColors.macroProteinTint.frame(width: geometry.size.width * distribution.protein)
                        AppColors.macroCarbTint.frame(width: geometry.size.width * distribution.carbs)
                        AppColors.macroFatTint.frame(width: geometry.size.width * distribution.fat)
                    }
                } else {
                    AppColors.progressTrack
                }
            }
            .frame(height: 10)
            .clipShape(Capsule())
            .accessibilityHidden(true)
            macroFooter(distribution: distribution)
        }
        .padding(.top, 6)
    }

    private func macroFooter(distribution: ProgressMacroDistribution? = nil) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        return layout {
            macro("Protein", value: model.overview.protein, fraction: distribution?.protein, tint: AppColors.macroProteinTint)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            macro("Karbo", value: model.overview.carbs, fraction: distribution?.carbs, tint: AppColors.macroCarbTint)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            macro("Fett", value: model.overview.fat, fraction: distribution?.fat, tint: AppColors.macroFatTint)
        }
        .font(AppTypography.captionEmphasis)
    }

    @ViewBuilder private func macro(_ title: String, value: Float?, fraction: Double?, tint: Color) -> some View {
        let fullTitle = title == "Karbo" ? "Karbohydrater" : title
        if let fraction, let value {
            let grams = NutritionDisplay.wholeGrams(value)
            let percentage = fraction.formatted(.percent.precision(.fractionLength(0)).locale(Locale(identifier: "nb_NO")))
            VStack(alignment: .leading, spacing: 3) {
                Label {
                    Text(title)
                } icon: {
                    Circle().fill(tint).frame(width: 7, height: 7).accessibilityHidden(true)
                }
                Text("\(grams) g · \(percentage)")
                    .foregroundStyle(AppColors.textSecondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(fullTitle), \(grams) gram, \(percentage) av energien fra makroene")
        } else {
            Text(value.map { "\(title) \(NutritionDisplay.wholeGrams($0)) g" } ?? "\(title) –")
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(value.map { "\(fullTitle) \(NutritionDisplay.wholeGrams($0)) gram" }
                                    ?? "\(fullTitle) ikke tilgjengelig")
        }
    }

}

struct CompactStepsCard: View {
    @ObservedObject var model: StepCountViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let isPaired: Bool

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 8) {
                ProgressCardHeading(title: "Skritt", symbol: "figure.walk", compact: true, opensDetails: true)
                switch model.state {
                case .loaded(let snapshot):
                    if let count = snapshot.count {
                        let layout = isPaired || dynamicTypeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 6))
                        layout {
                            Text(count.formatted(.number.locale(Locale(identifier: "nb_NO"))))
                                .font(AppTypography.metricValue)
                                .accessibilityLabel("\(count) skritt")
                                .accessibilityIdentifier("health-step-count-summary")
                            Text("skritt totalt")
                                .font(AppTypography.secondary)
                                .accessibilityHidden(true)
                        }
                        if let first = snapshot.buckets.first, let last = snapshot.buckets.last,
                           first.date < last.date {
                            trendChart(snapshot, domain: first.date...last.date)
                        }
                    }
                case .loading:
                    ProgressView().frame(minHeight: 40)
                    Text("Henter skritt …").font(AppTypography.secondary)
                case .notConnected:
                    Text("Slås på i Innstillinger").font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                case .noData:
                    Text("Ingen data").font(AppTypography.title)
                    Text("Se tilgang og detaljer").font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                case .failed:
                    Text("Prøv igjen").font(AppTypography.title)
                    Text("Kunne ikke hente skritt").font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                case .unavailable:
                    Text("Utilgjengelig").font(AppTypography.bodyEmphasis)
                case .demo:
                    Text("Ikke tilkoblet").font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: isPaired ? 116 : nil,
                   maxHeight: isPaired ? .infinity : nil, alignment: .topLeading)
        }
        .foregroundStyle(AppColors.deepInk)
    }

    private func trendChart(_ snapshot: StepCountSnapshot, domain: ClosedRange<Date>) -> some View {
        Chart {
            ForEach(snapshot.trendRuns(), id: \.first?.date) { run in
                ForEach(run) { bucket in
                    let time = PlottableValue.value("Tid", bucket.date)
                    let steps = PlottableValue.value("Skritt", bucket.steps)
                    if run.count > 1, let start = run.first?.date {
                        let series = PlottableValue.value("Serie", start)
                        AreaMark(x: time, yStart: .value("Null", 0.0), yEnd: steps, series: series)
                            .foregroundStyle(AppColors.activityChart.opacity(0.13))
                        LineMark(x: time, y: steps, series: series)
                            .foregroundStyle(AppColors.activityChart)
                    } else {
                        PointMark(x: time, y: steps)
                            .foregroundStyle(AppColors.activityChart)
                            .symbolSize(14)
                    }
                }
            }
        }
        .chartXScale(domain: domain)
        .chartYScale(domain: 0...max(1, snapshot.buckets.map(\.steps).max() ?? 0))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 28)
        .accessibilityHidden(true)
    }
}

struct CompactWeightCard: View {
    let overview: ProgressWeightOverview
    let isLoading: Bool
    let isPaired: Bool

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 8) {
                ProgressCardHeading(title: "Vekt", symbol: "scalemass", compact: true, opensDetails: true)
                if let latest = overview.latest {
                    let formattedWeight = latest.weightKg.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "nb_NO")))
                    ProgressMetricReading(isPaired: isPaired) {
                        ViewThatFits(in: .horizontal) {
                            Text("\(formattedWeight) kg")
                                .font(AppTypography.metricValue).fixedSize(horizontal: true, vertical: false)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(formattedWeight).font(AppTypography.metricValue)
                                Text("kg").font(AppTypography.body)
                            }
                        }
                    } detail: {
                        let date = latest.date.formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "nb_NO")))
                        Text(overview.showsEarlierMeasurement ? "Før perioden · \(date)" : "Sist \(date)")
                            .font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                    }
                    if overview.points.count > 1 {
                        Chart(overview.points) { entry in
                            LineMark(x: .value("Dato", entry.date), y: .value("kg", entry.weightKg))
                                .foregroundStyle(AppColors.deepInk.opacity(0.65))
                            PointMark(x: .value("Dato", entry.date), y: .value("kg", entry.weightKg))
                                .foregroundStyle(AppColors.deepInk.opacity(0.65)).symbolSize(12)
                        }
                        .chartYScale(domain: overview.chartLowerBound...overview.chartUpperBound)
                        .chartXAxis(.hidden).chartYAxis(.hidden)
                        .frame(height: 26).accessibilityHidden(true)
                    }
                } else if isLoading {
                    ProgressView().frame(minHeight: 40)
                } else {
                    Text("Ingen vekt").font(AppTypography.title)
                    Text("Registrer valgfritt").font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: isPaired ? 116 : nil,
                   maxHeight: isPaired ? .infinity : nil, alignment: .topLeading)
        }
        .foregroundStyle(AppColors.deepInk)
    }
}

private struct ProgressMetricReading<Value: View, Detail: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let isPaired: Bool
    @ViewBuilder let value: () -> Value
    @ViewBuilder let detail: () -> Detail

    var body: some View {
        if isPaired || dynamicTypeSize.isAccessibilitySize {
            stacked
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    value().fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    detail().fixedSize(horizontal: true, vertical: false)
                }
                stacked
            }
        }
    }

    private var stacked: some View {
        VStack(alignment: .leading, spacing: 8) {
            value()
            detail()
        }
    }
}

struct ProgressCardHeading: View {
    let title: String
    let symbol: String
    var detail: String? = nil
    var compact = false
    var opensDetails = false

    var body: some View {
        if opensDetails {
            HStack(spacing: 8) {
                titleContent
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(AppTypography.captionEmphasis)
                    .foregroundStyle(AppColors.textSecondary)
                    .accessibilityHidden(true)
            }
        } else {
            titleContent
        }
    }

    @ViewBuilder private var titleContent: some View {
        if let detail {
            let detailLabel = Text(detail).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    heading.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 4)
                    detailLabel.fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 3) {
                    heading
                    detailLabel
                }
            }
        } else {
            heading
        }
    }

    private var heading: some View {
        Label {
            Text(title).foregroundStyle(AppColors.deepInk)
        } icon: {
            Image(systemName: symbol).foregroundStyle(AppColors.actionText).accessibilityHidden(true)
        }
        .font(compact ? AppTypography.secondaryEmphasis : AppTypography.sectionTitle)
        .accessibilityAddTraits(.isHeader)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct NutritionDayTotalsSheet: View {
    let periodLabel: String
    let days: [DailySummary]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(days, id: \.date) { day in
                        dayRow(day)
                            .listRowBackground(AppColors.surface)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(periodLabel).font(AppTypography.sectionTitle).foregroundStyle(AppColors.deepInk)
                        Text("Registrert i MatLogg")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .textCase(nil)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("Dagstall")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ferdig") { dismiss() }
                }
            }
        }
    }

    private func dayRow(_ day: DailySummary) -> some View {
        let date = day.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).locale(Locale(identifier: "nb_NO")))
        let calories = "\(NutritionDisplay.wholeCalories(day.totalCalories)) kcal"
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 8))
        return VStack(alignment: .leading, spacing: 5) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(date).fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 8)
                    Text(calories).fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(date)
                    Text(calories)
                }
            }
            .font(AppTypography.bodyEmphasis)
            .foregroundStyle(AppColors.deepInk)

            layout {
                Text("Protein \(NutritionDisplay.wholeGrams(day.totalProtein)) g")
                Text("Karbohydrater \(NutritionDisplay.wholeGrams(day.totalCarbs)) g")
                Text("Fett \(NutritionDisplay.wholeGrams(day.totalFat)) g")
            }
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("nutrition-day-total")
    }
}

struct StepCountDetailView: View {
    @ObservedObject var model: StepCountViewModel
    let dateRange: ProgressDateRange
    let onOpenHealthSettings: () -> Void

    var body: some View {
        ScrollView {
            CardContainer {
                StepCountCardContent(model: model, dateRange: dateRange, onOpenHealthSettings: onOpenHealthSettings)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .matLoggTabBarScrollClearance()
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Skritt").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task { await model.refresh() }
        .refreshable { await model.refresh() }
    }
}
