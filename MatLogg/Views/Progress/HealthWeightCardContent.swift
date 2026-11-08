import SwiftUI

struct HealthWeightCardContent: View {
    @ObservedObject var model: HealthWeightViewModel
    let dateRange: ProgressDateRange
    let onOpenHealthSettings: () -> Void

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                ProgressCardHeading(title: "Vekt fra Apple Helse", symbol: "heart", detail: dateRange.label)
                switch model.state {
                case .notConnected:
                    if !model.isEnabled {
                        Text("Du kan slå på vekt fra Apple Helse i Innstillinger.")
                        AppleHealthSettingsShortcut(action: onOpenHealthSettings)
                    }
                case .loading:
                    ProgressView("Henter vekt …")
                case .loaded:
                    if let snapshot = model.snapshot(for: dateRange.interval) {
                        measurements(snapshot)
                    }
                case .noData:
                    Text("Ingen vektdata tilgjengelig").font(AppTypography.bodyEmphasis)
                    Text("Det kan mangle vektmålinger eller lesetilgang. Du kan sjekke MatLoggs tilgang til vekt i Helse.")
                case .failed:
                    Text("Kunne ikke hente vekt.")
                    Button("Prøv igjen") { Task { await model.refresh() } }
                        .frame(minHeight: 44)
                case .unavailable:
                    Text("Apple Helse er ikke tilgjengelig på denne enheten.")
                case .demo:
                    Text("Apple Helse er tilgjengelig fra din egen profil.")
                }
            }
            .font(AppTypography.body)
            .foregroundStyle(AppColors.deepInk)
            .tint(AppColors.action)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private func measurements(_ snapshot: HealthWeightSnapshot) -> some View {
        if let latest = snapshot.overview.latest {
            Text(weight(latest))
                .font(AppTypography.heroValue)
                .accessibilityIdentifier("health-weight-latest")
            Text("Målt \(date(latest))")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        if snapshot.overview.points.isEmpty {
            Text("Ingen målinger i valgt periode.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
        } else if snapshot.overview.points.count > 1 {
            Text("Tidligere målinger i perioden")
                .font(AppTypography.captionEmphasis)
                .foregroundStyle(AppColors.textSecondary)
            ForEach(Array(snapshot.overview.points.reversed().dropFirst())) { measurement in
                Divider()
                Text("\(date(measurement)) · \(weight(measurement))")
            }
        }
        if snapshot.isExampleData {
            Text("QA – eksempeldata").font(AppTypography.caption)
        }
    }

    private func weight(_ measurement: ProgressWeightMeasurement) -> String {
        "\(measurement.weightKg.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "nb_NO")))) kg"
    }

    private func date(_ measurement: ProgressWeightMeasurement) -> String {
        measurement.date.formatted(.dateTime.day().month(.abbreviated).year().hour().minute().locale(Locale(identifier: "nb_NO")))
    }
}
