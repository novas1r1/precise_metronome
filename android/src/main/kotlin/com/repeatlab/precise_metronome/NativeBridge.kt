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
        barsPerStep: Int,
        stepMs: Long,
        returnToStart: Boolean
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
    /** Selects a voice by its Dart name; false for an unknown name. */
    @JvmStatic external fun nativeSetVoice(handle: Long, voice: String): Boolean
    @JvmStatic external fun nativeSetVolume(handle: Long, volume: Double)

    @JvmStatic external fun nativeSetBeatEvents(
        handle: Long,
        enabled: Boolean,
        includeSubdivisions: Boolean
    )
    /**
     * Pending beat events flattened as
     * [bar, beat, pulse, accent, muted, landing, gapSegment, gapBar, ...].
     */
    @JvmStatic external fun nativeDrainBeatEvents(handle: Long): IntArray

    /**
     * Stores which bars of a gap segment are silent; false when the audio
     * thread has not taken in earlier bars yet.
     */
    @JvmStatic external fun nativeSetGapBars(
        handle: Long,
        segment: Int,
        from: Int,
        silent: BooleanArray
    ): Boolean
    /** Starts a gap segment that silences nothing. */
    @JvmStatic external fun nativeClearGapPlan(handle: Long, segment: Int)
}
