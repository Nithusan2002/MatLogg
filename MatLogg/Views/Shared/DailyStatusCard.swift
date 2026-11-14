import SwiftUI

struct DailyStatusCard<EnergyContent: View>: View {
    @EnvironmentObject private var waterViewModel: WaterViewModel
    let userId: UUID?
    let date: Date
    let showsEnergy: Bool
    @ViewBuilder let energyContent: () -> EnergyContent

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showsEnergy {
                energyContent()
                Rectangle()
                    .fill(AppColors.separator)
                    .frame(height: 1)
                    .accessibilityHidden(true)
            }

            WaterCardView(viewModel: waterViewModel, userId: userId, date: date, compact: true, embedded: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .matLoggCardSurface(fill: AppColors.energySurfaceGradient, cornerRadius: 24, shadowEnabled: false, borderEnabled: false)
    }
}
