package dev.viethung.skeleton.android.greeting

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.viethung.showcase.greeting.GreetingViewModel
import org.koin.androidx.compose.koinViewModel

@Composable
fun GreetingScreen(
    viewModel: GreetingViewModel = koinViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        viewModel.loadGreeting()
    }

    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        when (val s = state) {
            is GreetingViewModel.UiState.Loading -> CircularProgressIndicator()
            is GreetingViewModel.UiState.Ready   -> Text(
                text = s.message,
                style = MaterialTheme.typography.headlineMedium,
            )
            is GreetingViewModel.UiState.Error   -> Text(
                text = "Error: ${s.message}",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.error,
            )
        }
    }
}
