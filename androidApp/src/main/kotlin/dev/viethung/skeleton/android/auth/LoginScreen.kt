package dev.viethung.skeleton.android.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.viethung.core.theme.DesignTokens
import dev.viethung.showcase.auth.login.LoginUiState
import dev.viethung.showcase.auth.login.LoginViewModel
import org.koin.androidx.compose.koinViewModel

@Composable
fun LoginScreen(
    viewModel: LoginViewModel = koinViewModel(),
    onSuccess: () -> Unit,
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(state) {
        if (state is LoginUiState.Succeeded) {
            onSuccess()
            viewModel.onNavigatedToDashboard()
        }
    }

    when (val s = state) {
        is LoginUiState.Editing -> LoginForm(
            state = s,
            onEmailChange = viewModel::onEmailChange,
            onPasswordChange = viewModel::onPasswordChange,
            onSubmit = viewModel::onSubmit,
        )
        is LoginUiState.Submitting -> Box(modifier = Modifier.fillMaxSize()) {
            LoginForm(
                state = LoginUiState.Editing(
                    email = s.email,
                    password = s.password,
                    isSubmitEnabled = false,
                ),
                onEmailChange = {},
                onPasswordChange = {},
                onSubmit = {},
            )
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center,
            ) {
                CircularProgressIndicator()
            }
        }
        is LoginUiState.Failed -> {
            LoginForm(
                state = LoginUiState.Editing(
                    email = s.email,
                    password = "",
                    isSubmitEnabled = false,
                ),
                onEmailChange = viewModel::onEmailChange,
                onPasswordChange = viewModel::onPasswordChange,
                onSubmit = viewModel::onSubmit,
            )
            AlertDialog(
                onDismissRequest = viewModel::onErrorDismissed,
                title = { Text("Login failed") },
                text = { Text(s.message) },
                confirmButton = {
                    TextButton(onClick = viewModel::onErrorDismissed) {
                        Text("OK")
                    }
                },
            )
        }
        LoginUiState.Succeeded -> Unit
    }
}

@Composable
private fun LoginForm(
    state: LoginUiState.Editing,
    onEmailChange: (String) -> Unit,
    onPasswordChange: (String) -> Unit,
    onSubmit: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .imePadding()
            .padding(DesignTokens.spacing.xl.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = "Sign in",
            style = MaterialTheme.typography.headlineMedium,
        )
        Spacer(Modifier.height(DesignTokens.spacing.lg.dp))
        OutlinedTextField(
            value = state.email,
            onValueChange = onEmailChange,
            label = { Text("Email") },
            isError = state.emailError != null,
            supportingText = state.emailError?.let { { Text(it) } },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(DesignTokens.spacing.md.dp))
        OutlinedTextField(
            value = state.password,
            onValueChange = onPasswordChange,
            label = { Text("Password") },
            visualTransformation = PasswordVisualTransformation(),
            isError = state.passwordError != null,
            supportingText = state.passwordError?.let { { Text(it) } },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(DesignTokens.spacing.lg.dp))
        Button(
            onClick = onSubmit,
            enabled = state.isSubmitEnabled,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Sign in")
        }
    }
}
