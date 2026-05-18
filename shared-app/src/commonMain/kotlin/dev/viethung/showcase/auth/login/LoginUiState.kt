package dev.viethung.showcase.auth.login

sealed interface LoginUiState {

    data class Editing(
        val email: String = "",
        val password: String = "",
        val emailError: String? = null,
        val passwordError: String? = null,
        val isSubmitEnabled: Boolean = false,
    ) : LoginUiState

    data class Submitting(val email: String, val password: String) : LoginUiState

    data class Failed(
        val email: String,
        val password: String,
        val message: String,
    ) : LoginUiState

    data object Succeeded : LoginUiState
}
