import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
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
                        .foregroundColor(.blue)
                    }
                    Spacer()
                }
                
                Text("Registrer deg")
                    .font(.system(size: 28, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, 10)
            
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        TextField("Fornavn", text: $firstName)
                            .textContentType(.givenName)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        TextField("Etternavn", text: $lastName)
                            .textContentType(.familyName)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    TextField("E-post", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
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
                                .foregroundColor(.secondary)
                                .padding(.trailing, 12)
                        }
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    SecureField("Gjenta passord", text: $confirmPassword)
                        .textContentType(.password)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    if !password.isEmpty && password != confirmPassword {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle")
                            Text("Passordene stemmer ikke overens")
                                .font(.caption)
                        }
                        .foregroundColor(.red)
                        .padding(12)
                        .background(Color(.systemRed).opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    if password.count < 8 && !password.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle")
                            Text("Passord må være minst 8 tegn")
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                        .padding(12)
                        .background(Color(.systemOrange).opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    if let error = appState.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.circle")
                            Text(error)
                                .font(.caption)
                        }
                        .foregroundColor(.red)
                        .padding(12)
                        .background(Color(.systemRed).opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
            
            Button(action: signupAction) {
                if appState.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Registrer deg")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .disabled(!isFormValid || appState.isLoading)
        }
        .padding(20)
        .navigationBarBackButtonHidden(true)
    }
    
    private func signupAction() {
        Task {
            await appState.signupWithEmail(
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
            .environmentObject(AppState())
    }
}
