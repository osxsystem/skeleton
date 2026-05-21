package dev.viethung.skeleton.android.auth

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import dev.viethung.core.data.auth.EncryptedSessionStore
import dev.viethung.core.data.remote.auth.UserSession
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Round-trip test for AC-09 — EncryptedSessionStore persists across instances.
 * Runs as an Android instrumented test (`:androidApp:connectedAndroidTest`)
 * on a connected emulator or device. Validates the real
 * `EncryptedSharedPreferences` backend, not a mock.
 */
@RunWith(AndroidJUnit4::class)
class EncryptedSessionStoreTest {

    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext
    private val sample = UserSession(userId = "u-1", token = "t-encrypted-test")

    @Before
    fun clearStore() = runTest { EncryptedSessionStore(context).clear() }

    @After
    fun cleanupStore() = runTest { EncryptedSessionStore(context).clear() }

    @Test
    fun fresh_instance_returns_null_when_store_empty() = runTest {
        assertNull(EncryptedSessionStore(context).read())
    }

    @Test
    fun save_then_new_instance_reads_back_session() = runTest {
        EncryptedSessionStore(context).save(sample)

        // Fresh instance — simulates a relaunched process reading the persisted blob.
        val fresh = EncryptedSessionStore(context)
        assertEquals(sample, fresh.read())
    }

    @Test
    fun clear_removes_session_for_subsequent_instances() = runTest {
        EncryptedSessionStore(context).save(sample)
        EncryptedSessionStore(context).clear()

        assertNull(EncryptedSessionStore(context).read())
    }

    @Test
    fun overwrite_replaces_previous_session() = runTest {
        EncryptedSessionStore(context).save(sample)
        val replacement = UserSession(userId = "u-2", token = "t-replacement")
        EncryptedSessionStore(context).save(replacement)

        assertEquals(replacement, EncryptedSessionStore(context).read())
    }
}
