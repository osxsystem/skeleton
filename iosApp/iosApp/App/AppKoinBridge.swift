import SkeletonKit

/**
 * Bridges Koin initialization from Swift to Kotlin.
 * Called from @main iosApp.init() before any ViewModel is created.
 *
 * CR-02 fix: iosPlatformModule is passed so coreModule can resolve DatabaseDriverFactory.
 *
 * IN-03 note: the Swift symbol for Kotlin top-level fun initKoin(vararg platformModules: Module)
 * may be doInitKoin or initKoin depending on the SKIE version. Verify in the generated
 * SkeletonKit.framework/Headers before building. The pre-flight grep above confirms the name.
 */
final class AppKoinBridge {
    static func start() {
        AppModuleKt.doInitKoin(platformModules: [IosPlatformModuleKt.iosPlatformModule])
    }
}
