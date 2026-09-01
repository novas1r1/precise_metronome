package com.repeatlab.precise_metronome

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class PreciseMetronomePlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var rampChannel: EventChannel
    private lateinit var beatChannel: EventChannel
    private lateinit var appContext: Context

    // Ramp progress is published by the audio thread through atomics; we
    // poll them from the main thread while a ramp is running and forward
    // changes to Dart. Cheaper and safer than JNI callbacks from the
    // real-time audio callback.
    private val mainHandler = Handler(Looper.getMainLooper())
    private var rampSink: EventChannel.EventSink? = null
    private var rampPolling = false
    private var lastRampStep = -1
    private var lastRampFinished = false
    // Beat events: the audio thread writes each rendered pulse into a native
    // ring buffer; while Dart listens and the engine plays we drain it from
    // the main thread every BEAT_POLL_MS.
    private var beatSink: EventChannel.EventSink? = null
    private var beatEventsEnabled = false
    private var beatIncludeSub = false
    private var enginePlaying = false
    private var playSession = 0
    private var beatPolling = false
    private val beatPoller = object : Runnable {
        override fun run() {
            if (!beatPolling) return
            pollBeats()
            if (beatPolling) mainHandler.postDelayed(this, BEAT_POLL_MS)
        }
    }
    private val rampPoller = object : Runnable {
        override fun run() {
            if (!rampPolling) return
            pollRamp()
            if (rampPolling) mainHandler.postDelayed(this, RAMP_POLL_MS)
        }
    }

    private var engineHandle: Long = 0L
    private var backgroundEnabled: Boolean = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "precise_metronome")
        channel.setMethodCallHandler(this)
        rampChannel = EventChannel(binding.binaryMessenger, "precise_metronome/ramp")
        rampChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                rampSink = events
            }
            override fun onCancel(arguments: Any?) {
                rampSink = null
            }
        })
        beatChannel = EventChannel(binding.binaryMessenger, "precise_metronome/beats")
        beatChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                beatSink = events
                updateBeatPolling()
            }
            override fun onCancel(arguments: Any?) {
                beatSink = null
                updateBeatPolling()
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        rampChannel.setStreamHandler(null)
        rampSink = null
        stopRampPolling()
        beatChannel.setStreamHandler(null)
        beatSink = null
        stopBeatPolling()
        teardownEngine()
        if (backgroundEnabled) {
            stopForegroundService()
            backgroundEnabled = false
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "init" -> {
                    if (engineHandle == 0L) {
                        engineHandle = NativeBridge.nativeCreate()
                    }
                    val ok = NativeBridge.nativeInit(engineHandle)
                    if (ok) {
                        result.success(null)
                    } else {
                        NativeBridge.nativeDestroy(engineHandle)
                        engineHandle = 0L
                        result.error(
                            "init_failed",
                            "Oboe failed to open an audio stream.",
                            null
                        )
                    }
                }

                "start" -> {
                    stopRampPolling()
                    setEnginePlaying(true)
                    val initialDelayMs =
                        call.argument<Number>("initialDelayMs")?.toLong() ?: 0L
                    requireHandle(result)?.let {
                        NativeBridge.nativeStart(it, initialDelayMs)
                        result.success(null)
                    }
                }

                "startRamp" -> {
                    val initialDelayMs =
                        call.argument<Number>("initialDelayMs")?.toLong() ?: 0L
                    val startBpm = call.argument<Number>("startBpm")?.toDouble()
                    val goalBpm = call.argument<Number>("goalBpm")?.toDouble()
                    val stopAtGoal = call.argument<Boolean>("stopAtGoal") ?: true
                    val stepBpm = call.argument<Number>("stepBpm")?.toDouble()
                    val barsPerStep = call.argument<Number>("barsPerStep")?.toInt()
                    if (startBpm == null || goalBpm == null ||
                        stepBpm == null || barsPerStep == null
                    ) {
                        result.error(
                            "bad_arguments",
                            "startBpm, goalBpm, stepBpm: Double, barsPerStep: Int required",
                            null
                        )
                        return
                    }
                    requireHandle(result)?.let {
                        NativeBridge.nativeStartRamp(
                            it, initialDelayMs, startBpm, goalBpm, stopAtGoal,
                            stepBpm, barsPerStep
                        )
                        startRampPolling()
                        setEnginePlaying(true)
                        result.success(null)
                    }
                }

                "nudge" -> {
                    val deltaMs = call.argument<Number>("deltaMs")?.toLong()
                    if (deltaMs == null) {
                        result.error("bad_arguments", "deltaMs: Int required", null)
                        return
                    }
                    requireHandle(result)?.let {
                        NativeBridge.nativeNudge(it, deltaMs)
                        result.success(null)
                    }
                }

                "stop" -> {
                    stopRampPolling()
                    setEnginePlaying(false)
                    requireHandle(result)?.let {
                        NativeBridge.nativeStop(it)
                        result.success(null)
                    }
                }

                "setTempo" -> {
                    val bpm = call.argument<Double>("bpm")
                    if (bpm == null) {
                        result.error("bad_arguments", "bpm: Double required", null)
                        return
                    }
                    requireHandle(result)?.let {
                        NativeBridge.nativeSetTempo(it, bpm)
                        result.success(null)
                    }
                }

                "setTimeSignature" -> {
                    val beatsPerBar = call.argument<Int>("beatsPerBar")
                    val pattern = call.argument<List<Boolean>>("accentPattern")
                    if (beatsPerBar == null || pattern == null) {
                        result.error(
                            "bad_arguments",
                            "beatsPerBar: Int, accentPattern: List<Boolean> required",
                            null
                        )
                        return
                    }
                    requireHandle(result)?.let {
                        NativeBridge.nativeSetTimeSignature(
                            it,
                            beatsPerBar,
                            pattern.toBooleanArray()
                        )
                        result.success(null)
                    }
                }

                "setAccentPattern" -> {
                    val pattern = call.argument<List<Boolean>>("accentPattern")
                    if (pattern == null) {
                        result.error(
                            "bad_arguments",
                            "accentPattern: List<Boolean> required",
                            null
                        )
                        return
                    }
                    requireHandle(result)?.let {
                        NativeBridge.nativeSetAccentPattern(it, pattern.toBooleanArray())
                        result.success(null)
                    }
                }

                "setSubdivision" -> {
                    val ppb = call.argument<Int>("pulsesPerBeat")
                    if (ppb == null) {
                        result.error(
                            "bad_arguments",
                            "pulsesPerBeat: Int required",
                            null
                        )
                        return
                    }
                    requireHandle(result)?.let {
                        NativeBridge.nativeSetSubdivision(it, ppb)
                        result.success(null)
                    }
                }

                "setVoice" -> {
                    val voice = call.argument<String>("voice")
                    val idx = when (voice) {
                        "tone" -> 0
                        "click" -> 1
                        "wood" -> 2
                        "mechanical" -> 3
                        "blip" -> 4
                        else -> {
                            result.error(
                                "bad_arguments",
                                "voice must be 'tone', 'click', 'wood', " +
                                    "'mechanical', or 'blip'",
                                null
                            )
                            return
                        }
                    }
                    requireHandle(result)?.let {
                        NativeBridge.nativeSetVoice(it, idx)
                        result.success(null)
                    }
                }

                "setBeatEvents" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val includeSub = call.argument<Boolean>("includeSubdivisions") ?: false
                    requireHandle(result)?.let {
                        NativeBridge.nativeSetBeatEvents(it, enabled, includeSub)
                        beatEventsEnabled = enabled
                        beatIncludeSub = includeSub
                        updateBeatPolling()
                        result.success(null)
                    }
                }

                "setVolume" -> {
                    val volume = call.argument<Double>("volume")
                    if (volume == null) {
                        result.error("bad_arguments", "volume: Double required", null)
                        return
                    }
                    requireHandle(result)?.let {
                        NativeBridge.nativeSetVolume(it, volume)
                        result.success(null)
                    }
                }

                "enableBackgroundPlayback" -> {
                    val android = call.argument<Map<String, Any?>>("android")
                    startForegroundService(android)
                    backgroundEnabled = true
                    result.success(null)
                }

                "disableBackgroundPlayback" -> {
                    if (backgroundEnabled) {
                        stopForegroundService()
                        backgroundEnabled = false
                    }
                    result.success(null)
                }

                "dispose" -> {
                    teardownEngine()
                    if (backgroundEnabled) {
                        stopForegroundService()
                        backgroundEnabled = false
                    }
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        } catch (e: Throwable) {
            result.error(
                "unexpected_error",
                e.message ?: e::class.java.simpleName,
                null
            )
        }
    }

    private fun requireHandle(result: MethodChannel.Result): Long? {
        if (engineHandle == 0L) {
            result.error("not_initialized", "Call init() first.", null)
            return null
        }
        return engineHandle
    }

    private fun startRampPolling() {
        lastRampStep = 0
        lastRampFinished = false
        if (rampPolling) return
        rampPolling = true
        mainHandler.postDelayed(rampPoller, RAMP_POLL_MS)
    }

    private fun stopRampPolling() {
        rampPolling = false
        mainHandler.removeCallbacks(rampPoller)
    }

    private fun pollRamp() {
        if (engineHandle == 0L) {
            stopRampPolling()
            return
        }
        val state = NativeBridge.nativeRampState(engineHandle)
        val step = state[0].toInt()
        val bpm = state[1]
        val finished = state[2] != 0.0
        if (step != lastRampStep || finished != lastRampFinished) {
            lastRampStep = step
            lastRampFinished = finished
            rampSink?.success(
                mapOf("stepIndex" to step, "bpm" to bpm, "finished" to finished)
            )
        }
        if (finished) {
            stopRampPolling()
            // Let the last clicks drain before beat polling stops.
            val session = playSession
            mainHandler.postDelayed({
                if (playSession == session) setEnginePlaying(false)
            }, 250L)
        }
    }

    private fun setEnginePlaying(playing: Boolean) {
        if (playing) playSession++
        enginePlaying = playing
        updateBeatPolling()
    }

    private fun updateBeatPolling() {
        val shouldPoll = beatSink != null && beatEventsEnabled && enginePlaying
        if (shouldPoll && !beatPolling) {
            beatPolling = true
            mainHandler.postDelayed(beatPoller, BEAT_POLL_MS)
        } else if (!shouldPoll && beatPolling) {
            // Drain once more so nothing already rendered is lost.
            pollBeats()
            stopBeatPolling()
        }
    }

    private fun stopBeatPolling() {
        beatPolling = false
        mainHandler.removeCallbacks(beatPoller)
    }

    private fun pollBeats() {
        if (engineHandle == 0L) return
        val sink = beatSink ?: return
        val flat = NativeBridge.nativeDrainBeatEvents(engineHandle)
        var i = 0
        while (i + 3 < flat.size) {
            sink.success(
                mapOf(
                    "bar" to flat[i],
                    "beat" to flat[i + 1],
                    "pulse" to flat[i + 2],
                    "accent" to (flat[i + 3] != 0)
                )
            )
            i += 4
        }
    }

    private fun teardownEngine() {
        stopRampPolling()
        setEnginePlaying(false)
        stopBeatPolling()
        if (engineHandle != 0L) {
            NativeBridge.nativeStop(engineHandle)
            NativeBridge.nativeDestroy(engineHandle)
            engineHandle = 0L
        }
    }

    private fun startForegroundService(android: Map<String, Any?>?) {
        val intent = Intent(appContext, MetronomeService::class.java).apply {
            putExtra(
                MetronomeService.EXTRA_TITLE,
                android?.get("title") as? String ?: "Metronome running"
            )
            putExtra(MetronomeService.EXTRA_BODY, android?.get("body") as? String)
            putExtra(
                MetronomeService.EXTRA_CHANNEL_ID,
                android?.get("channelId") as? String
                    ?: MetronomeService.DEFAULT_CHANNEL_ID
            )
            putExtra(
                MetronomeService.EXTRA_CHANNEL_NAME,
                android?.get("channelName") as? String ?: "Metronome"
            )
            putExtra(
                MetronomeService.EXTRA_NOTIFICATION_ID,
                (android?.get("notificationId") as? Number)?.toInt()
                    ?: MetronomeService.DEFAULT_NOTIFICATION_ID
            )
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            appContext.startForegroundService(intent)
        } else {
            appContext.startService(intent)
        }
    }

    private fun stopForegroundService() {
        val intent = Intent(appContext, MetronomeService::class.java)
        appContext.stopService(intent)
    }

    private companion object {
        const val RAMP_POLL_MS = 20L
        const val BEAT_POLL_MS = 10L
    }
}
