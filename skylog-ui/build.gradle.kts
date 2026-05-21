plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.compose.compiler)
    alias(libs.plugins.vanniktech.publish)
}

android {
    namespace = "dev.viethung.skylog.ui"
    compileSdk = 36

    defaultConfig {
        minSdk = 23
        consumerProguardFiles("consumer-rules.pro")
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildFeatures {
        compose = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21)
        }
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
        }
    }
}

dependencies {
    api(project(":skylog-core"))
    api(project(":shared-core"))

    // Compose BOM — pin Compose versions via the BOM, not individually.
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.material3)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")

    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.kotlinx.coroutines.core)

    // ----- Instrumented tests (Compose UI) -----
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.test.ext.junit)
    // Pin Espresso 3.7.0+ — older versions call android.hardware.input.InputManager.getInstance(),
    // which was removed in API 35 (Android 15). 3.7.0 uses InputManagerGlobal.getInstance() via reflection.
    androidTestImplementation(libs.androidx.test.espresso.core)
    androidTestImplementation(libs.kotlinx.coroutines.test)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}

mavenPublishing {
    coordinates(
        groupId    = "dev.viethung",
        artifactId = "skylog-ui",
        version    = "0.1.0-SNAPSHOT",
    )
    pom {
        name.set("Skylog UI")
        description.set("In-app log viewer and Compose helpers for Skylog (Android Jetpack Compose)")
        url.set("https://github.com/viethung097/skeleton")
        licenses {
            license {
                name.set("MIT License")
                url.set("https://opensource.org/licenses/MIT")
            }
        }
        developers {
            developer {
                id.set("viethung097")
                name.set("Do Viet Hung")
                email.set("viethung097@gmail.com")
            }
        }
    }
}
