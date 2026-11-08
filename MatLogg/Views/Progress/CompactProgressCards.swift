import SwiftUI
import Charts

struct CompactNutritionCard: View {
    @ObservedObject var model: ProgressViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 8) {
                ProgressCardHeading(title: "Mat og næring", symbol: "fork.knife", source: "MatLogg")
                if let calories = model.overview.averageCalories {
                    ViewThatFits(in: .horizontal) {
                        Text("\(calories.formatted(.number.locale(Locale(identifier: "nb_NO")))) kcal")
                            .font(AppTypography.hero).fixedSize(horizontal: true, vertical: false)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(calories.formatted(.number.locale(Locale(identifier: "nb_NO")))).font(AppTypography.hero)
                            Text("kcal").font(AppTypography.bodyEmphasis)
                        }
                    }
                    Text(model.period == .day ? "Registrert denne dagen" : "Snitt per logget dag · \(model.overview.recordedDays.count)/\(model.dateRange.dates.count)")
                        .font(AppTypography.secondary).foregroundStyle(AppColors.textSecondary)
                    periodChart
                    Divider().overlay(AppColors.separator)
                    macroFooter
                } else if model.isLoading {
                    ProgressView("Henter oversikten …").frame(maxWidth: .infinity, minHeight: 140)
                } else {
                    Text(model.errorMessage == nil ? "Ingen mat registrert" : "Kunne ikke hente oversikten")
                        .font(AppTypography.bodyEmphasis)
                    Text(model.errorMessage == nil ? "Registrerte måltider vises her." : "Åpne kortet for å prøve igjen.")
                        .font(AppTypography.body).foregroundStyle(AppColors.textSecondary)
                }
                if model.errorMessage != nil && model.overview.averageCalories != nil {
                    Text("Kunne ikke oppdatere. Åpne kortet for å prøve igjen.")
                        .font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(AppColors.deepInk)
    }

    private var periodChart: some View {
        Chart(model.overview.recordedDays, id: \.date) { day in
            BarMark(x: .value("Dato", day.date, unit: .day), y: .value("kcal", day.totalCalories), width: .ratio(0.65))
                .foregroundStyle(AppColors.brand)
                .cornerRadius(5)
        }
        .chartXScale(domain: model.dateRange.interval.start...model.dateRange.interval.end)
        .chartYScale(domain: 0...model.overview.chartUpperBound)
        .chartXAxis {
            AxisMarks(values: axisDates) { value in
                AxisValueLabel(centered: model.period != .month) {
                    if let date = value.as(Date.self), date < model.dateRange.interval.end {
                        Text(date.formatted(model.period == .week
                            ? .dateTime.weekday(.narrow).locale(Locale(identifier: "nb_NO"))
                            : .dateTime.day().locale(Locale(identifier: "nb_NO"))))
                            .font(AppTypography.chartLabel)
                            .foregroundStyle(AppColors.textSecondary)
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

    private var axisDates: [Date] {
        if model.period == .month {
            return model.dateRange.dates.enumerated().filter { $0.offset % 7 == 0 }.map(\.element)
        }
        return model.dateRange.dates + [model.dateRange.interval.end]
    }

    private var macroFooter: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            macro("Protein", value: model.overview.protein)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            macro("Karbo", value: model.overview.carbs)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            macro("Fett", value: model.overview.fat)
        }
        .font(AppTypography.captionEmphasis)
    }
    private func macro(_ title: String, value: Float?) -> some View {
        Text(value.map { "\(title) \(NutritionDisplay.wholeGrams($0)) g" } ?? "\(title) –")
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(value.map { "\(title == "Karbo" ? "Karbohydrater" : title) \(NutritionDisplay.wholeGrams($0)) gram" }
                                ?? "\(title) ikke tilgjengelig")
    }
}

struct CompactStepsCard: View {
    @ObservedObject var model: StepCountViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let isPaired: Bool

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 8) {
                ProgressCardHeading(title: "Aktivitet", symbol: "figure.walk", source: "Apple Helse", compact: true)
                switch model.state {
                case .loaded(let snapshot):
                    if let count = snapshot.count {
                        ProgressMetricReading(isPaired: isPaired) {
                            let layout = isPaired || dynamicTypeSize.isAccessibilitySize
                                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 6))
                            layout {
                                Text(count.formatted(.number.locale(Locale(identifier: "nb_NO"))))
                                    .font(AppTypography.metricValue)
                                    .accessibilityLabel("\(count) skritt")
                                    .accessibilityIdentifier("health-step-count-summary")
                                Text(isPaired ? "skritt totalt" : "skritt")
                                    .font(AppTypography.secondary)
                                    .accessibilityHidden(true)
                            }
                        } detail: {
                            Text("Hentet \(snapshot.updatedAt.formatted(.dateTime.hour().minute()))")
                                .font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
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
                    Text("Skritt").font(AppTypography.title)
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
                    Text("Skritt").font(AppTypography.title)
                    Text("Ikke tilkoblet i demo").font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
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
                ProgressCardHeading(title: "Vekt", symbol: "scalemass", source: overview.source.rawValue, compact: true)
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
                        Text("Sist \(latest.date.formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "nb_NO"))))")
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
    let source: String
    var compact = false
    var body: some View {
        if compact {
            stackedHeading
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    heading.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 4)
                    sourceLabel.fixedSize(horizontal: true, vertical: false)
                }
                stackedHeading
            }
        }
    }

    private var stackedHeading: some View {
        VStack(alignment: .leading, spacing: 3) {
            heading
            sourceLabel
        }
    }

    private var sourceLabel: some View {
        Text(source)
            .font(compact ? AppTypography.chartLabel : AppTypography.caption)
            .foregroundStyle(AppColors.textSecondary)
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

struct NutritionPeriodDetailView: View {
    @ObservedObject var model: ProgressViewModel
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text(model.dateRange.label).font(AppTypography.sectionTitle)
                if model.isLoading { ProgressView("Henter oversikten …") }
                if let error = model.errorMessage {
                    ErrorMessageView(error)
                    Button("Prøv igjen") { Task { await model.load(userId: auth.currentUser?.id) } }
                        .frame(minHeight: 44)
                }
                ForEach(model.summaries, id: \.date) { day in
                    CardContainer {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(day.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).locale(Locale(identifier: "nb_NO"))))
                                .font(AppTypography.sectionTitle)
                            if day.logs.isEmpty {
                                Text("Ingen registreringer").foregroundStyle(AppColors.textSecondary)
                            } else {
                                Text("\(NutritionDisplay.wholeCalories(day.totalCalories)) kcal").font(AppTypography.title)
                                Text("Protein \(NutritionDisplay.wholeGrams(day.totalProtein)) g")
                                Text("Karbohydrater \(NutritionDisplay.wholeGrams(day.totalCarbs)) g")
                                Text("Fett \(NutritionDisplay.wholeGrams(day.totalFat)) g")
                            }
                        }
                        .font(AppTypography.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }.padding(16)
        }
        .matLoggTabBarScrollClearance()
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Mat og næring").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task {
            if model.summaries.isEmpty { await model.load(userId: auth.currentUser?.id) }
        }
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
        .navigationTitle("Aktivitet").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task { await model.refresh() }
        .refreshable { await model.refresh() }
    }
}
