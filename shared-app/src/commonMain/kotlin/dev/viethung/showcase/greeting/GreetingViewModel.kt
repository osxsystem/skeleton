package dev.viethung.showcase.greeting

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class GreetingViewModel(
    private val getGreeting: GetGreetingUseCase,
) : ViewModel() {

    sealed interface UiState {
        data object Loading : UiState
        data class Ready(val message: String) : UiState
        data class Error(val message: String) : UiState
    }

    private val _state = MutableStateFlow<UiState>(UiState.Loading)
    val state: StateFlow<UiState> = _state.asStateFlow()

    fun loadGreeting(id: Long = 1L) {
        viewModelScope.launch {
            _state.value = UiState.Loading
            _state.value = runCatching { getGreeting(id) }.fold(
                onSuccess = { UiState.Ready(it) },
                onFailure = { UiState.Error(it.message ?: "Unknown error") },
            )
        }
    }
}
