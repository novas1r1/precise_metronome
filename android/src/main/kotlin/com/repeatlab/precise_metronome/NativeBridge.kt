package com.repeatlab.precise_metronome

/**
 * Thin wrapper over the native engine. All calls delegate straight to
 * JNI; the native library is loaded lazily on first use.
 */
internal object NativeBridge {

    init {
        System.loadLibrary("precise_metronome")
    }

    @JvmStatic external fun nativeCreate(): Long
    @JvmStatic external fun nativeDestroy(handle: Long)

    @JvmStatic external fun nativeInit(handle: Long): Boolean
    @JvmStatic external fun nativeStart(handle: Long, initialDelayMs: Long)
    @JvmStatic external fun nativeStop(handle: Long)
    @JvmStatic external fun nativeStartRamp(
        handle: Long,
        initialDelayMs: Long,
        startBpm: Double,
        goalBpm: Double,
        stopAtGoal: Boolean,
        stepBpm: Double,
        barsPerStep: Int
    )
    /** Returns [stepIndex, bpm, finished (0/1)] of the running ramp. */
    @JvmStatic external fun nativeRampState(handle: Long): DoubleArray
    @JvmStatic external fun nativeNudge(handle: Long, deltaMs: Long)

    @JvmStatic external fun nativeSetTempo(handle: Long, bpm: Double)
    @JvmStatic external fun nativeSetTimeSignature(
        handle: Long,
        beatsPerBar: Int,
        accentPattern: BooleanArray
    )
    @JvmStatic external fun nativeSetAccentPattern(
        handle: Long,
        accentPattern: BooleanArray
    )
    @JvmStatic external fun nativeSetSubdivision(handle: Long, pulsesPerBeat: Int)
    @JvmStatic external fun nativeSetVoice(handle: Long, voiceIndex: Int)
    @JvmStatic external fun nativeSetVolume(handle: Long, volume: Double)

    @JvmStatic external fun nativeSetBeatEvents(
        handle: Long,
        enabled: Boolean,
        includeSubdivisions: Boolean
    )
    /** Pending beat events flattened as [bar, beat, pulse, accent, ...]. */
    @JvmStatic external fun nativeDrainBeatEvents(handle: Long): IntArray
}
