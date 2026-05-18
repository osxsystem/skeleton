package dev.viethung.showcase.auth.login

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.CreationExtras
import dev.viethung.core.domain.auth.LoginUseCase
import org.koin.mp.KoinPlatformTools
import kotlin.reflect.KClass

/**
 * Koin-backed ViewModelProvider.Factory for LoginViewModel.
 *
 * Used by iOS via the IosViewModelStoreOwner pattern (see architecture.md §Platform Bindings):
 *   let vm: LoginViewModel = LoginViewModelHelperKt.createLoginViewModel(store: owner.viewModelStore)
 * The helper is added in Step 7 and references this factory.
 *
 * Why resolve the dependency from Koin but construct the VM inline (matches GreetingViewModelFactory):
 * giving ViewModelProvider ownership of the instance ensures viewModelStore.clear() in
 * IosViewModelStoreOwner.deinit triggers onCleared() on the ViewModel that was actually used.
 */
val loginViewModelFactory: ViewModelProvider.Factory = object : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: KClass<T>, extras: CreationExtras): T {
        val useCase = KoinPlatformTools.defaultContext().get().get<LoginUseCase>()
        return LoginViewModel(useCase) as T
    }
}
