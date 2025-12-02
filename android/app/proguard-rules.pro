# Echoelmusic ProGuard Rules

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Compose
-keep class androidx.compose.** { *; }
-dontwarn androidx.compose.**

# Keep Health Connect
-keep class androidx.health.connect.** { *; }
-dontwarn androidx.health.connect.**

# Keep MIDI
-keep class android.media.midi.** { *; }

# Keep our app classes
-keep class com.echoelmusic.app.** { *; }

# Oboe
-keep class com.google.oboe.** { *; }
