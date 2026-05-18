package dev.viethung.core.data.auth

import dev.viethung.core.data.remote.auth.UserSession
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class SessionStore {
    private val _session = MutableStateFlow<UserSession?>(null)
    val session: StateFlow<UserSession?> = _session.asStateFlow()

    fun save(session: UserSession) { _session.value = session }
    fun get(): UserSession? = _session.value
    fun clear() { _session.value = null }
}
