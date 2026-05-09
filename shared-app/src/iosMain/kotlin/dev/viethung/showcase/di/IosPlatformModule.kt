package dev.viethung.showcase.di

import dev.viethung.core.db.DatabaseDriverFactory
import org.koin.dsl.module

val iosPlatformModule = module {
    single { DatabaseDriverFactory() }
}
