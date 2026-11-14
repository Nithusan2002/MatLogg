import SwiftUI
import SafariServices

struct PrivacyChoicesView: View {
    @EnvironmentObject var preferencesViewModel: PreferencesViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showPolicy = false
    @State private var showChoices = false
    
    var body: some View {
        ScrollView {
            PrivacyChoicesContentView(
                onOpenPolicy: PrivacyConstants.privacyPolicyURL == nil ? nil : { showPolicy = true },
                onOpenChoices: PrivacyConstants.privacyChoicesURL == nil ? nil : { showChoices = true }
            )
            .padding(20)
        }
        .matLoggTabBarScrollClearance()
        .background(AppColors.background.ignoresSafeArea())
        .toolbar(.visible, for: .navigationBar)
        .navigationTitle("Personvern og valg")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            preferencesViewModel.hasSeenPrivacyChoices = true
        }
        .sheet(isPresented: $showPolicy) {
            if let url = PrivacyConstants.privacyPolicyURL {
                SafariView(url: url)
            }
        }
        .sheet(isPresented: $showChoices) {
            if let url = PrivacyConstants.privacyChoicesURL {
                SafariView(url: url)
            }
        }
    }
    
}

struct PrivacyChoicesContentView: View {
    @EnvironmentObject var preferencesViewModel: PreferencesViewModel
    let onOpenPolicy: (() -> Void)?
    let onOpenChoices: (() -> Void)?
    
    init(
        onOpenPolicy: (() -> Void)? = nil,
        onOpenChoices: (() -> Void)? = nil
    ) {
        self.onOpenPolicy = onOpenPolicy
        self.onOpenChoices = onOpenChoices
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CardContainer {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Kort forklart")
                        .font(AppTypography.sectionTitle)
                        .accessibilityAddTraits(.isHeader)
                    PrivacyBullet(text: "Data lagres på denne iPhonen. Konto er valgfritt og gir foreløpig ikke skybackup.")
                    PrivacyBullet(text: "Kamera brukes når du skanner strekkoder eller velger å ta et produktbilde.")
                    PrivacyBullet(text: "Eksport og kontosletting finnes under Profil → Innstillinger.")
                    PrivacyBullet(text: "Vekt, høyde og fødselsdato er valgfrie.")
                }
            }
            CardContainer {
                VStack(alignment: .leading, spacing: 0) {
                    documentRow("Personvernerklæring", action: onOpenPolicy)
                    if PrivacyConstants.privacyChoicesURL != nil {
                        Divider().overlay(AppColors.separator)
                        documentRow("Dine personvernvalg", action: onOpenChoices)
                    }
                }
            }
            Text("Dokumentene åpnes i nettleseren i appen.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
            CardContainer {
                Label {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ingen deling av bruksdata")
                            .font(AppTypography.bodyEmphasis)
                        Text("Bruksstatistikk og krasjrapporter deles ikke i denne versjonen.")
                            .font(AppTypography.secondary)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                } icon: {
                    Image(systemName: "hand.raised")
                        .foregroundStyle(AppColors.textSecondary)
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("privacy-telemetry-status")
            }
        }
        .foregroundStyle(AppColors.ink)
    }

    private func documentRow(_ title: String, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 12) {
                Text(title)
                    .font(AppTypography.bodyEmphasis)
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .foregroundStyle(action == nil ? AppColors.textSecondary : AppColors.actionText)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }

}

private struct PrivacyBullet: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(AppColors.textSecondary)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            Text(text)
                .font(AppTypography.body)
                .foregroundColor(AppColors.ink)
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
