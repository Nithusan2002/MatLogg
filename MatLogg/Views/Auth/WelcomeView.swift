import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Spacer()
                VStack(alignment: .leading, spacing: 10) {
                    Text("MatLogg")
                        .font(AppTypography.hero)
                        .foregroundColor(AppColors.deepInk)
                        .accessibilityAddTraits(.isHeader)
                    Text("Kom raskt i gang")
                        .font(AppTypography.title)
                        .foregroundColor(AppColors.ink)
                    Text("Logg mat og se oversikten din. Data lagres først på denne iPhonen.")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                }
                CardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Fungerer uten konto", systemImage: "iphone")
                        Label("Du kan logge uten nett", systemImage: "wifi.slash")
                        Label("Konto er valgfritt", systemImage: "person.crop.circle")
                    }
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.ink)
                }
                Spacer()
                PrimaryButton(title: "Fortsett på denne iPhonen") {
                    authViewModel.continueLocally()
                }
                NavigationLink {
                    LoginView()
                } label: {
                    Text("Logg inn")
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(AppColors.action)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                if let url = PrivacyConstants.privacyPolicyURL {
                    Link("Les personvernerklæringen", destination: url)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
            .background(AppColors.background.ignoresSafeArea())
        }
    }
}

#Preview {
    WelcomeView().environmentObject(AuthViewModel())
}
