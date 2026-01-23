import SwiftUI
import SafariServices

struct PrivacyChoicesView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var showPolicy = false
    @State private var showChoices = false
    
    var body: some View {
        ScrollView {
            PrivacyChoicesContentView(
                onOpenPolicy: { showPolicy = true },
                onOpenChoices: PrivacyConstants.privacyChoicesURL == nil ? nil : { showChoices = true }
            )
            .environmentObject(appState)
            .padding(20)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Personvern & valg")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            appState.hasSeenPrivacyChoices = true
        }
        .sheet(isPresented: $showPolicy) {
            SafariView(url: PrivacyConstants.privacyPolicyURL)
        }
        .sheet(isPresented: $showChoices) {
            if let url = PrivacyConstants.privacyChoicesURL {
                SafariView(url: url)
            }
        }
    }
    
}

struct PrivacyChoicesContentView: View {
    @EnvironmentObject var appState: AppState
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
                Text("Personvern & valg")
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
                    PrivacyBullet(text: "Vi lagrer dataene dine for å vise loggen din på tvers av enheter.")
                    PrivacyBullet(text: "Kamera brukes bare når du skanner strekkoder.")
                    PrivacyBullet(text: "Du kan laste ned eller slette dataene dine i Profil.")
                    PrivacyBullet(text: "Valgfrie rapporter kan hjelpe oss å gjøre appen mer stabil.")
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
                Toggle("Del anonym bruksstatistikk", isOn: $appState.analyticsEnabled)
                Toggle("Del anonyme krasjrapporter", isOn: $appState.crashReportsEnabled)
            }
            .padding(16)
            .background(AppColors.surface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.separator, lineWidth: 1)
            )
            
            Text("Dette er valgfritt. Du kan skru av/på senere.")
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
