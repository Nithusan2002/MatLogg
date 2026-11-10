import SwiftUI

struct CompactWorkoutCard: View {
    @ObservedObject var model: HealthWorkoutViewModel
    let dateRange: ProgressDateRange

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 8) {
                ProgressCardHeading(title: "Treningsøkter", symbol: "dumbbell", opensDetails: true)
                if let snapshot = model.snapshot(for: dateRange.interval) {
                    Text(snapshot.workouts.count == 1 ? "1 økt i perioden" : "\(snapshot.workouts.count) økter i perioden")
                        .font(AppTypography.bodyEmphasis)
                    ForEach(snapshot.workouts.prefix(2)) { workout in
                        Divider().overlay(AppColors.separator)
                        WorkoutRow(workout: workout, showsTime: false)
                    }
                } else {
                    WorkoutStatus(state: model.state)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(AppColors.deepInk)
    }
}

struct WorkoutDetailView: View {
    @ObservedObject var model: HealthWorkoutViewModel
    let dateRange: ProgressDateRange
    let onOpenHealthSettings: () -> Void

    var body: some View {
        ScrollView {
            CardContainer {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ProgressCardHeading(title: dateRange.label, symbol: "dumbbell", detail: "Apple Helse")
                    if let snapshot = model.snapshot(for: dateRange.interval) {
                        ForEach(snapshot.workouts) { workout in
                            Divider().overlay(AppColors.separator)
                            WorkoutRow(workout: workout, showsTime: true)
                        }
                    } else {
                        WorkoutStatus(state: model.state)
                        if model.state == .notConnected {
                            AppleHealthSettingsShortcut(action: onOpenHealthSettings)
                        } else if model.state == .failed {
                            Button("Prøv igjen") { Task { await model.refresh() } }
                                .font(AppTypography.bodyEmphasis)
                                .foregroundStyle(AppColors.actionText)
                                .frame(minHeight: 44)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .foregroundStyle(AppColors.deepInk)
        .matLoggTabBarScrollClearance()
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Treningsøkter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .refreshable { await model.refresh() }
    }
}

private struct WorkoutStatus: View {
    let state: HealthWorkoutViewModel.State

    var body: some View {
        Group {
            switch state {
            case .loading, .loaded: ProgressView("Henter treningsøkter …")
            case .notConnected: Text("Slå på under Profil → Innstillinger → Apple Helse.")
            case .noData: Text("Ingen treningsøkter tilgjengelig i perioden")
            case .failed: Text("Kunne ikke hente treningsøkter")
            case .unavailable: Text("Apple Helse er utilgjengelig")
            case .demo: Text("Ikke tilkoblet i demo")
            }
        }
        .font(AppTypography.secondary)
        .foregroundStyle(AppColors.textSecondary)
    }
}

private struct WorkoutRow: View {
    let workout: HealthWorkoutSummary
    let showsTime: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                sessionLabel.fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
                duration.fixedSize(horizontal: true, vertical: false)
            }
            VStack(alignment: .leading, spacing: 4) {
                sessionLabel
                duration
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("workout-row")
    }

    private var sessionLabel: some View {
        let date = Date.FormatStyle.dateTime.day().month(.abbreviated).locale(norwegian)
        return Group {
            if showsTime {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.title)
                    Text(workout.startDate.formatted(date.hour().minute()))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            } else {
                let shortDate = Text(workout.startDate.formatted(date))
                    .foregroundStyle(AppColors.textSecondary)
                Text("\(Text(workout.title)) · \(shortDate)")
            }
        }
        .font(AppTypography.body)
    }

    private var duration: some View {
        Text(durationLabel)
            .font(AppTypography.bodyEmphasis)
            .monospacedDigit()
    }

    private var norwegian: Locale { Locale(identifier: "nb_NO") }

    private var durationLabel: String {
        guard let minutes = Int(exactly: (workout.duration / 60).rounded(.down)), minutes >= 0 else {
            return "Ukjent varighet"
        }
        if minutes < 1 { return "Under 1 min" }
        if minutes < 60 { return "\(minutes) min" }
        let hours = (minutes / 60).formatted(.number.locale(norwegian))
        let remaining = minutes % 60
        return remaining == 0 ? "\(hours) t" : "\(hours) t \(remaining) min"
    }
}
