package com.echoelmusic.app.core

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import java.util.concurrent.ConcurrentHashMap

/**
 * EngineBus — Lock-free publish/subscribe/request message bus
 *
 * Kotlin port of the Swift EngineBus from EngineConsolidation.swift.
 * All EchoelToolkit tools communicate through this bus.
 *
 * Features:
 * - Topic-based pub/sub via SharedFlow (backpressure-safe)
 * - Provide/request pattern for synchronous value queries
 * - Thread-safe via ConcurrentHashMap + coroutines
 */
object EngineBus {

    // MARK: - Message Types

    sealed class BusMessage {
        data class BioUpdate(val snapshot: BioSnapshot) : BusMessage()
        data class AudioAnalysis(val rms: Float, val bpm: Float, val beatDetected: Boolean) : BusMessage()
        data class ParameterChange(val engineId: String, val param: String, val value: Float) : BusMessage()
        data class Custom(val topic: String, val payload: Map<String, String>) : BusMessage()
    }

    /**
     * BioSnapshot — Extended bio-signal data matching Swift BioSnapshot
     */
    data class BioSnapshot(
        val coherence: Float = 0f,
        val heartRate: Float = 70f,
        val breathPhase: Float = 0.5f,
        val flowScore: Float = 0f,
        val hrvVariability: Float = 0.5f,
        val breathDepth: Float = 0.5f,
        val lfHfRatio: Float = 0.5f,
        val coherenceTrend: Float = 0f
    )

    // MARK: - Pub/Sub

    private val _messages = MutableSharedFlow<BusMessage>(
        replay = 0,
        extraBufferCapacity = 64
    )
    val messages: SharedFlow<BusMessage> = _messages.asSharedFlow()

    /** Publish a message to all subscribers */
    fun publish(message: BusMessage): Boolean {
        return _messages.tryEmit(message)
    }

    /** Convenience: publish bio snapshot */
    fun publishBio(snapshot: BioSnapshot) {
        publish(BusMessage.BioUpdate(snapshot))
    }

    /** Convenience: publish parameter change */
    fun publishParam(engineId: String, param: String, value: Float) {
        publish(BusMessage.ParameterChange(engineId, param, value))
    }

    // MARK: - Provide/Request

    private val providers = ConcurrentHashMap<String, () -> Float?>()

    /** Register a value provider (synchronous) */
    fun provide(key: String, provider: () -> Float?) {
        providers[key] = provider
    }

    /** Request a value from a provider */
    fun request(key: String): Float? {
        return providers[key]?.invoke()
    }

    // MARK: - Stats

    val stats: String
        get() = "EngineBus: ${providers.size} providers"
}
