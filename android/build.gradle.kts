// Echoelmusic Android - Top-level build file
// Bio-Reactive Audio-Visual Platform
// Updated: December 2025 - Latest Stable Versions

plugins {
    // AGP 8.8.0 (January 2025) - Stable
    id("com.android.application") version "8.8.0" apply false

    // Kotlin 2.1.20 - K2 Compiler Stable, kapt enabled by default
    id("org.jetbrains.kotlin.android") version "2.1.20" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.1.20" apply false
}

tasks.register("clean", Delete::class) {
    delete(rootProject.layout.buildDirectory)
}
