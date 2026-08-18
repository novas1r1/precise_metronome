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
    JNIEnv* /*env*/, jclass /*clazz*/, jlong handle,
    jlong initial_delay_ms) {
    if (handle == 0) return;
    reinterpret_cast<MetronomeEngine*>(handle)->start(initial_delay_ms);
}

JNIEXPORT void JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeStartRamp(
    JNIEnv* /*env*/, jclass /*clazz*/, jlong handle,
    jlong initial_delay_ms, jdouble start_bpm, jdouble goal_bpm,
    jboolean stop_at_goal, jdouble step_bpm, jint bars_per_step) {
    if (handle == 0) return;
    reinterpret_cast<MetronomeEngine*>(handle)->start_ramp(
        initial_delay_ms, start_bpm, goal_bpm, stop_at_goal != 0, step_bpm,
        bars_per_step);
}

// Returns [stepIndex, bpm, finished(0/1)] for the running ramp.
JNIEXPORT jdoubleArray JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeRampState(
    JNIEnv* env, jclass /*clazz*/, jlong handle) {
    jdoubleArray out = env->NewDoubleArray(3);
    if (handle == 0 || out == nullptr) return out;
    auto* engine = reinterpret_cast<MetronomeEngine*>(handle);
    const jdouble values[3] = {
        static_cast<jdouble>(engine->ramp_step_index()),
        engine->ramp_bpm(),
        engine->ramp_finished() ? 1.0 : 0.0,
    };
    env->SetDoubleArrayRegion(out, 0, 3, values);
    return out;
}

JNIEXPORT void JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeNudge(
    JNIEnv* /*env*/, jclass /*clazz*/, jlong handle, jlong delta_ms) {
    if (handle == 0) return;
    reinterpret_cast<MetronomeEngine*>(handle)->nudge(delta_ms);
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
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeSetSubdivision(
    JNIEnv* /*env*/, jclass /*clazz*/, jlong handle, jint pulses_per_beat) {
    if (handle == 0) return;
    reinterpret_cast<MetronomeEngine*>(handle)->set_subdivision(pulses_per_beat);
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
