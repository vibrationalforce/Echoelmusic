// Echoelmusic Android App
// Updated: December 2025 - Latest Stable Versions
// Compose December '25 Release, API 35, Kotlin 2.1.20

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.echoelmusic.app"
    compileSdk = 35  // Android 15 (API 35)

    defaultConfig {
        applicationId = "com.echoelmusic.app"
        minSdk = 26      // Android 8.0+
        targetSdk = 35   // Android 15
        versionCode = 2
        versionName = "1.1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        vectorDrawables {
            useSupportLibrary = true
        }

        // NDK configuration for Oboe with 16KB page support
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
        }

        externalNativeBuild {
            cmake {
                // C++20 for latest features (NDK r27+)
                cppFlags += listOf("-std=c++20", "-O3", "-ffast-math", "-DANDROID")
                arguments += listOf(
                    "-DANDROID_STL=c++_shared",
                    "-DANDROID_TOOLCHAIN=clang",
                    // 16KB page size support (Android 15 / API 35)
                    "-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON"
                )
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug") // Debug key for easy install
        }
        debug {
            isDebuggable = true
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
        // K2 compiler optimizations
        freeCompilerArgs += listOf(
            "-opt-in=kotlin.RequiresOptIn",
            "-opt-in=androidx.compose.material3.ExperimentalMaterial3Api",
            "-opt-in=androidx.compose.foundation.ExperimentalFoundationApi"
        )
    }

    buildFeatures {
        compose = true
        prefab = true  // For Oboe
        buildConfig = true
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            excludes += "/META-INF/versions/9/previous-compilation-data.bin"
        }
    }
}

dependencies {
    // ═══════════════════════════════════════════════════════════════
    // Compose BOM December 2025 (1.10 Stable + Material 3 1.4)
    // Features: Pausable Composition, Background Text Prefetch
    // ═══════════════════════════════════════════════════════════════
    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)
    androidTestImplementation(composeBom)

    // ═══════════════════════════════════════════════════════════════
    // Core Android - December 2025 Stable
    // ═══════════════════════════════════════════════════════════════
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.activity:activity-compose:1.9.3")

    // ═══════════════════════════════════════════════════════════════
    // Compose UI 1.10 (December 2025)
    // New: Auto-sizing text, Visibility tracking, Animate bounds
    // ═══════════════════════════════════════════════════════════════
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.ui:ui-util")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.animation:animation")

    // Material 3 (1.4 December 2025)
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material3:material3-window-size-class")
    implementation("androidx.compose.material:material-icons-extended")

    // ═══════════════════════════════════════════════════════════════
    // Navigation
    // ═══════════════════════════════════════════════════════════════
    implementation("androidx.navigation:navigation-compose:2.8.5")

    // ═══════════════════════════════════════════════════════════════
    // Health Connect (Bio-Reactive Features)
    // ═══════════════════════════════════════════════════════════════
    implementation("androidx.health.connect:connect-client:1.1.0-alpha10")

    // ═══════════════════════════════════════════════════════════════
    // Media & MIDI
    // ═══════════════════════════════════════════════════════════════
    implementation("androidx.media:media:1.7.0")
    implementation("androidx.media3:media3-exoplayer:1.5.0")

    // ═══════════════════════════════════════════════════════════════
    // Coroutines (Kotlin 2.1.20 compatible)
    // ═══════════════════════════════════════════════════════════════
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.9.0")

    // ═══════════════════════════════════════════════════════════════
    // Oboe 1.9.0 (Low-latency audio)
    // ═══════════════════════════════════════════════════════════════
    implementation("com.google.oboe:oboe:1.9.0")

    // ═══════════════════════════════════════════════════════════════
    // DataStore & Preferences
    // ═══════════════════════════════════════════════════════════════
    implementation("androidx.datastore:datastore-preferences:1.1.1")

    // ═══════════════════════════════════════════════════════════════
    // Serialization (for state saving)
    // ═══════════════════════════════════════════════════════════════
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")

    // ═══════════════════════════════════════════════════════════════
    // Testing
    // ═══════════════════════════════════════════════════════════════
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.6.1")
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}
