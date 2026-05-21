package dev.viethung.skeleton.android.di

import dev.viethung.core.data.auth.EncryptedSessionStore
import dev.viethung.core.data.auth.SessionStore
import dev.viethung.core.db.DatabaseDriverFactory
import dev.viethung.skylog.writers.InMemoryLogWriter
import org.koin.android.ext.koin.androidContext
import org.koin.dsl.module

val platformModule = module {
    // DatabaseDriverFactory for Android requires Context
    single { DatabaseDriverFactory(androidContext()) }
    // SessionStore backed by EncryptedSharedPreferences (PRD §8.2)
    single<SessionStore> { EncryptedSessionStore(androidContext()) }
    // Shared InMemoryLogWriter singleton — registered with Skylog in SkeletonApp.onCreate
    single { InMemoryLogWriter(capacity = 1000) }
}
