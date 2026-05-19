package dev.viethung.components.numberinput

import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewmodel.CreationExtras
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import kotlin.reflect.KClass

/**
 * iOS construction helper — hides the `KClass<T>` parameter the K/N Obj-C bridge
 * cannot expose ergonomically without SKIE.
 *
 * Swift call site:
 *     let vm = NumberInputViewModelHelperKt.createNumberInputViewModel(
 *         store: owner.viewModelStore,
 *         formatter: SkeletonKitNumberInputViewModelHelperKt.newLocaleNumberFormatter(),
 *         initialValue: KotlinDouble(value: 1234.5),
 *         config: config
 *     )
 *
 * Mirrors LoginViewModelHelper.kt / GreetingViewModelHelper.kt exactly.
 */
fun createNumberInputViewModel(
    store: ViewModelStore,
    formatter: LocaleNumberFormatter,
    initialValue: Double?,
    config: NumberInputConfig,
): NumberInputViewModel {
    val factory = object : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: KClass<T>, extras: CreationExtras): T {
            return NumberInputViewModel(
                formatter = formatter,
                initialValue = initialValue,
                significantDigits = config.significantDigits,
                locale = config.locale,
                allowNegative = config.allowNegative,
            ) as T
        }
    }
    return ViewModelProvider.create(store, factory)[NumberInputViewModel::class]
}

/**
 * Bridge for subscribing to [NumberInputViewModel.state] from Swift (SKIE-less).
 * Returned [Job] lets the caller cancel on `.onDisappear`.
 *
 * Swift call site:
 *     let job = NumberInputViewModelHelperKt.subscribeNumberInputState(vm: vm) { state in
 *         uiState = state
 *     }
 *     // on cleanup: job.cancel(cause: nil)
 */
fun subscribeNumberInputState(
    vm: NumberInputViewModel,
    onState: (NumberInputUiState) -> Unit,
): Job {
    val scope = CoroutineScope(Dispatchers.Main)
    return scope.launch {
        vm.state.collect { onState(it) }
    }
}
