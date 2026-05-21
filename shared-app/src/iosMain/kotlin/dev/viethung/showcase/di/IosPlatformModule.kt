package dev.viethung.showcase.di

import dev.viethung.core.data.auth.KeychainSessionStore
import dev.viethung.core.data.auth.SessionStore
import dev.viethung.core.db.DatabaseDriverFactory
import org.koin.dsl.module

val iosPlatformModule = module {
    single { DatabaseDriverFactory() }
    // SessionStore backed by Keychain (PRD §8.2)
    single<SessionStore> { KeychainSessionStore() }
}
