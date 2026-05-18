package dev.viethung.core.domain.auth

import dev.viethung.core.data.auth.AuthRepository
import dev.viethung.core.data.remote.auth.UserSession

class LoginUseCase(private val repository: AuthRepository) {
    suspend operator fun invoke(email: String, password: String): UserSession {
        require(email.isNotBlank()) { "Email is required" }
        require(password.isNotBlank()) { "Password is required" }
        return repository.login(email.trim(), password)
    }
}
