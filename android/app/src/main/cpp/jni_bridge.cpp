/**
 * JNI Bridge for Echoelmusic Android
 * Connects Kotlin AudioEngine to native C++ engine
 */

#include <jni.h>
#include <android/log.h>
#include <memory>
#include "EchoelmusicEngine.h"

#define LOG_TAG "EchoelmusicJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Global engine instance
static std::unique_ptr<echoelmusic::EchoelmusicEngine> gEngine;

extern "C" {

// ============== Lifecycle ==============

JNIEXPORT jboolean JNICALL
Java_com_echoelmusic_app_audio_AudioEngine_nativeCreate(
    JNIEnv* env,
    jobject thiz,
    jint sampleRate,
    jint framesPerBuffer) {

    LOGI("nativeCreate: %d Hz, %d frames", sampleRate, framesPerBuffer);

    if (gEngine) {
        gEngine->destroy();
    }

    gEngine = std::make_unique<echoelmusic::EchoelmusicEngine>();
    return gEngine->create(sampleRate, framesPerBuffer) ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_com_echoelmusic_app_audio_AudioEngine_nativeStart(
    JNIEnv* env,
    jobject thiz) {

    LOGI("nativeStart");
    if (!gEngine) return JNI_FALSE;
    return gEngine->start() ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL
Java_com_echoelmusic_app_audio_AudioEngine_nativeStop(
    JNIEnv* env,
    jobject thiz) {

    LOGI("nativeStop");
    if (gEngine) {
        gEngine->stop();
    }
}

JNIEXPORT void JNICALL
Java_com_echoelmusic_app_audio_AudioEngine_nativeDestroy(
    JNIEnv* env,
    jobject thiz) {

    LOGI("nativeDestroy");
    if (gEngine) {
        gEngine->destroy();
        gEngine.reset();
    }
}

JNIEXPORT jfloat JNICALL
Java_com_echoelmusic_app_audio_AudioEngine_nativeGetLatencyMs(
    JNIEnv* env,
    jobject thiz) {

    if (!gEngine) return 0.0f;
    return gEngine->getLatencyMs();
}

// ============== Synth Control ==============

JNIEXPORT void JNICALL
Java_com_echoelmusic_app_audio_AudioEngine_nativeNoteOn(
    JNIEnv* env,
    jobject thiz,
    jint note,
    jint velocity) {

    if (gEngine) {
        gEngine->noteOn(note, velocity);
    }
}

JNIEXPORT void JNICALL
Java_com_echoelmusic_app_audio_AudioEngine_nativeNoteOff(
    JNIEnv* env,
    jobject thiz,
    jint note) {

    if (gEngine) {
        gEngine->noteOff(note);
    }
}

JNIEXPORT void JNICALL
Java_com_echoelmusic_app_audio_AudioEngine_nativeSetParameter(
    JNIEnv* env,
    jobject thiz,
    jint paramId,
    jfloat value) {

    if (gEngine) {
        gEngine->setParameter(paramId, value);
    }
}

// ============== Bio-Reactive ==============

JNIEXPORT void JNICALL
Java_com_echoelmusic_app_audio_AudioEngine_nativeUpdateBioData(
    JNIEnv* env,
    jobject thiz,
    jfloat heartRate,
    jfloat hrv,
    jfloat coherence) {

    if (gEngine) {
        gEngine->updateBioData(heartRate, hrv, coherence);
    }
}

// ============== TR-808 ==============

JNIEXPORT void JNICALL
Java_com_echoelmusic_app_audio_AudioEngine_nativeTrigger808(
    JNIEnv* env,
    jobject thiz,
    jint note,
    jint velocity) {

    if (gEngine) {
        gEngine->trigger808(note, velocity);
    }
}

JNIEXPORT void JNICALL
Java_com_echoelmusic_app_audio_AudioEngine_nativeSet808Parameter(
    JNIEnv* env,
    jobject thiz,
    jint paramId,
    jfloat value) {

    if (gEngine) {
        gEngine->set808Parameter(paramId, value);
    }
}

} // extern "C"
