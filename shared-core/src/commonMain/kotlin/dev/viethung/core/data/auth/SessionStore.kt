package dev.viethung.core.data.auth

import dev.viethung.core.data.remote.auth.UserSession
import kotlinx.coroutines.flow.StateFlow

interface SessionStore {
    val session: StateFlow<UserSession?>
    suspend fun save(session: UserSession)
    suspend fun read(): UserSession?
    suspend fun clear()
}
