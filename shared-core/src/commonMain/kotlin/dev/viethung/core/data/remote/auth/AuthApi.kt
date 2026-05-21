package dev.viethung.core.data.remote.auth

import kotlinx.serialization.Serializable

interface AuthApi {
    suspend fun login(email: String, password: String): UserSession
}

@Serializable
data class UserSession(
    val userId: String,
    val token: String,
)
