package dev.viethung.core.data.auth

import dev.viethung.core.data.remote.auth.AuthApi
import dev.viethung.core.data.remote.auth.AuthException
import dev.viethung.core.data.remote.auth.UserSession
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull

class AuthRepositoryTest {

    private val expected = UserSession(userId = "u-1", token = "t-1")

    @Test
    fun login_success_persists_session_and_returns_it() = runTest {
        val api = StubAuthApi(result = expected)
        val store = SessionStore()
        val repo = AuthRepository(api, store)

        val result = repo.login("a@b.com", "pw")

        assertEquals(expected, result)
        assertEquals(expected, store.get())
    }

    @Test
    fun login_failure_propagates_and_leaves_store_untouched() = runTest {
        val api = StubAuthApi(error = AuthException("nope"))
        val store = SessionStore()
        val repo = AuthRepository(api, store)

        assertFailsWith<AuthException> { repo.login("a@b.com", "pw") }
        assertNull(store.get())
    }

    private class StubAuthApi(
        private val result: UserSession? = null,
        private val error: Throwable? = null,
    ) : AuthApi {
        override suspend fun login(email: String, password: String): UserSession =
            error?.let { throw it } ?: result!!
    }
}
