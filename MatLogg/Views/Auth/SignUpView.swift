import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    
    var isFormValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        password.count >= 8
    }
    
    var body: some View {
        Group {
            if let pendingEmail = authViewModel.pendingVerificationEmail {
                verificationContent(email: pendingEmail)
            } else {
                registrationContent
            }
        }
        .padding(20)
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }

    private var registrationContent: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Tilbake")
                        }
                        .foregroundColor(AppColors.action)
                    }
                    Spacer()
                }
                
                Text("Registrer deg")
                    .font(AppTypography.hero)
                    .foregroundColor(AppColors.deepInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, 10)
            
            ScrollView {
                VStack(spacing: 12) {
                    TextField("E-post", text: $email)
                        .textContentType(.emailAddress)
                        .foregroundColor(AppColors.ink)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(12)
                        .background(AppColors.mutedSurface)
                        .cornerRadius(12)
                    
                    HStack {
                        if showPassword {
                            TextField("Passord (min. 8 tegn)", text: $password)
                                .foregroundColor(AppColors.ink)
                                .padding(12)
                        } else {
                            SecureField("Passord (min. 8 tegn)", text: $password)
                                .foregroundColor(AppColors.ink)
                                .padding(12)
                        }
                        
                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.trailing, 12)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel(showPassword ? "Skjul passord" : "Vis passord")
                    }
                    .background(AppColors.mutedSurface)
                    .cornerRadius(12)
                    
                    SecureField("Gjenta passord", text: $confirmPassword)
                        .textContentType(.password)
                        .foregroundColor(AppColors.ink)
                        .padding(12)
                        .background(AppColors.mutedSurface)
                        .cornerRadius(12)
                    
                    if !password.isEmpty && password != confirmPassword {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle")
                            Text("Passordene stemmer ikke overens")
                                .font(.caption)
                        }
                        .foregroundColor(AppColors.ink)
                        .padding(12)
                        .background(AppColors.warmSurface)
                        .cornerRadius(12)
                    }
                    
                    if password.count < 8 && !password.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle")
                            Text("Passord må være minst 8 tegn")
                                .font(.caption)
                        }
                        .foregroundColor(AppColors.ink)
                        .padding(12)
                        .background(AppColors.warmSurface)
                        .cornerRadius(12)
                    }
                    
                    if let error = authViewModel.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.circle")
                            Text(error)
                                .font(.caption)
                        }
                        .foregroundColor(AppColors.ink)
                        .padding(12)
                        .background(AppColors.warmSurface)
                        .cornerRadius(12)
                    }
                }
            }
            
            Button(action: signupAction) {
                if authViewModel.isLoading {
                    ProgressView()
                        .tint(AppColors.onVibrant)
                } else {
                    Text("Registrer deg")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .frame(minHeight: 56)
            .background(AppColors.brand)
            .foregroundColor(AppColors.onVibrant)
            .clipShape(Capsule())
            .disabled(!isFormValid || authViewModel.isLoading)
        }
    }

    private func verificationContent(email: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "envelope.badge")
                .font(.system(size: 48, weight: .semibold))
                .foregroundColor(AppColors.action)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("Sjekk e-posten din")
                    .font(AppTypography.hero)
                    .foregroundColor(AppColors.deepInk)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("Vi har sendt en bekreftelseslenke til \(email). Åpne lenken på denne iPhonen for å fullføre registreringen.")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let message = authViewModel.verificationMessage {
                Label(message, systemImage: "checkmark.circle")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.ink)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.mutedSurface, in: RoundedRectangle(cornerRadius: 12))
            }

            if let error = authViewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.ink)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.warmSurface, in: RoundedRectangle(cornerRadius: 12))
            }

            PrimaryButton(title: authViewModel.isLoading ? "Sender …" : "Send på nytt") {
                Task { await authViewModel.resendEmailVerification() }
            }
            .disabled(authViewModel.isLoading)

            Button("Tilbake") {
                authViewModel.dismissEmailVerification()
            }
            .font(AppTypography.bodyEmphasis)
            .foregroundColor(AppColors.action)
            .frame(minHeight: 44)

            Spacer()
        }
    }
    
    private func signupAction() {
        Task {
            await authViewModel.signUp(
                email: email,
                password: password
            )
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView()
            .environmentObject(AuthViewModel())
    }
}
