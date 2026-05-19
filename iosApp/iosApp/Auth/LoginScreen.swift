import SwiftUI
import SkeletonApp

struct LoginScreen: View {
    @StateObject private var owner = IosViewModelStoreOwner()
    @State private var uiState: LoginUiState = LoginUiStateEditing(
        email: "",
        password: "",
        emailError: nil,
        passwordError: nil,
        isSubmitEnabled: false
    )
    @State private var stateJob: Kotlinx_coroutines_coreJob?
    @Environment(\.appTheme) private var theme
    let onSuccess: () -> Void

    var body: some View {
        let vm: LoginViewModel = LoginViewModelHelperKt.createLoginViewModel(
            store: owner.viewModelStore
        )
        ZStack {
            stateContent(vm: vm)
        }
        .alert(
            "Login failed",
            isPresented: .constant(uiState is LoginUiStateFailed),
            actions: {
                Button("OK") { vm.onErrorDismissed() }
            },
            message: {
                if let failed = uiState as? LoginUiStateFailed {
                    Text(failed.message)
                }
            }
        )
        .task {
            stateJob = LoginViewModelHelperKt.subscribeLoginState(vm: vm) { state in
                uiState = state
                if state is LoginUiStateSucceeded {
                    onSuccess()
                    vm.onNavigatedToDashboard()
                }
            }
        }
        .onDisappear {
            stateJob?.cancel(cause: nil)
            stateJob = nil
        }
        .navigationTitle("Sign in")
    }

    @ViewBuilder
    private func stateContent(vm: LoginViewModel) -> some View {
        if let editing = uiState as? LoginUiStateEditing {
            LoginForm(state: editing, vm: vm)
        } else if let submitting = uiState as? LoginUiStateSubmitting {
            ZStack {
                LoginForm(
                    state: LoginUiStateEditing(
                        email: submitting.email,
                        password: submitting.password,
                        emailError: nil,
                        passwordError: nil,
                        isSubmitEnabled: false
                    ),
                    vm: vm,
                    interactive: false
                )
                ProgressView()
            }
        } else if let failed = uiState as? LoginUiStateFailed {
            LoginForm(
                state: LoginUiStateEditing(
                    email: failed.email,
                    password: "",
                    emailError: nil,
                    passwordError: nil,
                    isSubmitEnabled: false
                ),
                vm: vm
            )
        } else {
            EmptyView()
        }
    }
}

private struct LoginForm: View {
    let state: LoginUiStateEditing
    let vm: LoginViewModel
    var interactive: Bool = true
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: theme.spacing.md) {
            Text("Sign in")
                .font(theme.typography.headlineMedium)
            TextField(
                "Email",
                text: Binding(
                    get: { state.email },
                    set: { vm.onEmailChange(value: $0) }
                )
            )
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .textFieldStyle(.roundedBorder)
            if let emailError = state.emailError {
                Text(emailError).foregroundColor(theme.colors.error)
            }
            SecureField(
                "Password",
                text: Binding(
                    get: { state.password },
                    set: { vm.onPasswordChange(value: $0) }
                )
            )
            .textContentType(.password)
            .textFieldStyle(.roundedBorder)
            if let passwordError = state.passwordError {
                Text(passwordError).foregroundColor(theme.colors.error)
            }
            Button("Sign in") {
                vm.onSubmit()
            }
            .disabled(!state.isSubmitEnabled)
        }
        .padding(theme.spacing.xl)
        .disabled(!interactive)
    }
}
