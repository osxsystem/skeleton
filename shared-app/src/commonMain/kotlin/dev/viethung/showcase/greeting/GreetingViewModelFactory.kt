package dev.viethung.showcase.greeting

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.CreationExtras
import org.koin.core.context.GlobalContext
import kotlin.reflect.KClass

/**
 * Koin-backed ViewModelProvider.Factory for GreetingViewModel.
 *
 * Exposed to iOS as GreetingViewModelFactoryKt.greetingViewModelFactory
 * via SKIE (Kotlin top-level val → Swift static property on the Kt companion).
 *
 * Usage from Swift (IosViewModelStoreOwner pattern):
 *   let vm: GreetingViewModel = owner.viewModel(factory: GreetingViewModelFactoryKt.greetingViewModelFactory)
 *
 * CR-05 fix: resolve GetGreetingUseCase from Koin but construct GreetingViewModel(useCase)
 * directly inside create(). This gives ViewModelProvider ownership of the instance,
 * so viewModelStore.clear() in IosViewModelStoreOwner.deinit correctly calls onCleared()
 * on the ViewModel that was actually used. (D-12 / SCAF-05 lifecycle contract.)
 */
val greetingViewModelFactory: ViewModelProvider.Factory = object : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: KClass<T>, extras: CreationExtras): T {
        // Resolve the dependency from Koin — NOT the ViewModel itself.
        val useCase = GlobalContext.get().get<GetGreetingUseCase>()
        // Construct a fresh instance for the ViewModelStore to own.
        return GreetingViewModel(useCase) as T
    }
}
