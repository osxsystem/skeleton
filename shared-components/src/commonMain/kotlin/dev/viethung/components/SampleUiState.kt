package dev.viethung.components

/**
 * Reference sealed UiState pattern for SKIE-bridged ViewModels.
 *
 * SKIE GENERICS RULE (D-16 / Pitfall 4):
 * - NEVER use Result<T> as a StateFlow type parameter — SKIE cannot preserve T across the ObjC bridge.
 * - NEVER use Flow<SealedClass?> where the sealed class is itself a nullable generic.
 * - ALWAYS use a project-specific sealed wrapper (like this one) with concrete data classes.
 *
 * This pattern generates correct Swift headers:
 *   sealed class SampleUiState { Loading, Ready(message: String), Error(message: String) }
 *   → Swift: enum SampleUiState { case loading, ready(SampleUiStateReady), error(SampleUiStateError) }
 *   → NO Any? in the generated header.
 *
 * Anti-pattern (generates Any? erasure):
 *   val state: StateFlow<Result<String>>  ← BROKEN — avoid
 *   val state: StateFlow<Data?>           ← RISKY  — avoid nullable sealed class
 */
sealed interface SampleUiState {
    /** Initial / loading state. No data. */
    data object Loading : SampleUiState

    /**
     * Success state with a concrete String message.
     * NOTE: If the data type were a generic T, SKIE would erase it to Any?.
     * Always use concrete types in data classes.
     */
    data class Ready(val message: String) : SampleUiState

    /** Error state — always carry a non-nullable String message, not a Throwable. */
    data class Error(val message: String) : SampleUiState
}
