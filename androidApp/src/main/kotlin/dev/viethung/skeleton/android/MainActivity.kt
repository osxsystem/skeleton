package dev.viethung.skeleton.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import dev.viethung.skeleton.android.greeting.GreetingScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            // Phase 1: single screen, no NavHost (deferred to Phase 5 per CONTEXT.md)
            MaterialTheme {
                Surface {
                    GreetingScreen()
                }
            }
        }
    }
}
