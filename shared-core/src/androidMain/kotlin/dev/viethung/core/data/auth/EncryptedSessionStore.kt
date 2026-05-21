package dev.viethung.core.data.auth

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import dev.viethung.core.data.remote.auth.UserSession
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.json.Json

class EncryptedSessionStore(context: Context) : SessionStore {

    private val prefs: SharedPreferences = createPrefs(context)
    private val _session = MutableStateFlow(readFromPrefs())
    override val session: StateFlow<UserSession?> = _session.asStateFlow()

    override suspend fun save(session: UserSession) {
        prefs.edit().putString(KEY, json.encodeToString(session)).apply()
        _session.value = session
    }

    override suspend fun read(): UserSession? = _session.value

    override suspend fun clear() {
        prefs.edit().remove(KEY).apply()
        _session.value = null
    }

    private fun readFromPrefs(): UserSession? =
        prefs.getString(KEY, null)?.let { json.decodeFromString(it) }

    private companion object {
        const val FILE_NAME = "user_session"
        const val KEY = "session"
        val json: Json = Json

        fun createPrefs(context: Context): SharedPreferences {
            val masterKey = MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()
            return EncryptedSharedPreferences.create(
                context,
                FILE_NAME,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
        }
    }
}
