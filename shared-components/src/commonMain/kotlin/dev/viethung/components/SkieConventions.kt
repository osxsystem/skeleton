package dev.viethung.components

/**
 * SKIE bridging conventions enforced in this module.
 *
 * RULE 1 — @Throws on all public suspend functions (D-19 / Pitfall 5):
 *
 *   Without @Throws, exceptions thrown by a suspend function are silently swallowed
 *   at the ObjC boundary. The Swift caller sees a nil/empty result with no error.
 *
 *   ALL public suspend functions in :shared-components MUST be annotated:
 *
 *     @Throws(CancellationException::class, Exception::class)
 *     suspend fun doSomething(): String
 *
 *   This ensures the generated Swift async function declares `throws`,
 *   making the error visible in the catch block.
 *
 * RULE 2 — No Result<T>, no Flow<T?> with nullable sealed class (D-16 / Pitfall 4):
 *
 *   See SampleUiState for the correct sealed-wrapper pattern.
 *
 * Enforcement: enforced via code review checklist. A Phase 1 static check is not
 * added (out of scope per D-19). Phase 7 CI can add a detekt rule.
 */
object SkieConventions
