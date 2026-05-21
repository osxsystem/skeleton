package dev.viethung.skylog

import dev.viethung.skylog.platform.platformDefaultWriter

/**
 * Global logging facade backed by a singleton [Logger].
 *
 * For non-global instances (different tag / writer set), construct a [Logger] directly.
 *
 * ## Initialization contract
 *
 * The `default` [Logger] is initialized eagerly on the first access to `Skylog` (Kotlin
 * `object` semantics). This triggers [platformDefaultWriter] exactly once per process.
 * Safe under Kotlin 2.x's new memory model — [Logger.config] is `@Volatile` and mutated
 * under `synchronized(lock)`.
 *
 * **Test setup recipe:** tests that need to swap in a fake writer must call
 * `Skylog.configure { writers.clear(); writers += fakeWriter }` BEFORE the first
 * `Skylog.v/d/i/w/e/a/configure` call, OR construct a fresh
 * `Logger(SkylogConfig().apply { writers += fakeWriter })` directly instead of using `Skylog`.
 */
object Skylog {
    private val default: Logger = Logger(SkylogConfig().apply { writers += platformDefaultWriter() })

    fun v(tag: String? = null, throwable: Throwable? = null, message: () -> String) =
        default.v(tag, throwable, message)

    fun d(tag: String? = null, throwable: Throwable? = null, message: () -> String) =
        default.d(tag, throwable, message)

    fun i(tag: String? = null, throwable: Throwable? = null, message: () -> String) =
        default.i(tag, throwable, message)

    fun w(tag: String? = null, throwable: Throwable? = null, message: () -> String) =
        default.w(tag, throwable, message)

    fun e(tag: String? = null, throwable: Throwable? = null, message: () -> String) =
        default.e(tag, throwable, message)

    fun a(tag: String? = null, throwable: Throwable? = null, message: () -> String) =
        default.a(tag, throwable, message)

    // Structured fields surface
    fun v(tag: String? = null, fields: Map<String, String>, throwable: Throwable? = null, message: () -> String) =
        default.v(tag, fields, throwable, message)

    fun d(tag: String? = null, fields: Map<String, String>, throwable: Throwable? = null, message: () -> String) =
        default.d(tag, fields, throwable, message)

    fun i(tag: String? = null, fields: Map<String, String>, throwable: Throwable? = null, message: () -> String) =
        default.i(tag, fields, throwable, message)

    fun w(tag: String? = null, fields: Map<String, String>, throwable: Throwable? = null, message: () -> String) =
        default.w(tag, fields, throwable, message)

    fun e(tag: String? = null, fields: Map<String, String>, throwable: Throwable? = null, message: () -> String) =
        default.e(tag, fields, throwable, message)

    fun a(tag: String? = null, fields: Map<String, String>, throwable: Throwable? = null, message: () -> String) =
        default.a(tag, fields, throwable, message)

    fun configure(block: SkylogConfig.() -> Unit) = default.configure(block)

    fun minSeverity(severity: Severity) = configure { minSeverity = severity }
}
