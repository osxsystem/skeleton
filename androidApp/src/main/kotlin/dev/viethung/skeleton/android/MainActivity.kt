package dev.viethung.skeleton.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import dev.viethung.skeleton.android.auth.LoginScreen
import dev.viethung.skeleton.android.dashboard.DashboardPlaceholder
import dev.viethung.skeleton.android.theme.AppTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            var themeOverride: Boolean? by rememberSaveable { mutableStateOf<Boolean?>(null) }
            val isDark = themeOverride ?: isSystemInDarkTheme()
            AppTheme(isDark = isDark) {
                Surface {
                    var isAuthenticated by rememberSaveable { mutableStateOf(false) }
                    if (!isAuthenticated) {
                        LoginScreen(onSuccess = { isAuthenticated = true })
                    } else {
                        DashboardPlaceholder(
                            themeOverride = themeOverride,
                            onCycleTheme = {
                                themeOverride = when (themeOverride) {
                                    null  -> false
                                    false -> true
                                    true  -> null
                                }
                            },
                            onLogout = { isAuthenticated = false },
                        )
                    }
                }
            }
        }
    }
}
