package dev.viethung.skeleton.android.di

import dev.viethung.core.db.DatabaseDriverFactory
import org.koin.android.ext.koin.androidContext
import org.koin.dsl.module

val platformModule = module {
    // DatabaseDriverFactory for Android requires Context
    single { DatabaseDriverFactory(androidContext()) }
}
