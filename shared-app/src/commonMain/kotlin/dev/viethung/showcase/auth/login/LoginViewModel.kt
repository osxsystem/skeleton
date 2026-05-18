package dev.viethung.showcase.auth.login

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dev.viethung.core.data.remote.auth.AuthException
import dev.viethung.core.domain.auth.LoginUseCase
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class LoginViewModel(
    private val login: LoginUseCase,
) : ViewModel() {

    private val _state = MutableStateFlow<LoginUiState>(LoginUiState.Editing())
    val state: StateFlow<LoginUiState> = _state.asStateFlow()

    fun onEmailChange(value: String) {
        val current = _state.value as? LoginUiState.Editing ?: return
        _state.value = current.copy(
            email = value,
            emailError = null,
            isSubmitEnabled = value.isNotBlank() && current.password.isNotBlank(),
        )
    }

    fun onPasswordChange(value: String) {
        val current = _state.value as? LoginUiState.Editing ?: return
        _state.value = current.copy(
            password = value,
            passwordError = null,
            isSubmitEnabled = current.email.isNotBlank() && value.isNotBlank(),
        )
    }

    fun onSubmit() {
        val current = _state.value as? LoginUiState.Editing ?: return
        if (!current.isSubmitEnabled) return

        viewModelScope.launch {
            _state.value = LoginUiState.Submitting(current.email, current.password)
            try {
                login(current.email, current.password)
                _state.value = LoginUiState.Succeeded
            } catch (e: AuthException) {
                _state.value = LoginUiState.Failed(
                    email = current.email,
                    password = "",
                    message = e.message ?: "Login failed",
                )
            } catch (e: Exception) {
                _state.value = LoginUiState.Failed(
                    email = current.email,
                    password = "",
                    message = "Something went wrong. Please try again.",
                )
            }
        }
    }

    fun onErrorDismissed() {
        val failed = _state.value as? LoginUiState.Failed ?: return
        _state.value = LoginUiState.Editing(
            email = failed.email,
            password = "",
            isSubmitEnabled = false,
        )
    }

    fun onNavigatedToDashboard() {
        _state.value = LoginUiState.Editing()
    }
}
