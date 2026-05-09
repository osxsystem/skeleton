package dev.viethung.showcase.greeting

import app.cash.turbine.test
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test                   // kotlin.test.Test — NEVER org.junit.Test (D-17 / Pitfall 18)
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class GreetingViewModelTest {

    @BeforeTest
    fun setMainDispatcher() {
        Dispatchers.setMain(StandardTestDispatcher())
    }

    @AfterTest
    fun resetMainDispatcher() {
        Dispatchers.resetMain()
    }

    private fun makeViewModel(message: String = "Hello, KMP"): GreetingViewModel {
        val repo = object : GreetingRepository {
            override suspend fun getGreeting(id: Long): String = message
        }
        return GreetingViewModel(GetGreetingUseCase(repo))
    }

    private fun makeErrorViewModel(error: String = "DB error"): GreetingViewModel {
        val repo = object : GreetingRepository {
            override suspend fun getGreeting(id: Long): String = throw RuntimeException(error)
        }
        return GreetingViewModel(GetGreetingUseCase(repo))
    }

    @Test
    fun initialStateIsLoading() = runTest {
        val vm = makeViewModel()
        vm.state.test {
            assertIs<GreetingViewModel.UiState.Loading>(awaitItem())
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun loadGreetingTransitionsToReady() = runTest {
        val vm = makeViewModel("Hello, KMP")
        vm.state.test {
            assertIs<GreetingViewModel.UiState.Loading>(awaitItem())  // initial
            vm.loadGreeting()
            advanceUntilIdle()
            // May emit Loading again, then Ready
            val finalState = expectMostRecentItem()
            assertIs<GreetingViewModel.UiState.Ready>(finalState)
            assertEquals("Hello, KMP", finalState.message)
        }
    }

    @Test
    fun loadGreetingOnErrorTransitionsToError() = runTest {
        val vm = makeErrorViewModel("DB error")
        vm.state.test {
            assertIs<GreetingViewModel.UiState.Loading>(awaitItem())
            vm.loadGreeting()
            advanceUntilIdle()
            val finalState = expectMostRecentItem()
            assertIs<GreetingViewModel.UiState.Error>(finalState)
            assertTrue(finalState.message.isNotBlank())
        }
    }
}
