package dev.viethung.core.data.auth

import app.cash.turbine.test
import dev.viethung.core.data.remote.auth.UserSession
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class SessionStoreTest {

    private val sample = UserSession(userId = "u-1", token = "t-1")

    @Test
    fun initial_session_is_null() {
        assertNull(SessionStore().get())
    }

    @Test
    fun save_then_get_returns_session() {
        val store = SessionStore()
        store.save(sample)
        assertEquals(sample, store.get())
    }

    @Test
    fun clear_resets_to_null() {
        val store = SessionStore().apply { save(sample) }
        store.clear()
        assertNull(store.get())
    }

    @Test
    fun session_flow_emits_null_then_session_then_null() = runTest {
        val store = SessionStore()
        store.session.test {
            assertNull(awaitItem())
            store.save(sample)
            assertEquals(sample, awaitItem())
            store.clear()
            assertNull(awaitItem())
        }
    }
}
