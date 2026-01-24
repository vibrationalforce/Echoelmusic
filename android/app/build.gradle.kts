// Echoelmusic Android App
// Updated: January 2026 - CI-Compatible Stable Versions
// Compose BOM 2024.10.00, API 34, Kotlin 1.9.22

import java.io.File

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.echoelmusic.app"
    compileSdk = 34  // Android 14 (API 34) - Stable in CI

    signingConfigs {
        create("release") {
            // Use environment variables for CI/CD (GitHub Secrets)
            // For local builds, use debug key or create local.properties
            val keystorePath = System.getenv("ANDROID_KEYSTORE_PATH") ?: ""
            val keystorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD") ?: ""
            val keyAlias = System.getenv("ANDROID_KEY_ALIAS") ?: ""
            val keyPassword = System.getenv("ANDROID_KEY_PASSWORD") ?: ""

            if (keystorePath.isNotEmpty() && File(keystorePath).exists()) {
                storeFile = File(keystorePath)
                storePassword = keystorePassword
                this.keyAlias = keyAlias
                this.keyPassword = keyPassword
            }
        }
    }

    defaultConfig {
        applicationId = "com.echoelmusic.app"
        minSdk = 26      // Android 8.0+
        targetSdk = 34   // Android 14
        versionCode = 3
        versionName = "1.2.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        vectorDrawables {
            useSupportLibrary = true
        }

        // NDK configuration for Oboe
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
        }

        externalNativeBuild {
            cmake {
                cppFlags += listOf("-std=c++17", "-O3", "-ffast-math", "-DANDROID")
                arguments += listOf(
                    "-DANDROID_STL=c++_shared",
                    "-DANDROID_TOOLCHAIN=clang"
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
            // Use release signing config if available (CI/CD), fallback to debug for local builds
            val releaseConfig = signingConfigs.findByName("release")
            signingConfig = if (releaseConfig?.storeFile != null) {
                releaseConfig
            } else {
                signingConfigs.getByName("debug") // Fallback for local development
            }
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

    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.8"
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
    // Compose BOM - Stable October 2024 (Latest stable with Kotlin 1.9.22)
    // ═══════════════════════════════════════════════════════════════
    val composeBom = platform("androidx.compose:compose-bom:2024.10.00")
    implementation(composeBom)
    androidTestImplementation(composeBom)

    // ═══════════════════════════════════════════════════════════════
    // Core Android - Stable versions
    // ═══════════════════════════════════════════════════════════════
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.7.0")
    implementation("androidx.activity:activity-compose:1.8.2")

    // ═══════════════════════════════════════════════════════════════
    // Compose UI
    // ═══════════════════════════════════════════════════════════════
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.animation:animation")

    // Material 3
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")

    // ═══════════════════════════════════════════════════════════════
    // Navigation
    // ═══════════════════════════════════════════════════════════════
    implementation("androidx.navigation:navigation-compose:2.7.7")

    // ═══════════════════════════════════════════════════════════════
    // Health Connect (Bio-Reactive Features)
    // ═══════════════════════════════════════════════════════════════
    implementation("androidx.health.connect:connect-client:1.1.0-alpha07")

    // ═══════════════════════════════════════════════════════════════
    // Media & Audio
    // ═══════════════════════════════════════════════════════════════
    implementation("androidx.media:media:1.7.0")
    implementation("androidx.media3:media3-exoplayer:1.2.1")

    // ═══════════════════════════════════════════════════════════════
    // Coroutines
    // ═══════════════════════════════════════════════════════════════
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")

    // ═══════════════════════════════════════════════════════════════
    // Oboe (Low-latency audio)
    // ═══════════════════════════════════════════════════════════════
    implementation("com.google.oboe:oboe:1.8.0")

    // ═══════════════════════════════════════════════════════════════
    // DataStore & Preferences
    // ═══════════════════════════════════════════════════════════════
    implementation("androidx.datastore:datastore-preferences:1.0.0")

    // ═══════════════════════════════════════════════════════════════
    // Serialization
    // ═══════════════════════════════════════════════════════════════
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.2")

    // ═══════════════════════════════════════════════════════════════
    // Testing
    // ═══════════════════════════════════════════════════════════════
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.7.3")
    testImplementation("org.mockito.kotlin:mockito-kotlin:5.2.1")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}
