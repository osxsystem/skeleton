package dev.viethung.components

import kotlin.test.Test                    // kotlin.test.Test — NEVER org.junit.Test (D-17 / Pitfall 18)
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertTrue

/**
 * Compile-time + runtime verification that SampleUiState follows the non-erased
 * sealed pattern required by D-16 / Pitfall 4 / SCAF-11.
 *
 * The CI grep gate (`find SkeletonKit.framework/Headers -name "*.h" | xargs grep -l "Any?"`)
 * runs in Plan 09 to verify the generated Objective-C header is also clean.
 */
class SkieGenericsTest {

    @Test
    fun loadingIsDistinctFromReadyAndError() {
        val state: SampleUiState = SampleUiState.Loading
        assertFalse(state is SampleUiState.Ready)
        assertFalse(state is SampleUiState.Error)
        assertIs<SampleUiState.Loading>(state)
    }

    @Test
    fun readyCarriesConcreteMessage() {
        val state: SampleUiState = SampleUiState.Ready("Hello")
        assertIs<SampleUiState.Ready>(state)
        assertEquals("Hello", state.message)
    }

    @Test
    fun errorCarriesNonBlankMessage() {
        val state: SampleUiState = SampleUiState.Error("Something went wrong")
        assertIs<SampleUiState.Error>(state)
        assertTrue(state.message.isNotBlank())
    }

    @Test
    fun whenExhaustiveCoversAllVariants() {
        // This test verifies at compile time that the sealed hierarchy is exhaustive.
        // If a new variant is added without updating this when(), it fails to compile.
        val states: List<SampleUiState> = listOf(
            SampleUiState.Loading,
            SampleUiState.Ready("ok"),
            SampleUiState.Error("fail"),
        )
        val labels = states.map { state ->
            when (state) {
                is SampleUiState.Loading -> "loading"
                is SampleUiState.Ready   -> "ready:${state.message}"
                is SampleUiState.Error   -> "error:${state.message}"
            }
        }
        assertEquals(listOf("loading", "ready:ok", "error:fail"), labels)
    }
}
