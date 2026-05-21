package dev.viethung.core.data.auth

import dev.viethung.core.data.remote.auth.UserSession
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class FakeSessionStore : SessionStore {
    private val _session = MutableStateFlow<UserSession?>(null)
    override val session: StateFlow<UserSession?> = _session.asStateFlow()
    override suspend fun save(session: UserSession) { _session.value = session }
    override suspend fun read(): UserSession? = _session.value
    override suspend fun clear() { _session.value = null }
}
