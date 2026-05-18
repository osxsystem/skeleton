package dev.viethung.core.data.auth

import dev.viethung.core.data.remote.auth.AuthApi
import dev.viethung.core.data.remote.auth.UserSession

class AuthRepository(
    private val api: AuthApi,
    private val sessionStore: SessionStore,
) {
    suspend fun login(email: String, password: String): UserSession {
        val session = api.login(email, password)
        sessionStore.save(session)
        return session
    }
}
