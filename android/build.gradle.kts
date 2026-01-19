// Echoelmusic Android - Top-level build file
// Bio-Reactive Audio-Visual Platform
// Updated: January 2026 - CI-Compatible Stable Versions

plugins {
    // AGP 8.2.2 - Stable version available in CI
    id("com.android.application") version "8.2.2" apply false

    // Kotlin 1.9.22 - Stable, Compose compatible
    id("org.jetbrains.kotlin.android") version "1.9.22" apply false
}

tasks.register("clean", Delete::class) {
    delete(rootProject.layout.buildDirectory)
}
