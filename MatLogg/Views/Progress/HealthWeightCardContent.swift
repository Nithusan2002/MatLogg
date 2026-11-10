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
                        WeightPeriodMeasurements(overview: snapshot.overview)
                        if snapshot.isExampleData {
                            Text("QA – eksempeldata").font(AppTypography.caption)
                        }
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
}

struct WeightPeriodMeasurements: View {
    let overview: ProgressWeightOverview

    var body: some View {
        if let latest = overview.latest {
            if overview.showsEarlierMeasurement {
                Text("Siste måling før perioden")
                    .font(AppTypography.captionEmphasis)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Text(weight(latest))
                .font(AppTypography.heroValue)
                .accessibilityIdentifier(overview.source == .appleHealth ? "health-weight-latest" : "local-weight-latest")
            let dateLabel = date(latest)
            Text(overview.source == .appleHealth ? "Målt \(dateLabel)" : "Registrert \(dateLabel)")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
        } else {
            Text("Ingen målinger i valgt periode.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
        }
        if overview.points.count > 1 {
            Text("Tidligere målinger i perioden")
                .font(AppTypography.captionEmphasis)
                .foregroundStyle(AppColors.textSecondary)
            ForEach(overview.points.reversed().dropFirst()) { measurement in
                Divider()
                Text("\(date(measurement)) · \(weight(measurement))")
            }
        }
    }

    private func weight(_ measurement: ProgressWeightMeasurement) -> String {
        "\(measurement.weightKg.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "nb_NO")))) kg"
    }

    private func date(_ measurement: ProgressWeightMeasurement) -> String {
        let style = Date.FormatStyle.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "nb_NO"))
        return measurement.date.formatted(overview.source == .appleHealth ? style.hour().minute() : style)
    }
}
