package dev.viethung.skeleton.android.dashboard

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import dev.viethung.core.theme.DesignTokens

@Composable
fun DashboardPlaceholder(
    themeOverride: Boolean?,
    onCycleTheme: () -> Unit,
    onLogout: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = "Dashboard",
            style = MaterialTheme.typography.headlineMedium,
        )
        Spacer(Modifier.height(DesignTokens.spacing.lg.dp))
        Button(onClick = onLogout) {
            Text("Log out")
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
