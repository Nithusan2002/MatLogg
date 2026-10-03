import AuthenticationServices
import CryptoKit
import Security
import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var appleNonce = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Logg inn")
                        .font(AppTypography.hero)
                        .foregroundColor(AppColors.deepInk)
                        .accessibilityAddTraits(.isHeader)
                    Text("Konto er valgfritt og brukes til innlogging. Matloggene dine lagres bare på denne enheten, uten skybackup.")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                }

                SignInWithAppleButton(.signIn) { request in
                    let nonce = Self.randomNonceString()
                    appleNonce = nonce
                    request.requestedScopes = [.email]
                    request.nonce = Self.sha256(nonce)
                } onCompletion: { result in
                    handleAppleResult(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .disabled(authViewModel.isLoading)
                .accessibilityLabel("Logg inn med Apple")

                HStack {
                    Rectangle().fill(AppColors.separator).frame(height: 1)
                    Text("eller").font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
                    Rectangle().fill(AppColors.separator).frame(height: 1)
                }

                CardContainer {
                    VStack(alignment: .leading, spacing: 14) {
                        authLabel("E-post")
                        TextField("navn@eksempel.no", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .authFieldStyle()
                        authLabel("Passord")
                        HStack(spacing: 4) {
                            Group {
                                if showPassword { TextField("Passord", text: $password) }
                                else { SecureField("Passord", text: $password) }
                            }
                            .textContentType(.password)
                            Button { showPassword.toggle() } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye").frame(width: 44, height: 44)
                            }
                            .foregroundColor(AppColors.textSecondary)
                            .accessibilityLabel(showPassword ? "Skjul passord" : "Vis passord")
                        }
                        .authFieldStyle()
                    }
                }

                if let error = authViewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.ink)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.warmSurface, in: RoundedRectangle(cornerRadius: 12))
                }

                PrimaryButton(title: authViewModel.isLoading ? "Logger inn …" : "Logg inn med e-post") {
                    Task { await authViewModel.login(email: email, password: password) }
                }
                .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)

                NavigationLink(destination: SignUpView()) {
                    Text("Ny i MatLogg? Opprett konto med e-post")
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(AppColors.action)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(20)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Konto")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Knytt lokale data til kontoen?", isPresented: linkAlertBinding) {
            Button("Knytt til konto") { Task { await authViewModel.confirmLocalDataLink() } }
            Button("Avbryt", role: .cancel) { authViewModel.cancelLocalDataLink() }
        } message: {
            Text(localDataSummaryText)
        }
    }

    private var linkAlertBinding: Binding<Bool> {
        Binding(
            get: { authViewModel.pendingLocalDataSummary != nil },
            set: { if !$0, authViewModel.pendingLocalDataSummary != nil { authViewModel.cancelLocalDataLink() } }
        )
    }

    private var localDataSummaryText: String {
        guard let summary = authViewModel.pendingLocalDataSummary else { return "" }
        return "Denne iPhonen har \(summary.logs) loggføringer, \(summary.favorites) favoritter, \(summary.savedMeals) lagrede måltider, \(summary.products) egne produkter og \(summary.weights) vektregistreringer. De knyttes til kontoen først når du bekrefter, og blir fortsatt lagret bare på denne enheten. Dette gir ingen skybackup."
    }

    private func authLabel(_ title: String) -> some View {
        Text(title).font(AppTypography.bodyEmphasis).foregroundColor(AppColors.ink)
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else {
                authViewModel.reportAuthenticationError("Apple-innloggingen manglet en gyldig identitet. Prøv igjen.")
                return
            }
            let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
            let nonce = appleNonce
            Task { await authViewModel.loginWithApple(identityToken: identityToken, authorizationCode: code, nonce: nonce) }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                authViewModel.reportAuthenticationError("Kunne ikke logge inn med Apple. Prøv igjen.")
            }
        }
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func randomNonceString(length: Int = 32) -> String {
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var bytes = [UInt8](repeating: 0, count: 16)
            guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { return UUID().uuidString }
            for byte in bytes where byte < characters.count {
                result.append(characters[Int(byte)])
                remaining -= 1
                if remaining == 0 { break }
            }
        }
        return result
    }
}

extension View {
    fileprivate func authFieldStyle() -> some View {
        font(AppTypography.body)
            .padding(.horizontal, 12)
            .frame(minHeight: 52)
            .background(AppColors.mutedSurface)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.controlBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack { LoginView().environmentObject(AuthViewModel()) }
}
