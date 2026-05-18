package dev.viethung.core.data.remote.auth

import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class FakeAuthApiTest {

    @Test
    fun login_succeeds_with_canonical_credentials() = runTest {
        val api = FakeAuthApi()
        val session = api.login("test@example.com", "password")
        assertEquals("u-1", session.userId)
        assertEquals("fake-token-abc", session.token)
    }

    @Test
    fun login_throws_AuthException_on_wrong_password() = runTest {
        val api = FakeAuthApi()
        val ex = assertFailsWith<AuthException> {
            api.login("test@example.com", "wrong")
        }
        assertEquals("Invalid email or password", ex.message)
    }

    @Test
    fun login_throws_AuthException_on_unknown_email() = runTest {
        val api = FakeAuthApi()
        val ex = assertFailsWith<AuthException> {
            api.login("other@example.com", "password")
        }
        assertEquals("Invalid email or password", ex.message)
    }
}
