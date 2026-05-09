package dev.viethung.showcase.di

import dev.viethung.core.di.coreModule
import dev.viethung.showcase.greeting.GetGreetingUseCase
import dev.viethung.showcase.greeting.GreetingRepository
import dev.viethung.showcase.greeting.GreetingRepositoryImpl
import dev.viethung.showcase.greeting.GreetingViewModel
import org.koin.core.context.startKoin
import org.koin.core.module.Module
import org.koin.dsl.module

val appModule = module {
    includes(coreModule)

    factory<GreetingRepository> { GreetingRepositoryImpl(get()) }
    factory { GetGreetingUseCase(get()) }
    factory { GreetingViewModel(get()) }
}

/**
 * Top-level Koin initialization entry point — used by iOS only.
 *
 * Android: SkeletonApp.onCreate() calls startKoin { ... modules(appModule, platformModule) }
 *          directly (NOT initKoin()) — androidLogger and androidContext are Android-only
 *          Koin extras that cannot live in shared commonMain code.
 * iOS:     AppKoinBridge.start() calls AppModuleKt.doInitKoin(platformModules: [iosPlatformModule])
 *          (SKIE maps Kotlin initKoin top-level fun to Swift AppModuleKt.doInitKoin; the
 *           vararg platformModules: Module parameter becomes platformModules: [any KoinModule]
 *           in the generated Swift overlay — verify exact signature in the XCFramework headers)
 *
 * CR-02 fix: platformModules parameter lets iOS supply its DatabaseDriverFactory binding.
 */
fun initKoin(vararg platformModules: Module) {
    startKoin {
        modules(appModule, *platformModules)
    }
}
