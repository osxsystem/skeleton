package dev.viethung.core.di

import dev.viethung.core.db.AppDatabase
import dev.viethung.core.db.DatabaseDriverFactory
import dev.viethung.core.network.createHttpClient
import org.koin.dsl.module

val coreModule = module {
    // Ktor HTTP client — single instance
    single { createHttpClient() }

    // SQLDelight database — created from platform-specific driver factory
    single { AppDatabase(get<DatabaseDriverFactory>().createDriver()) }
}
