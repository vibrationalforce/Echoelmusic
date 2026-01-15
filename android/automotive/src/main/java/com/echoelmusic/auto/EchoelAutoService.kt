/**
 * EchoelAutoService.kt
 * Echoelmusic Android Auto Integration
 *
 * Features:
 * - Media playback controls
 * - Bio-reactive presets
 * - Voice commands
 * - Simplified driving-safe UI
 *
 * Created: 2026-01-15
 */

package com.echoelmusic.auto

import android.content.Intent
import android.content.pm.ApplicationInfo
import androidx.car.app.CarAppService
import androidx.car.app.Screen
import androidx.car.app.Session
import androidx.car.app.validation.HostValidator

class EchoelAutoService : CarAppService() {

    override fun createHostValidator(): HostValidator {
        return if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0) {
            HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
        } else {
            HostValidator.Builder(applicationContext)
                .addAllowedHosts(androidx.car.app.R.array.hosts_allowlist_sample)
                .build()
        }
    }

    override fun onCreateSession(): Session {
        return EchoelAutoSession()
    }
}

class EchoelAutoSession : Session() {
    override fun onCreateScreen(intent: Intent): Screen {
        return MainAutoScreen(carContext)
    }
}
