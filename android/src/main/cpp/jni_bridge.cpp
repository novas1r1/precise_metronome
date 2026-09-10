#include <jni.h>

#include <algorithm>

#include "click_synth.h"
#include "metronome_engine.h"

using precise_metronome::ClickVoice;
using precise_metronome::MetronomeEngine;
using precise_metronome::parse_click_voice;

namespace {

MetronomeEngine* engine_of(jlong handle) {
    return reinterpret_cast<MetronomeEngine*>(handle);
}

// Copies a Kotlin BooleanArray into `out`, which must hold
// MetronomeEngine::kMaxPattern flags. Returns how many were copied.
int copy_pattern(JNIEnv* env, jbooleanArray pattern, bool* out) {
    const int n = std::min<int>(env->GetArrayLength(pattern),
                                MetronomeEngine::kMaxPattern);
    jboolean* elements = env->GetBooleanArrayElements(pattern, nullptr);
    if (elements == nullptr) return 0;
    for (int i = 0; i < n; ++i) out[i] = (elements[i] != 0);
    env->ReleaseBooleanArrayElements(pattern, elements, JNI_ABORT);
    return n;
}

}  // namespace

extern "C" {

JNIEXPORT jlong JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeCreate(
    JNIEnv* /*env*/, jclass /*clazz*/) {
    return reinterpret_cast<jlong>(new MetronomeEngine());
}

JNIEXPORT void JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeDestroy(
    JNIEnv* /*env*/, jclass /*clazz*/, jlong handle) {
    if (handle == 0) return;
    delete engine_of(handle);
}

JNIEXPORT jboolean JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeInit(
    JNIEnv* /*env*/, jclass /*clazz*/, jlong handle) {
    if (handle == 0) return JNI_FALSE;
    return engine_of(handle)->initialize() ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeStart(
    JNIEnv* /*env*/, jclass /*clazz*/, jlong handle,
    jlong initial_delay_ms) {
    if (handle == 0) return;
    engine_of(handle)->start(initial_delay_ms);
}

JNIEXPORT void JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeStartRamp(
    JNIEnv* /*env*/, jclass /*clazz*/, jlong handle,
    jlong initial_delay_ms, jdouble start_bpm, jdouble goal_bpm,
    jboolean stop_at_goal, jdouble step_bpm, jint bars_per_step,
    jlong step_ms, jboolean return_to_start) {
    if (handle == 0) return;
    engine_of(handle)->start_ramp(
        initial_delay_ms, start_bpm, goal_bpm, stop_at_goal != 0, step_bpm,
        bars_per_step, step_ms, return_to_start != 0);
}

// Returns [stepIndex, bpm, finished(0/1)] for the running ramp.
JNIEXPORT jdoubleArray JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeRampState(
    JNIEnv* env, jclass /*clazz*/, jlong handle) {
    jdoubleArray out = env->NewDoubleArray(3);
    if (handle == 0 || out == nullptr) return out;
    const MetronomeEngine* engine = engine_of(handle);
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
    engine_of(handle)->nudge(delta_ms);
}

JNIEXPORT void JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeStop(
    JNIEnv* /*env*/, jclass /*clazz*/, jlong handle) {
    if (handle == 0) return;
    engine_of(handle)->stop();
}

JNIEXPORT void JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeSetTempo(
    JNIEnv* /*env*/, jclass /*clazz*/, jlong handle, jdouble bpm) {
    if (handle == 0) return;
    engine_of(handle)->set_tempo(bpm);
}

JNIEXPORT void JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeSetTimeSignature(
    JNIEnv* env, jclass /*clazz*/, jlong handle,
    jint beats_per_bar, jbooleanArray pattern) {
    if (handle == 0 || pattern == nullptr) return;
    bool flags[MetronomeEngine::kMaxPattern];
    const int n = copy_pattern(env, pattern, flags);
    engine_of(handle)->set_time_signature(beats_per_bar, flags, n);
}

JNIEXPORT void JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeSetAccentPattern(
    JNIEnv* env, jclass /*clazz*/, jlong handle, jbooleanArray pattern) {
    if (handle == 0 || pattern == nullptr) return;
    bool flags[MetronomeEngine::kMaxPattern];
    const int n = copy_pattern(env, pattern, flags);
    engine_of(handle)->set_accent_pattern(flags, n);
}

JNIEXPORT void JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeSetSubdivision(
    JNIEnv* /*env*/, jclass /*clazz*/, jlong handle, jint pulses_per_beat) {
    if (handle == 0) return;
    engine_of(handle)->set_subdivision(pulses_per_beat);
}

// Returns false for an unknown voice name; the engine is left unchanged.
JNIEXPORT jboolean JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeSetVoice(
    JNIEnv* env, jclass /*clazz*/, jlong handle, jstring name) {
    if (handle == 0 || name == nullptr) return JNI_FALSE;
    const char* chars = env->GetStringUTFChars(name, nullptr);
    if (chars == nullptr) return JNI_FALSE;
    ClickVoice voice = ClickVoice::Tone;
    const bool known = parse_click_voice(chars, &voice);
    env->ReleaseStringUTFChars(name, chars);
    if (!known) return JNI_FALSE;
    engine_of(handle)->set_voice(static_cast<int>(voice));
    return JNI_TRUE;
}

JNIEXPORT void JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeSetVolume(
    JNIEnv* /*env*/, jclass /*clazz*/, jlong handle, jdouble volume) {
    if (handle == 0) return;
    engine_of(handle)->set_volume(volume);
}

JNIEXPORT void JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeSetBeatEvents(
    JNIEnv* /*env*/, jclass /*clazz*/, jlong handle,
    jboolean enabled, jboolean include_subdivisions) {
    if (handle == 0) return;
    engine_of(handle)->set_beat_events(enabled != 0,
                                       include_subdivisions != 0);
}

// Returns pending beat events flattened as [bar, beat, pulse, accent, ...].
JNIEXPORT jintArray JNICALL
Java_com_repeatlab_precise_1metronome_NativeBridge_nativeDrainBeatEvents(
    JNIEnv* env, jclass /*clazz*/, jlong handle) {
    constexpr int kMax = 64;
    MetronomeEngine::BeatEvent events[kMax];
    int n = 0;
    if (handle != 0) {
        n = engine_of(handle)->drain_beat_events(events, kMax);
    }
    jintArray out = env->NewIntArray(n * 4);
    if (out == nullptr || n == 0) return out;
    jint flat[kMax * 4];
    for (int i = 0; i < n; ++i) {
        flat[i * 4 + 0] = events[i].bar;
        flat[i * 4 + 1] = events[i].beat;
        flat[i * 4 + 2] = events[i].pulse;
        flat[i * 4 + 3] = events[i].accent;
    }
    env->SetIntArrayRegion(out, 0, n * 4, flat);
    return out;
}

}  // extern "C"
