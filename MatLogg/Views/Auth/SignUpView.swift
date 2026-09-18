import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var showPassword = false
    
    var isFormValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        password.count >= 8
    }
    
    var body: some View {
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
                    HStack(spacing: 12) {
                        TextField("Fornavn", text: $firstName)
                            .textContentType(.givenName)
                            .padding(12)
                            .background(AppColors.mutedSurface)
                            .cornerRadius(12)
                        
                        TextField("Etternavn", text: $lastName)
                            .textContentType(.familyName)
                            .padding(12)
                            .background(AppColors.mutedSurface)
                            .cornerRadius(12)
                    }
                    
                    TextField("E-post", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(12)
                        .background(AppColors.mutedSurface)
                        .cornerRadius(12)
                    
                    HStack {
                        if showPassword {
                            TextField("Passord (min. 8 tegn)", text: $password)
                                .padding(12)
                        } else {
                            SecureField("Passord (min. 8 tegn)", text: $password)
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
                        .tint(.white)
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
        .padding(20)
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }
    
    private func signupAction() {
        Task {
            await authViewModel.signUp(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName
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
