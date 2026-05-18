package dev.viethung.core.data.remote.auth

import kotlinx.coroutines.delay

class FakeAuthApi : AuthApi {
    override suspend fun login(email: String, password: String): UserSession {
        delay(800)
        if (email == "test@example.com" && password == "password") {
            return UserSession(userId = "u-1", token = "fake-token-abc")
        }
        throw AuthException("Invalid email or password")
    }
}

class AuthException(message: String) : RuntimeException(message)
