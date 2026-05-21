package dev.viethung.core.domain.auth

import dev.viethung.core.data.auth.AuthRepository
import dev.viethung.core.data.auth.FakeSessionStore
import dev.viethung.core.data.remote.auth.AuthApi
import dev.viethung.core.data.remote.auth.UserSession
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class LoginUseCaseTest {

    private val expected = UserSession(userId = "u-1", token = "t-1")

    @Test
    fun invoke_trims_email_and_returns_session() = runTest {
        val api = RecordingAuthApi(result = expected)
        val useCase = LoginUseCase(AuthRepository(api, FakeSessionStore()))

        val result = useCase.invoke("  user@example.com  ", "pw")

        assertEquals(expected, result)
        assertEquals("user@example.com", api.lastEmail)
        assertEquals("pw", api.lastPassword)
    }

    @Test
    fun blank_email_throws_IllegalArgumentException() = runTest {
        val useCase = LoginUseCase(AuthRepository(RecordingAuthApi(result = expected), FakeSessionStore()))
        assertFailsWith<IllegalArgumentException> { useCase.invoke("   ", "pw") }
    }

    @Test
    fun blank_password_throws_IllegalArgumentException() = runTest {
        val useCase = LoginUseCase(AuthRepository(RecordingAuthApi(result = expected), FakeSessionStore()))
        assertFailsWith<IllegalArgumentException> { useCase.invoke("a@b.com", "") }
    }

    private class RecordingAuthApi(private val result: UserSession) : AuthApi {
        var lastEmail: String? = null
        var lastPassword: String? = null
        override suspend fun login(email: String, password: String): UserSession {
            lastEmail = email
            lastPassword = password
            return result
        }
    }
}
