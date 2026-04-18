#include <jni.h>

#include <memory>

#include "metronome_engine.h"

using precise_metronome::MetronomeEngine;

extern "C" {

JNIEXPORT jlong JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeCreate(
    JNIEnv* /*env*/, jclass /*clazz*/) {
    auto* engine = new MetronomeEngine();
    return reinterpret_cast<jlong>(engine);
}

JNIEXPORT void JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeDestroy(
    JNIEnv* /*env*/, jclass /*clazz*/, jlong handle) {
    if (handle == 0) return;
    auto* engine = reinterpret_cast<MetronomeEngine*>(handle);
    delete engine;
}

JNIEXPORT jboolean JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeInit(
    JNIEnv* /*env*/, jclass /*clazz*/, jlong handle) {
    if (handle == 0) return JNI_FALSE;
    auto* engine = reinterpret_cast<MetronomeEngine*>(handle);
    return engine->initialize() ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeStart(
    JNIEnv* /*env*/, jclass /*clazz*/, jlong handle) {
    if (handle == 0) return;
    reinterpret_cast<MetronomeEngine*>(handle)->start();
}

JNIEXPORT void JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeStop(
    JNIEnv* /*env*/, jclass /*clazz*/, jlong handle) {
    if (handle == 0) return;
    reinterpret_cast<MetronomeEngine*>(handle)->stop();
}

JNIEXPORT void JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeSetTempo(
    JNIEnv* /*env*/, jclass /*clazz*/, jlong handle, jdouble bpm) {
    if (handle == 0) return;
    reinterpret_cast<MetronomeEngine*>(handle)->set_tempo(bpm);
}

JNIEXPORT void JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeSetTimeSignature(
    JNIEnv* env, jclass /*clazz*/, jlong handle,
    jint beats_per_bar, jbooleanArray pattern) {
    if (handle == 0 || pattern == nullptr) return;
    auto* engine = reinterpret_cast<MetronomeEngine*>(handle);
    jsize length = env->GetArrayLength(pattern);
    jboolean* elements = env->GetBooleanArrayElements(pattern, nullptr);
    bool tmp[32];
    int n = std::min<int>(length, 32);
    for (int i = 0; i < n; ++i) tmp[i] = (elements[i] != 0);
    env->ReleaseBooleanArrayElements(pattern, elements, JNI_ABORT);
    engine->set_time_signature(beats_per_bar, tmp, n);
}

JNIEXPORT void JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeSetAccentPattern(
    JNIEnv* env, jclass /*clazz*/, jlong handle, jbooleanArray pattern) {
    if (handle == 0 || pattern == nullptr) return;
    auto* engine = reinterpret_cast<MetronomeEngine*>(handle);
    jsize length = env->GetArrayLength(pattern);
    jboolean* elements = env->GetBooleanArrayElements(pattern, nullptr);
    bool tmp[32];
    int n = std::min<int>(length, 32);
    for (int i = 0; i < n; ++i) tmp[i] = (elements[i] != 0);
    env->ReleaseBooleanArrayElements(pattern, elements, JNI_ABORT);
    engine->set_accent_pattern(tmp, n);
}

JNIEXPORT void JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeSetVoice(
    JNIEnv* /*env*/, jclass /*clazz*/, jlong handle, jint voice_index) {
    if (handle == 0) return;
    reinterpret_cast<MetronomeEngine*>(handle)->set_voice(voice_index);
}

JNIEXPORT void JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeSetVolume(
    JNIEnv* /*env*/, jclass /*clazz*/, jlong handle, jdouble volume) {
    if (handle == 0) return;
    reinterpret_cast<MetronomeEngine*>(handle)->set_volume(volume);
}

}  // extern "C"
