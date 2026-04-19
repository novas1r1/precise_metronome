package com.repeatlab.precise_metronome

import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class PreciseMetronomePlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context

    private var engineHandle: Long = 0L
    private var backgroundEnabled: Boolean = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "precise_metronome")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
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
                    requireHandle(result)?.let {
                        NativeBridge.nativeStart(it)
                        result.success(null)
                    }
                }

                "stop" -> {
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
                        else -> {
                            result.error(
                                "bad_arguments",
                                "voice must be 'tone' or 'click'",
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

    private fun teardownEngine() {
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
}
