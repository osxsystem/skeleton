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
 */
val greetingViewModelFactory: ViewModelProvider.Factory = object : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: KClass<T>, extras: CreationExtras): T {
        return GlobalContext.get().get<GreetingViewModel>() as T
    }
}
