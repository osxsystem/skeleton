import SkeletonKit

/**
 * Bridges Koin initialization from Swift to Kotlin.
 * Called from @main iosApp.init() before any ViewModel is created.
 */
final class AppKoinBridge {
    static func start() {
        // AppModuleKt.doInitKoin() calls startKoin { modules(appModule) } on the Kotlin side.
        // The iOS side does not supply a DatabaseDriverFactory — the Kotlin expect class
        // has a no-arg actual on iOS (see DatabaseDriverFactory.ios.kt).
        AppModuleKt.doInitKoin()
    }
}
