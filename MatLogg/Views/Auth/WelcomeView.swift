import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var showDeletionRecovery = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "fork.knife")
                                .font(.title2.weight(.bold))
                                .foregroundColor(AppColors.onVibrant)
                                .frame(width: 52, height: 52)
                                .background(AppColors.brand, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .accessibilityHidden(true)
                            Spacer()
                            Text("MATLOGG")
                                .font(AppTypography.captionEmphasis)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        WelcomeIllustration()
                            .frame(height: 112)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("EN ROLIGERE MATLOGG")
                                .font(AppTypography.captionEmphasis)
                                .foregroundColor(AppColors.actionText)
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

                        VStack(alignment: .leading, spacing: 8) {
                            WelcomeTrustRow(title: "Fungerer uten konto", systemImage: "iphone")
                            WelcomeTrustRow(title: "Du kan logge uten nett", systemImage: "wifi.slash")
                            WelcomeTrustRow(title: "Konto er valgfritt", systemImage: "person.crop.circle")
                        }

                        Spacer(minLength: 8)

                        VStack(spacing: 4) {
                            if let error = authViewModel.errorMessage {
                                ErrorMessageView(error)
                            }
                            if authViewModel.pendingDeletion != nil {
                                Button("Fullfør lokal sletting", role: .destructive) {
                                    showDeletionRecovery = true
                                }
                                .frame(minHeight: 44)
                                .disabled(authViewModel.isDeletingAccount)
                                if let contact = URL(string: "mailto:nithusank.2002@gmail.com") {
                                    Link("Kontakt oss om kontosletting", destination: contact)
                                        .frame(minHeight: 44)
                                }
                            }
                            PrimaryButton(title: "Fortsett på denne iPhonen") {
                                authViewModel.continueLocally()
                            }
                            .accessibilityIdentifier("welcome-continue-local")
                            .disabled(authViewModel.pendingDeletion != nil)

                            NavigationLink {
                                LoginView()
                            } label: {
                                Text("Logg inn")
                                    .font(AppTypography.bodyEmphasis)
                                    .foregroundColor(AppColors.ink)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(AppColors.surface, in: Capsule())
                                    .overlay(Capsule().stroke(AppColors.separator, lineWidth: 1))
                            }
                            .accessibilityIdentifier("welcome-login")
                            .disabled(authViewModel.pendingDeletion != nil)

                            if let url = PrivacyConstants.privacyPolicyURL {
                                Link("Les personvernerklæringen", destination: url)
                                    .font(AppTypography.captionEmphasis)
                                    .foregroundColor(AppColors.actionText)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .accessibilityIdentifier("welcome-privacy")
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .frame(maxWidth: 560, minHeight: geometry.size.height, alignment: .top)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
                .background(AppColors.background.ignoresSafeArea())
            }
        }
        .alert("Fullfør lokal sletting?", isPresented: $showDeletionRecovery) {
            Button("Slett lokale data", role: .destructive) {
                Task { await authViewModel.finishPendingLocalDeletion() }
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text(authViewModel.pendingDeletion?.serverConfirmed == true
                 ? "Serveren har bekreftet sletteforespørselen. Fjern nå de gjenværende dataene fra denne iPhonen."
                 : "Dette fjerner profildata fra denne iPhonen. Det bekrefter ikke sletting på serveren. Kontakt oss hvis kontostatus er usikker.")
        }
    }
}

private struct WelcomeTrustRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label {
            Text(title)
                .font(AppTypography.bodyEmphasis)
                .foregroundColor(AppColors.ink)
        } icon: {
            Image(systemName: systemImage)
                .foregroundColor(AppColors.actionText)
                .frame(width: 36, height: 36)
                .background(AppColors.warmSurface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
}

struct WelcomeIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppColors.warmSurface)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.surface)
                .frame(width: 86, height: 78)
                .rotationEffect(.degrees(7))
                .overlay {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach([32.0, 52.0, 44.0], id: \.self) { width in
                            Capsule()
                                .fill(AppColors.separator)
                                .frame(width: width, height: 6)
                        }
                    }
                    .rotationEffect(.degrees(7))
                }
            Circle()
                .fill(AppColors.accent)
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(AppColors.surface, lineWidth: 6))
                .offset(x: -72, y: -20)
            Capsule()
                .fill(AppColors.success)
                .frame(width: 54, height: 24)
                .rotationEffect(.degrees(-28))
                .offset(x: 72, y: 24)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    WelcomeView().environmentObject(AuthViewModel())
}
