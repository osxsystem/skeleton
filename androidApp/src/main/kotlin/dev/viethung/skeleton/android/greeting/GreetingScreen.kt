package dev.viethung.skeleton.android.greeting

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.viethung.core.theme.DesignTokens
import dev.viethung.showcase.greeting.GreetingViewModel
import org.koin.androidx.compose.koinViewModel

@Composable
fun GreetingScreen(
    viewModel: GreetingViewModel = koinViewModel(),
    themeOverride: Boolean?,
    onCycleTheme: () -> Unit,
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        viewModel.loadGreeting()
    }

    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
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
        Spacer(Modifier.height(DesignTokens.spacing.md.dp))
        Button(onClick = onCycleTheme) {
            Text(
                when (themeOverride) {
                    null  -> "Override theme"
                    false -> "Switch to Dark"
                    true  -> "Switch to System"
                }
            )
        }
    }
}
