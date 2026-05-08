package dev.viethung.showcase.di

import dev.viethung.core.di.coreModule
import dev.viethung.showcase.greeting.GetGreetingUseCase
import dev.viethung.showcase.greeting.GreetingViewModel
import org.koin.core.context.startKoin
import org.koin.dsl.module

/**
 * Showcase Koin module — registers all showcase-specific dependencies.
 * Platform entry points call startKoin { modules(appModule) } at app start.
 *
 * NOTE: GreetingRepository actual implementation is provided by the platform
 * Koin module (androidApp / iosApp) which contributes a DatabaseDriverFactory-backed impl.
 */
val appModule = module {
    includes(coreModule)

    factory { GetGreetingUseCase(get()) }
    factory { GreetingViewModel(get()) }
}

/**
 * Top-level Koin initialization entry point.
 * Called from iOS via AppModuleKt.doInitKoin() (SKIE/KMP name mangling maps initKoin → doInitKoin).
 * Called from androidApp directly via startKoin { modules(appModule) }.
 */
fun initKoin() {
    startKoin {
        modules(appModule)
    }
}
