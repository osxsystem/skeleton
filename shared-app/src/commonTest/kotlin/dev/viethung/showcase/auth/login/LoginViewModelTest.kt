package dev.viethung.showcase.auth.login

import app.cash.turbine.test
import dev.viethung.core.data.auth.AuthRepository
import dev.viethung.core.data.auth.SessionStore
import dev.viethung.core.data.remote.auth.AuthApi
import dev.viethung.core.data.remote.auth.AuthException
import dev.viethung.core.data.remote.auth.UserSession
import dev.viethung.core.domain.auth.LoginUseCase
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertFalse
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class LoginViewModelTest {

    private val sampleSession = UserSession(userId = "u-1", token = "t-1")

    @BeforeTest
    fun setMainDispatcher() {
        Dispatchers.setMain(StandardTestDispatcher())
    }

    @AfterTest
    fun resetMainDispatcher() {
        Dispatchers.resetMain()
    }

    private fun makeViewModel(api: AuthApi): LoginViewModel =
        LoginViewModel(LoginUseCase(AuthRepository(api, FakeSessionStore())))

    private class StubAuthApi(
        private val result: UserSession? = null,
        private val error: Throwable? = null,
    ) : AuthApi {
        override suspend fun login(email: String, password: String): UserSession =
            error?.let { throw it } ?: result!!
    }

    private class FakeSessionStore : SessionStore {
        private val _session = MutableStateFlow<UserSession?>(null)
        override val session: StateFlow<UserSession?> = _session.asStateFlow()
        override suspend fun save(session: UserSession) { _session.value = session }
        override suspend fun read(): UserSession? = _session.value
        override suspend fun clear() { _session.value = null }
    }

    @Test
    fun initial_state_is_empty_editing() = runTest {
        val vm = makeViewModel(StubAuthApi(result = sampleSession))
        vm.state.test {
            val initial = assertIs<LoginUiState.Editing>(awaitItem())
            assertEquals("", initial.email)
            assertEquals("", initial.password)
            assertFalse(initial.isSubmitEnabled)
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun typing_both_fields_enables_submit() = runTest {
        val vm = makeViewModel(StubAuthApi(result = sampleSession))
        vm.onEmailChange("a@b.com")
        vm.onPasswordChange("pw")

        val state = assertIs<LoginUiState.Editing>(vm.state.value)
        assertEquals("a@b.com", state.email)
        assertEquals("pw", state.password)
        assertTrue(state.isSubmitEnabled)
    }

    @Test
    fun blanking_a_field_disables_submit() = runTest {
        val vm = makeViewModel(StubAuthApi(result = sampleSession))
        vm.onEmailChange("a@b.com")
        vm.onPasswordChange("pw")
        vm.onPasswordChange("")

        val state = assertIs<LoginUiState.Editing>(vm.state.value)
        assertFalse(state.isSubmitEnabled)
    }

    @Test
    fun submit_happy_path_emits_submitting_then_succeeded() = runTest {
        val vm = makeViewModel(StubAuthApi(result = sampleSession))
        vm.onEmailChange("a@b.com")
        vm.onPasswordChange("pw")

        vm.state.test {
            // Drop the Editing state we already validated above.
            skipItems(1)
            vm.onSubmit()
            val submitting = assertIs<LoginUiState.Submitting>(awaitItem())
            assertEquals("a@b.com", submitting.email)
            advanceUntilIdle()
            assertIs<LoginUiState.Succeeded>(expectMostRecentItem())
        }
    }

    @Test
    fun submit_auth_failure_emits_failed_with_message_and_preserves_email() = runTest {
        val vm = makeViewModel(StubAuthApi(error = AuthException("Invalid email or password")))
        vm.onEmailChange("a@b.com")
        vm.onPasswordChange("wrong")

        vm.state.test {
            skipItems(1)
            vm.onSubmit()
            assertIs<LoginUiState.Submitting>(awaitItem())
            advanceUntilIdle()
            val failed = assertIs<LoginUiState.Failed>(expectMostRecentItem())
            assertEquals("a@b.com", failed.email)
            assertEquals("", failed.password)
            assertEquals("Invalid email or password", failed.message)
        }
    }

    @Test
    fun submit_unexpected_exception_emits_failed_with_friendly_message() = runTest {
        val vm = makeViewModel(StubAuthApi(error = RuntimeException("socket reset")))
        vm.onEmailChange("a@b.com")
        vm.onPasswordChange("pw")

        vm.state.test {
            skipItems(1)
            vm.onSubmit()
            assertIs<LoginUiState.Submitting>(awaitItem())
            advanceUntilIdle()
            val failed = assertIs<LoginUiState.Failed>(expectMostRecentItem())
            assertEquals("Something went wrong. Please try again.", failed.message)
        }
    }

    @Test
    fun submit_does_nothing_when_not_enabled() = runTest {
        val vm = makeViewModel(StubAuthApi(result = sampleSession))
        vm.onSubmit()
        advanceUntilIdle()
        assertIs<LoginUiState.Editing>(vm.state.value)
    }

    @Test
    fun on_error_dismissed_returns_to_editing_with_email_preserved() = runTest {
        val vm = makeViewModel(StubAuthApi(error = AuthException("nope")))
        vm.onEmailChange("a@b.com")
        vm.onPasswordChange("pw")
        vm.onSubmit()
        advanceUntilIdle()
        assertIs<LoginUiState.Failed>(vm.state.value)

        vm.onErrorDismissed()

        val editing = assertIs<LoginUiState.Editing>(vm.state.value)
        assertEquals("a@b.com", editing.email)
        assertEquals("", editing.password)
        assertFalse(editing.isSubmitEnabled)
    }

    @Test
    fun on_navigated_to_dashboard_resets_to_empty_editing() = runTest {
        val vm = makeViewModel(StubAuthApi(result = sampleSession))
        vm.onEmailChange("a@b.com")
        vm.onPasswordChange("pw")
        vm.onSubmit()
        advanceUntilIdle()
        assertIs<LoginUiState.Succeeded>(vm.state.value)

        vm.onNavigatedToDashboard()

        val editing = assertIs<LoginUiState.Editing>(vm.state.value)
        assertEquals("", editing.email)
        assertEquals("", editing.password)
        assertFalse(editing.isSubmitEnabled)
    }
}
