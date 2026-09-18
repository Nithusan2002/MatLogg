import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MatLogg").font(AppTypography.hero).foregroundColor(AppColors.deepInk).accessibilityAddTraits(.isHeader)
                        Text("Logg mat raskt og få en rolig oversikt over dagen.").font(AppTypography.body).foregroundColor(AppColors.textSecondary)
                    }
                    CardContainer {
                        VStack(alignment: .leading, spacing: 16) {
                            authLabel("E-post")
                            TextField("navn@eksempel.no", text: $email)
                                .textContentType(.emailAddress).keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never).autocorrectionDisabled().authFieldStyle()
                            authLabel("Passord")
                            HStack(spacing: 4) {
                                Group { if showPassword { TextField("Passord", text: $password) } else { SecureField("Passord", text: $password) } }
                                    .textContentType(.password)
                                Button { showPassword.toggle() } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye").frame(width: 44, height: 44)
                                }
                                .foregroundColor(AppColors.textSecondary)
                                .accessibilityLabel(showPassword ? "Skjul passord" : "Vis passord")
                            }.authFieldStyle()
                        }
                    }
                    if let error = authViewModel.errorMessage {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(AppTypography.body).foregroundColor(AppColors.ink).padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.warmSurface, in: RoundedRectangle(cornerRadius: 12))
                    }
                    PrimaryButton(title: authViewModel.isLoading ? "Logger inn …" : "Logg inn") {
                        Task { await authViewModel.login(email: email, password: password) }
                    }.disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)
                    NavigationLink(destination: SignUpView()) {
                        Text("Ny i MatLogg? Opprett konto").font(AppTypography.bodyEmphasis).foregroundColor(AppColors.action)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }.padding(20)
            }.background(AppColors.background.ignoresSafeArea()).navigationBarBackButtonHidden(true)
        }
    }

    private func authLabel(_ title: String) -> some View {
        Text(title).font(AppTypography.bodyEmphasis).foregroundColor(AppColors.ink)
    }
}

extension View {
    fileprivate func authFieldStyle() -> some View {
        font(AppTypography.body).padding(.horizontal, 12).frame(minHeight: 52)
            .background(AppColors.mutedSurface)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.controlBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview { LoginView().environmentObject(AuthViewModel()) }
