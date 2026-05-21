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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import dev.viethung.core.theme.DesignTokens
import dev.viethung.skeleton.android.showcase.NumberInputKitShowcaseScreen
import dev.viethung.skeleton.android.showcase.SkylogShowcaseScreen

@Composable
fun DashboardPlaceholder(
    themeOverride: Boolean?,
    onCycleTheme: () -> Unit,
    onLogout: () -> Unit,
) {
    var showNumberInput by rememberSaveable { mutableStateOf(false) }
    var showSkylog by rememberSaveable { mutableStateOf(false) }

    when {
        showNumberInput -> {
            NumberInputKitShowcaseScreen(onBack = { showNumberInput = false })
            return
        }
        showSkylog -> {
            SkylogShowcaseScreen(onClose = { showSkylog = false })
            return
        }
    }

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
        Button(onClick = { showNumberInput = true }) {
            Text("NumberInputKit Showcase")
        }
        Spacer(Modifier.height(DesignTokens.spacing.md.dp))
        Button(onClick = { showSkylog = true }) {
            Text("Skylog Showcase")
        }
        Spacer(Modifier.height(DesignTokens.spacing.md.dp))
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
