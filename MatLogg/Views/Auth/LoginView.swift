import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    Text("MatLogg")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.blue)
                    
                    Text("Din personlige kaloriteller")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                .padding(.bottom, 30)
                
                VStack(spacing: 12) {
                    TextField("E-post", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    HStack {
                        if showPassword {
                            TextField("Passord", text: $password)
                                .textContentType(.password)
                                .padding(12)
                        } else {
                            SecureField("Passord", text: $password)
                                .textContentType(.password)
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
                
                Button(action: loginAction) {
                    if appState.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Logg inn")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(appState.isLoading || email.isEmpty || password.isEmpty)
                
                Divider()
                    .padding(.vertical, 8)
                
                Button(action: {}) {
                    HStack(spacing: 12) {
                        Image(systemName: "applelogo")
                        Text("Logg inn med Apple")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Spacer()
                
                NavigationLink(destination: SignUpView()) {
                    HStack(spacing: 4) {
                        Text("Har du ikke konto?")
                            .foregroundColor(.secondary)
                        Text("Registrer deg")
                            .foregroundColor(.blue)
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }
            }
            .padding(20)
            .navigationBarBackButtonHidden(true)
        }
    }
    
    private func loginAction() {
        Task {
            await appState.loginWithEmail(email: email, password: password)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AppState())
}
