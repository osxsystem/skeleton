plugins {
    alias(libs.plugins.kotlin.multiplatform)   apply false
    alias(libs.plugins.kotlin.jvm)             apply false
    alias(libs.plugins.kotlin.serialization)   apply false
    alias(libs.plugins.android.application)    apply false
    alias(libs.plugins.android.kmp.library)    apply false
    alias(libs.plugins.ksp)                    apply false
    alias(libs.plugins.skie)                   apply false
    alias(libs.plugins.kmmbridge)              apply false
    alias(libs.plugins.sqldelight)             apply false
    alias(libs.plugins.vanniktech.publish)     apply false
}
