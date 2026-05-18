package dev.viethung.showcase.greeting

import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch

/**
 * iOS construction helper that hides the `KClass<T>` parameter the K/N Obj-C bridge
 * cannot expose ergonomically without SKIE.
 *
 * Swift call site:
 *     let vm = GreetingViewModelHelperKt.createGreetingViewModel(store: owner.viewModelStore)
 */
fun createGreetingViewModel(store: ViewModelStore): GreetingViewModel {
    return ViewModelProvider.create(store, greetingViewModelFactory)[GreetingViewModel::class]
}

/**
 * Bridge for `for await s in vm.state` which is a SKIE-only Swift idiom.
 * Subscribes to GreetingViewModel.state on the Main dispatcher and forwards each
 * emission to the Swift closure. Returned Job lets the caller cancel on .onDisappear.
 *
 * Swift call site:
 *     let job = GreetingViewModelHelperKt.subscribeGreetingState(vm: vm) { state in
 *         uiState = state
 *     }
 *     // on cleanup: job.cancel()
 */
fun subscribeGreetingState(
    vm: GreetingViewModel,
    onState: (GreetingViewModel.UiState) -> Unit,
): Job {
    val scope = CoroutineScope(Dispatchers.Main)
    return scope.launch {
        vm.state.collect { onState(it) }
    }
}
