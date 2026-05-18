package dev.viethung.core.data.remote.auth

interface AuthApi {
    suspend fun login(email: String, password: String): UserSession
}

data class UserSession(
    val userId: String,
    val token: String,
)
