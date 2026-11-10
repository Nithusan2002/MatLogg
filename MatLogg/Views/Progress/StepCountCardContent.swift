import Charts
import SwiftUI

struct StepCountCardContent: View {
    @ObservedObject var model: StepCountViewModel
    let dateRange: ProgressDateRange
    let onOpenHealthSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(dateRange.label) · Apple Helse")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
                .accessibilityIdentifier("health-steps-period")
            switch model.state {
            case .notConnected:
                if !model.isEnabled {
                    Text("Slå på under Profil → Innstillinger → Apple Helse.")
                    AppleHealthSettingsShortcut(action: onOpenHealthSettings)
                }
            case .loading:
                ProgressView("Henter skritt …")
            case .loaded(let snapshot):
                if let count = snapshot.count {
                    Text(count.formatted(.number.locale(Locale(identifier: "nb_NO"))))
                        .font(AppTypography.heroValue)
                        .accessibilityLabel("\(count) skritt")
                        .accessibilityIdentifier("health-step-count")
                }
                Text("skritt totalt").font(AppTypography.body)
                breakdownChart(snapshot)
                Text("Hentet \(snapshot.updatedAt.formatted(.dateTime.hour().minute().locale(Locale(identifier: "nb_NO"))))")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                if snapshot.isExampleData { Text("QA – eksempeldata").font(AppTypography.caption) }
            case .noData:
                Text("Ingen skrittdata tilgjengelig").font(AppTypography.bodyEmphasis)
                Text("Det kan mangle registreringer eller lesetilgang. Kontroller MatLoggs tilgang til skritt i Helse, og prøv igjen.")
            case .failed:
                Text("Kunne ikke hente skritt.")
                Button("Prøv igjen") { Task { await model.refresh() } }
                    .frame(minHeight: 44)
            case .unavailable:
                Text("Apple Helse er ikke tilgjengelig på denne enheten.")
            case .demo:
                Text("Apple Helse kobles ikke til i demomodus. Bytt til din egen profil for å vise skritt fra denne iPhonen.")
            }
        }
        .font(AppTypography.body)
        .foregroundStyle(AppColors.deepInk)
        .tint(AppColors.action)
    }

    private func breakdownChart(_ snapshot: StepCountSnapshot) -> some View {
        let isHourly = snapshot.granularity == .hour
        let title = isHourly ? "Skritt per time" : "Skritt per dag"
        let norwegian = Locale(identifier: "nb_NO")
        let axisFormat = isHourly ? Date.FormatStyle.dateTime.hour().minute().locale(norwegian)
            : .dateTime.day().month(.abbreviated).locale(norwegian)
        let accessibilityFormat = isHourly ? axisFormat : .dateTime.day().month(.wide).locale(norwegian)
        return VStack(alignment: .leading, spacing: 6) {
            Text(title).font(AppTypography.bodyEmphasis)
            Chart(snapshot.buckets) { bucket in
                BarMark(
                    x: .value("Tid", bucket.date, unit: snapshot.granularity.component),
                    y: .value("Skritt", bucket.steps)
                )
                .foregroundStyle(AppColors.action)
                .accessibilityLabel(bucket.date.formatted(accessibilityFormat))
                .accessibilityValue("\(Int(bucket.steps)) skritt")
            }
            .chartXScale(domain: snapshot.range.start...snapshot.range.end)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) {
                    AxisValueLabel(format: axisFormat)
                }
            }
            .frame(height: 128)
            .accessibilityLabel(title)
            if !isHourly {
                Text("\(snapshot.buckets.count) av \(dateRange.dates.count) dager med data")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }
}
