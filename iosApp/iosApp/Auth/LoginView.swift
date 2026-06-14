import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @StateObject private var vm   = AuthViewModel()
    @State private var email      = ""
    @State private var password   = ""
    @State private var isSignUp   = false
    @State private var showPassword = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Logo / title
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)
                    Text("TickTrust")
                        .font(.largeTitle).fontWeight(.bold)
                    Text("Parental time control")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 48)

                // Apple sign-in
                SignInWithAppleButton(
                    isSignUp ? .signUp : .signIn,
                    onRequest:    { vm.prepareAppleRequest($0) },
                    onCompletion: { result in
                        Task {
                            switch result {
                            case .success(let auth):
                                if let cred = auth.credential as? ASAuthorizationAppleIDCredential {
                                    await vm.handleAppleCredential(cred)
                                }
                            case .failure(let error):
                                // User cancelled — no error needed
                                if (error as? ASAuthorizationError)?.code != .canceled {
                                    vm.errorMessage = error.localizedDescription
                                    vm.showError    = true
                                }
                            }
                        }
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .cornerRadius(10)

                // Divider
                HStack {
                    Rectangle().fill(Color(.separator)).frame(height: 1)
                    Text("or").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8)
                    Rectangle().fill(Color(.separator)).frame(height: 1)
                }

                // Email / password form
                VStack(spacing: 14) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

                    HStack {
                        Group {
                            if showPassword {
                                TextField("Password", text: $password)
                            } else {
                                SecureField("Password", text: $password)
                            }
                        }
                        .textContentType(isSignUp ? .newPassword : .password)
                        .autocapitalization(.none)

                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

                    Button {
                        Task {
                            if isSignUp {
                                await vm.signUp(email: email, password: password)
                            } else {
                                await vm.signIn(email: email, password: password)
                            }
                        }
                    } label: {
                        Group {
                            if vm.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isSignUp ? "Create account" : "Sign in")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .cornerRadius(10)
                    .disabled(vm.isLoading || email.isEmpty || password.isEmpty)
                }

                // Toggle sign in / sign up
                Button {
                    withAnimation { isSignUp.toggle() }
                } label: {
                    Text(isSignUp
                         ? "Already have an account? **Sign in**"
                         : "New here? **Create account**")
                        .font(.subheadline)
                }
                .tint(.blue)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .alert(isSignUp ? "Almost there!" : "Error",
               isPresented: $vm.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage)
        }
    }
}
