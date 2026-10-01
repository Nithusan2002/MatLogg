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
            VStack(alignment: .leading, spacing: 8) {
                Text("Personvern og valg")
                    .font(AppTypography.title)
                    .foregroundColor(AppColors.ink)
                Text("Du bestemmer. Du kan endre dette når som helst.")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Kort forklart")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                
                VStack(alignment: .leading, spacing: 10) {
                    PrivacyBullet(text: "Data lagres først på enheten. Konto er valgfritt. Synk og gjenoppretting avhenger av hvilke funksjoner som er tilgjengelige.")
                    PrivacyBullet(text: "Kamera brukes bare når du skanner strekkoder.")
                    PrivacyBullet(text: "Du kan eksportere data under Profil → Innstillinger. Bruker du konto, finner du også kontosletting der.")
                    PrivacyBullet(text: "Du velger selv om du vil oppgi vekt, høyde og fødselsdato.")
                }
            }
            .padding(16)
            .background(AppColors.surface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.separator, lineWidth: 1)
            )
            
            VStack(alignment: .leading, spacing: 12) {
                if let onOpenPolicy {
                    Button(action: onOpenPolicy) {
                        HStack {
                            Text("Personvernerklæring")
                                .foregroundColor(AppColors.ink)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                } else {
                    HStack {
                        Text("Personvernerklæring")
                            .foregroundColor(AppColors.ink)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                if PrivacyConstants.privacyChoicesURL != nil {
                    if let onOpenChoices {
                        Button(action: onOpenChoices) {
                            HStack {
                                Text("Dine personvernvalg")
                                    .foregroundColor(AppColors.ink)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    } else {
                        HStack {
                            Text("Dine personvernvalg")
                                .foregroundColor(AppColors.ink)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                
                Text("Lenker åpnes i Safari.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(16)
            .background(AppColors.surface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.separator, lineWidth: 1)
            )
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Del anonym bruksstatistikk", isOn: $preferencesViewModel.analyticsEnabled)
                    .disabled(true)
                Toggle("Del anonyme krasjrapporter", isOn: $preferencesViewModel.crashReportsEnabled)
                    .disabled(true)
            }
            .padding(16)
            .background(AppColors.surface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.separator, lineWidth: 1)
            )
            
            Text("Deling av bruksstatistikk og krasjrapporter er ikke tilgjengelig i denne versjonen.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
        }
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
