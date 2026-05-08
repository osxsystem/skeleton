package dev.viethung.skeleton.android

import android.app.Application
import dev.viethung.skeleton.android.di.platformModule
import dev.viethung.showcase.di.appModule
import org.koin.android.ext.koin.androidContext
import org.koin.android.ext.koin.androidLogger
import org.koin.core.context.startKoin
import org.koin.core.logger.Level

class SkeletonApp : Application() {
    override fun onCreate() {
        super.onCreate()
        startKoin {
            androidLogger(Level.DEBUG)
            androidContext(this@SkeletonApp)
            modules(appModule, platformModule)
        }
    }
}
