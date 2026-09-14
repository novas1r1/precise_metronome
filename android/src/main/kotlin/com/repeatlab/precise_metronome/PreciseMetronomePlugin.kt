package com.repeatlab.precise_metronome

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter entry point: dispatches method calls to the native engine and
 * forwards its ramp progress and beat events to Dart.
 *
 * Both event streams are polled from the main thread rather than pushed
 * from the audio callback. Ramp progress lives in atomics the audio thread
 * publishes; beat events sit in a native ring buffer it fills. Polling is
 * cheaper and safer than JNI callbacks from a real-time thread.
 */
class PreciseMetronomePlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var rampChannel: EventChannel
    private lateinit var beatChannel: EventChannel
    private lateinit var appContext: Context

    private var engineHandle = 0L
    private var backgroundEnabled = false

    private val mainHandler = Handler(Looper.getMainLooper())

    // Ramp progress: polled while a ramp runs, forwarded when it changes.
    private var rampSink: EventChannel.EventSink? = null
    private var rampPolling = false
    private var lastRampStep = -1
    private var lastRampFinished = false
    private val rampPoller = object : Runnable {
        override fun run() {
            if (!rampPolling) return
            pollRamp()
            if (rampPolling) mainHandler.postDelayed(this, RAMP_POLL_MS)
        }
    }

    // Beat events: drained while Dart listens and the engine plays.
    private var beatSink: EventChannel.EventSink? = null
    private var beatEventsEnabled = false
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

    // ------------------------------------------------------------ lifecycle

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "precise_metronome")
        channel.setMethodCallHandler(this)
        rampChannel = EventChannel(binding.binaryMessenger, "precise_metronome/ramp")
        rampChannel.setStreamHandler(streamHandler { rampSink = it })
        beatChannel = EventChannel(binding.binaryMessenger, "precise_metronome/beats")
        beatChannel.setStreamHandler(
            streamHandler {
                beatSink = it
                updateBeatPolling()
            }
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        rampChannel.setStreamHandler(null)
        rampSink = null
        beatChannel.setStreamHandler(null)
        beatSink = null
        teardownEngine()
        stopBackgroundPlayback()
    }

    private fun streamHandler(onSink: (EventChannel.EventSink?) -> Unit) =
        object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) =
                onSink(events)

            override fun onCancel(arguments: Any?) = onSink(null)
        }

    // ------------------------------------------------------------- dispatch

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "init" -> init(result)
                "start" -> start(call, result)
                "startRamp" -> startRamp(call, result)
                "nudge" -> nudge(call, result)
                "stop" -> stop(result)
                "setTempo" -> setTempo(call, result)
                "setTimeSignature" -> setTimeSignature(call, result)
                "setAccentPattern" -> setAccentPattern(call, result)
                "setSubdivision" -> setSubdivision(call, result)
                "setVoice" -> setVoice(call, result)
                "setBeatEvents" -> setBeatEvents(call, result)
                "setVolume" -> setVolume(call, result)
                "setGapPlan" -> setGapPlan(call, result)
                "clearGapPlan" -> clearGapPlan(call, result)
                "enableBackgroundPlayback" -> enableBackgroundPlayback(call, result)
                "disableBackgroundPlayback" -> disableBackgroundPlayback(result)
                "dispose" -> dispose(result)
                else -> result.notImplemented()
            }
        } catch (e: Throwable) {
            result.error("unexpected_error", e.message ?: e::class.java.simpleName, null)
        }
    }

    /** The engine handle, or null after reporting `not_initialized`. */
    private fun requireHandle(result: MethodChannel.Result): Long? {
        if (engineHandle == 0L) {
            result.error("not_initialized", "Call init() first.", null)
            return null
        }
        return engineHandle
    }

    private fun badArguments(result: MethodChannel.Result, expected: String) {
        result.error("bad_arguments", "$expected required", null)
    }

    private fun MethodCall.doubleArg(name: String) = argument<Number>(name)?.toDouble()
    private fun MethodCall.intArg(name: String) = argument<Number>(name)?.toInt()
    private fun MethodCall.longArg(name: String) = argument<Number>(name)?.toLong()
    private fun MethodCall.boolArg(name: String) = argument<Boolean>(name)
    private fun MethodCall.patternArg() =
        argument<List<Boolean>>("accentPattern")?.toBooleanArray()

    // -------------------------------------------------------------- methods

    private fun init(result: MethodChannel.Result) {
        if (engineHandle == 0L) engineHandle = NativeBridge.nativeCreate()
        if (NativeBridge.nativeInit(engineHandle)) {
            result.success(null)
            return
        }
        NativeBridge.nativeDestroy(engineHandle)
        engineHandle = 0L
        result.error("init_failed", "Oboe failed to open an audio stream.", null)
    }

    private fun start(call: MethodCall, result: MethodChannel.Result) {
        val handle = requireHandle(result) ?: return
        stopRampPolling()
        setEnginePlaying(true)
        NativeBridge.nativeStart(handle, call.longArg("initialDelayMs") ?: 0L)
        result.success(null)
    }

    private fun startRamp(call: MethodCall, result: MethodChannel.Result) {
        val startBpm = call.doubleArg("startBpm")
        val goalBpm = call.doubleArg("goalBpm")
        val stepBpm = call.doubleArg("stepBpm")
        val barsPerStep = call.intArg("barsPerStep")
        if (startBpm == null || goalBpm == null || stepBpm == null || barsPerStep == null) {
            badArguments(result, "startBpm, goalBpm, stepBpm: Double, barsPerStep: Int")
            return
        }
        // A timed step: the step length in ms, 0 for bars.
        val stepMs = call.longArg("stepMs") ?: 0L
        if (barsPerStep < 1 && stepMs < 1) {
            badArguments(result, "barsPerStep >= 1 or stepMs >= 1")
            return
        }
        val handle = requireHandle(result) ?: return
        NativeBridge.nativeStartRamp(
            handle,
            call.longArg("initialDelayMs") ?: 0L,
            startBpm,
            goalBpm,
            call.boolArg("stopAtGoal") ?: true,
            stepBpm,
            barsPerStep,
            stepMs,
            call.boolArg("returnToStart") ?: false
        )
        startRampPolling()
        setEnginePlaying(true)
        result.success(null)
    }

    private fun nudge(call: MethodCall, result: MethodChannel.Result) {
        val deltaMs = call.longArg("deltaMs") ?: return badArguments(result, "deltaMs: Int")
        val handle = requireHandle(result) ?: return
        NativeBridge.nativeNudge(handle, deltaMs)
        result.success(null)
    }

    private fun stop(result: MethodChannel.Result) {
        val handle = requireHandle(result) ?: return
        stopRampPolling()
        setEnginePlaying(false)
        NativeBridge.nativeStop(handle)
        result.success(null)
    }

    private fun setTempo(call: MethodCall, result: MethodChannel.Result) {
        val bpm = call.doubleArg("bpm") ?: return badArguments(result, "bpm: Double")
        val handle = requireHandle(result) ?: return
        NativeBridge.nativeSetTempo(handle, bpm)
        result.success(null)
    }

    private fun setTimeSignature(call: MethodCall, result: MethodChannel.Result) {
        val beatsPerBar = call.intArg("beatsPerBar")
        val pattern = call.patternArg()
        if (beatsPerBar == null || pattern == null) {
            badArguments(result, "beatsPerBar: Int, accentPattern: List<Boolean>")
            return
        }
        val handle = requireHandle(result) ?: return
        NativeBridge.nativeSetTimeSignature(handle, beatsPerBar, pattern)
        result.success(null)
    }

    private fun setAccentPattern(call: MethodCall, result: MethodChannel.Result) {
        val pattern = call.patternArg()
            ?: return badArguments(result, "accentPattern: List<Boolean>")
        val handle = requireHandle(result) ?: return
        NativeBridge.nativeSetAccentPattern(handle, pattern)
        result.success(null)
    }

    private fun setSubdivision(call: MethodCall, result: MethodChannel.Result) {
        val pulsesPerBeat = call.intArg("pulsesPerBeat")
            ?: return badArguments(result, "pulsesPerBeat: Int")
        val handle = requireHandle(result) ?: return
        NativeBridge.nativeSetSubdivision(handle, pulsesPerBeat)
        result.success(null)
    }

    private fun setVoice(call: MethodCall, result: MethodChannel.Result) {
        val voice = call.argument<String>("voice")
            ?: return badArguments(result, "voice: String")
        val handle = requireHandle(result) ?: return
        // The native synth owns the list of voice names.
        if (!NativeBridge.nativeSetVoice(handle, voice)) {
            badArguments(result, "voice: a MetronomeVoice name")
            return
        }
        result.success(null)
    }

    private fun setBeatEvents(call: MethodCall, result: MethodChannel.Result) {
        val handle = requireHandle(result) ?: return
        val enabled = call.boolArg("enabled") ?: false
        val includeSubdivisions = call.boolArg("includeSubdivisions") ?: false
        NativeBridge.nativeSetBeatEvents(handle, enabled, includeSubdivisions)
        beatEventsEnabled = enabled
        updateBeatPolling()
        result.success(null)
    }

    private fun setVolume(call: MethodCall, result: MethodChannel.Result) {
        val volume = call.doubleArg("volume") ?: return badArguments(result, "volume: Double")
        val handle = requireHandle(result) ?: return
        NativeBridge.nativeSetVolume(handle, volume)
        result.success(null)
    }

    private fun setGapPlan(call: MethodCall, result: MethodChannel.Result) {
        val segment = call.intArg("segment")
        val from = call.intArg("from")
        val silent = call.argument<List<Boolean>>("silent")?.toBooleanArray()
        if (segment == null || from == null || silent == null) {
            badArguments(result, "segment: Int, from: Int, silent: List<Boolean>")
            return
        }
        val handle = requireHandle(result) ?: return
        if (!NativeBridge.nativeSetGapBars(handle, segment, from, silent)) {
            result.error(
                "gap_plan_busy",
                "The audio thread has not taken in earlier gap bars yet.",
                null
            )
            return
        }
        result.success(null)
    }

    private fun clearGapPlan(call: MethodCall, result: MethodChannel.Result) {
        val segment = call.intArg("segment") ?: return badArguments(result, "segment: Int")
        val handle = requireHandle(result) ?: return
        NativeBridge.nativeClearGapPlan(handle, segment)
        result.success(null)
    }

    private fun enableBackgroundPlayback(call: MethodCall, result: MethodChannel.Result) {
        startForegroundService(call.argument<Map<String, Any?>>("android"))
        backgroundEnabled = true
        result.success(null)
    }

    private fun disableBackgroundPlayback(result: MethodChannel.Result) {
        stopBackgroundPlayback()
        result.success(null)
    }

    private fun dispose(result: MethodChannel.Result) {
        teardownEngine()
        stopBackgroundPlayback()
        result.success(null)
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

    // --------------------------------------------------------- ramp events

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
            rampSink?.success(mapOf("stepIndex" to step, "bpm" to bpm, "finished" to finished))
        }
        if (finished) {
            stopRampPolling()
            // Let the last clicks drain before beat polling stops.
            val session = playSession
            mainHandler.postDelayed({
                if (playSession == session) setEnginePlaying(false)
            }, RAMP_DRAIN_MS)
        }
    }

    // --------------------------------------------------------- beat events

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
        for (i in flat.indices step BEAT_EVENT_FIELDS) {
            sink.success(
                mapOf(
                    "bar" to flat[i],
                    "beat" to flat[i + 1],
                    "pulse" to flat[i + 2],
                    "accent" to (flat[i + 3] != 0),
                    "muted" to (flat[i + 4] != 0),
                    "landing" to (flat[i + 5] != 0),
                    "gapSegment" to flat[i + 6],
                    "gapBar" to flat[i + 7]
                )
            )
        }
    }

    // --------------------------------------------------- background service

    private fun startForegroundService(config: Map<String, Any?>?) {
        val intent = Intent(appContext, MetronomeService::class.java).apply {
            putExtra(
                MetronomeService.EXTRA_TITLE,
                config?.get("title") as? String ?: "Metronome running"
            )
            putExtra(MetronomeService.EXTRA_BODY, config?.get("body") as? String)
            putExtra(
                MetronomeService.EXTRA_CHANNEL_ID,
                config?.get("channelId") as? String ?: MetronomeService.DEFAULT_CHANNEL_ID
            )
            putExtra(
                MetronomeService.EXTRA_CHANNEL_NAME,
                config?.get("channelName") as? String ?: "Metronome"
            )
            putExtra(
                MetronomeService.EXTRA_NOTIFICATION_ID,
                (config?.get("notificationId") as? Number)?.toInt()
                    ?: MetronomeService.DEFAULT_NOTIFICATION_ID
            )
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            appContext.startForegroundService(intent)
        } else {
            appContext.startService(intent)
        }
    }

    private fun stopBackgroundPlayback() {
        if (!backgroundEnabled) return
        appContext.stopService(Intent(appContext, MetronomeService::class.java))
        backgroundEnabled = false
    }

    private companion object {
        const val RAMP_POLL_MS = 20L
        const val BEAT_POLL_MS = 10L
        /** Ints per event in nativeDrainBeatEvents. */
        const val BEAT_EVENT_FIELDS = 8
        /** How long the last clicks of a finished ramp get to ring out. */
        const val RAMP_DRAIN_MS = 250L
    }
}
