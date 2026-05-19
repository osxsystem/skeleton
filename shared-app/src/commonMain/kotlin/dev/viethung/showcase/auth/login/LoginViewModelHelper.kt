package dev.viethung.showcase.auth.login

import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch

fun createLoginViewModel(store: ViewModelStore): LoginViewModel {
    return ViewModelProvider.create(store, loginViewModelFactory)[LoginViewModel::class]
}

fun subscribeLoginState(
    vm: LoginViewModel,
    onState: (LoginUiState) -> Unit,
): Job {
    val scope = CoroutineScope(Dispatchers.Main)
    return scope.launch {
        vm.state.collect { onState(it) }
    }
}
