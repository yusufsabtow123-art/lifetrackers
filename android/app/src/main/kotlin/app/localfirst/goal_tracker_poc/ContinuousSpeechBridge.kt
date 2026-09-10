package app.localfirst.goal_tracker_poc

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import kotlin.math.min

/**
 * A user-controlled Android dictation session.
 *
 * Android 13+ recognition services may honor segmented sessions and continue
 * across pauses without closing the microphone. Services that do not support
 * segmentation are restarted after each completed utterance. The Flutter side
 * keeps every finalized segment, so a platform restart never replaces earlier
 * speech.
 */
class ContinuousSpeechBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : EventChannel.StreamHandler {
    private val handler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var recognizer: SpeechRecognizer? = null
    private var requestedActive = false
    private var generation = 0
    private var consecutiveFailures = 0
    private var lastLevelEventAt = 0L
    private var pendingStart: MethodChannel.Result? = null
    private var pendingStop: MethodChannel.Result? = null
    private var stopFallback: Runnable? = null

    init {
        MethodChannel(messenger, methodChannel).setMethodCallHandler(::onMethodCall)
        EventChannel(messenger, eventChannel).setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> start(result)
            "stop" -> stop(result)
            "cancel" -> {
                cancelSession("cancelled")
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun start(result: MethodChannel.Result) {
        if (requestedActive || pendingStart != null) {
            result.error("speech_busy", "A dictation session is already active.", null)
            return
        }
        if (!SpeechRecognizer.isRecognitionAvailable(activity)) {
            result.success(false)
            emitError(
                "recognizer_unavailable",
                "Speech recognition is not available on this phone.",
            )
            return
        }
        if (activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            pendingStart = result
            activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), permissionRequest)
            return
        }
        beginSession(result)
    }

    fun onPermissionResult(granted: Boolean) {
        val result = pendingStart ?: return
        pendingStart = null
        if (granted) {
            beginSession(result)
        } else {
            result.error(
                "microphone_denied",
                "Microphone permission is needed for speech to text.",
                null,
            )
            emitError(
                "microphone_denied",
                "Allow microphone access to use speech to text.",
            )
        }
    }

    private fun beginSession(result: MethodChannel.Result) {
        requestedActive = true
        consecutiveFailures = 0
        emitStatus("preparing")
        try {
            startCycle()
            result.success(true)
        } catch (error: Throwable) {
            requestedActive = false
            destroyRecognizer()
            result.error("speech_start_failed", error.message, null)
            emitError(
                "speech_start_failed",
                "The phone could not start speech recognition.",
            )
        }
    }

    private fun stop(result: MethodChannel.Result) {
        if (!requestedActive) {
            result.success(null)
            return
        }
        requestedActive = false
        pendingStop?.success(null)
        pendingStop = result
        emitStatus("stopping")
        recognizer?.stopListening()
        stopFallback?.let(handler::removeCallbacks)
        stopFallback = Runnable { finishStop() }.also {
            handler.postDelayed(it, stopResultTimeoutMillis)
        }
    }

    private fun startCycle() {
        if (!requestedActive) return
        generation += 1
        val cycle = generation
        destroyRecognizer()
        val next = SpeechRecognizer.createSpeechRecognizer(activity)
        recognizer = next
        next.setRecognitionListener(CycleListener(cycle))
        next.startListening(recognitionIntent())
    }

    private fun recognitionIntent() =
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            // The system may use either its local or network model. This gives
            // far broader device coverage than requiring an offline pack.
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, false)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                putExtra(
                    RecognizerIntent.EXTRA_SEGMENTED_SESSION,
                    RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS,
                )
                putExtra(
                    RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS,
                    segmentSilenceMillis,
                )
                putExtra(
                    RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS,
                    segmentedSessionMillis,
                )
                putExtra(
                    RecognizerIntent.EXTRA_ENABLE_FORMATTING,
                    RecognizerIntent.FORMATTING_OPTIMIZE_QUALITY,
                )
            }
        }

    private fun scheduleRestart(errorCode: Int? = null) {
        if (!requestedActive) {
            finishStop()
            return
        }
        val quietEnd = errorCode == SpeechRecognizer.ERROR_NO_MATCH ||
            errorCode == SpeechRecognizer.ERROR_SPEECH_TIMEOUT
        if (quietEnd) {
            consecutiveFailures = 0
        } else if (errorCode != null) {
            consecutiveFailures += 1
            if (consecutiveFailures > maxRecoverableFailures) {
                requestedActive = false
                destroyRecognizer()
                emitError(
                    errorName(errorCode),
                    errorMessage(errorCode),
                )
                return
            }
        }
        emitStatus("reconnecting")
        generation += 1 // Ignore late events from the recognizer being retired.
        destroyRecognizer()
        val delay = if (quietEnd || errorCode == null) {
            normalRestartDelayMillis
        } else {
            min(2_000L, 250L shl min(consecutiveFailures, 3))
        }
        handler.postDelayed({
            if (!requestedActive) return@postDelayed
            runCatching(::startCycle).onFailure {
                scheduleRestart(SpeechRecognizer.ERROR_CLIENT)
            }
        }, delay)
    }

    private fun handleError(errorCode: Int) {
        if (!requestedActive) {
            finishStop()
            return
        }
        if (isRecoverable(errorCode)) {
            scheduleRestart(errorCode)
            return
        }
        requestedActive = false
        destroyRecognizer()
        emitError(errorName(errorCode), errorMessage(errorCode))
    }

    private fun cancelSession(status: String) {
        requestedActive = false
        pendingStart?.error("speech_cancelled", "Dictation was cancelled.", null)
        pendingStart = null
        stopFallback?.let(handler::removeCallbacks)
        stopFallback = null
        generation += 1
        recognizer?.cancel()
        destroyRecognizer()
        pendingStop?.success(null)
        pendingStop = null
        emitStatus(status)
    }

    private fun finishStop() {
        stopFallback?.let(handler::removeCallbacks)
        stopFallback = null
        generation += 1
        destroyRecognizer()
        pendingStop?.success(null)
        pendingStop = null
        emitStatus("stopped")
    }

    fun dispose() {
        cancelSession("stopped")
        eventSink = null
    }

    private fun destroyRecognizer() {
        recognizer?.destroy()
        recognizer = null
    }

    private fun emitText(type: String, results: Bundle?) {
        val words = results
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull()
            ?.trim()
            .orEmpty()
        if (words.isNotEmpty()) {
            eventSink?.success(mapOf("type" to type, "text" to words))
        }
    }

    private fun emitStatus(status: String) {
        eventSink?.success(mapOf("type" to "status", "status" to status))
    }

    private fun emitError(code: String, message: String) {
        eventSink?.success(
            mapOf(
                "type" to "error",
                "code" to code,
                "message" to message,
            ),
        )
    }

    private fun isRecoverable(code: Int) = when (code) {
        SpeechRecognizer.ERROR_NO_MATCH,
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT,
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY,
        SpeechRecognizer.ERROR_CLIENT,
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT,
        SpeechRecognizer.ERROR_NETWORK,
        SpeechRecognizer.ERROR_SERVER,
        SpeechRecognizer.ERROR_SERVER_DISCONNECTED,
        SpeechRecognizer.ERROR_AUDIO,
        -> true
        else -> false
    }

    private fun errorName(code: Int) = when (code) {
        SpeechRecognizer.ERROR_AUDIO -> "audio_error"
        SpeechRecognizer.ERROR_CLIENT -> "client_error"
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "microphone_denied"
        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED -> "language_not_supported"
        SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "language_unavailable"
        SpeechRecognizer.ERROR_NETWORK -> "network_error"
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "network_timeout"
        SpeechRecognizer.ERROR_NO_MATCH -> "no_match"
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "recognizer_busy"
        SpeechRecognizer.ERROR_SERVER -> "server_error"
        SpeechRecognizer.ERROR_SERVER_DISCONNECTED -> "server_disconnected"
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "speech_timeout"
        SpeechRecognizer.ERROR_TOO_MANY_REQUESTS -> "too_many_requests"
        else -> "recognizer_error_$code"
    }

    private fun errorMessage(code: Int) = when (code) {
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS ->
            "Allow microphone access to use speech to text."
        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED,
        SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE,
        -> "The phone's speech service does not support the current language."
        SpeechRecognizer.ERROR_TOO_MANY_REQUESTS ->
            "The phone's speech service is temporarily limiting requests. Try again shortly."
        SpeechRecognizer.ERROR_NETWORK,
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT,
        SpeechRecognizer.ERROR_SERVER,
        SpeechRecognizer.ERROR_SERVER_DISCONNECTED,
        -> "Speech recognition could not connect. Check your connection and try again."
        SpeechRecognizer.ERROR_AUDIO ->
            "The microphone could not be read. Close other recording apps and try again."
        else -> "Speech recognition stopped unexpectedly. Please try again."
    }

    private inner class CycleListener(private val cycle: Int) : RecognitionListener {
        private fun current() = cycle == generation

        override fun onReadyForSpeech(params: Bundle?) {
            if (!current()) return
            consecutiveFailures = 0
            emitStatus("listening")
        }

        override fun onBeginningOfSpeech() {
            if (!current()) return
            consecutiveFailures = 0
            emitStatus("hearing")
        }

        override fun onRmsChanged(rmsdB: Float) {
            if (!current()) return
            val now = System.currentTimeMillis()
            if (now - lastLevelEventAt < soundLevelIntervalMillis) return
            lastLevelEventAt = now
            eventSink?.success(mapOf("type" to "soundLevel", "level" to rmsdB.toDouble()))
        }

        override fun onBufferReceived(buffer: ByteArray?) = Unit

        override fun onEndOfSpeech() {
            if (!current()) return
            emitStatus("processing")
        }

        override fun onError(error: Int) {
            if (!current()) return
            handleError(error)
        }

        override fun onResults(results: Bundle?) {
            if (!current()) return
            emitText("final", results)
            if (requestedActive) scheduleRestart() else finishStop()
        }

        override fun onPartialResults(partialResults: Bundle?) {
            if (!current()) return
            emitText("partial", partialResults)
        }

        override fun onEvent(eventType: Int, params: Bundle?) = Unit

        override fun onSegmentResults(segmentResults: Bundle) {
            if (!current()) return
            emitText("final", segmentResults)
            emitStatus("listening")
        }

        override fun onEndOfSegmentedSession() {
            if (!current()) return
            if (requestedActive) scheduleRestart() else finishStop()
        }

        override fun onLanguageDetection(results: Bundle) = Unit
    }

    companion object {
        const val permissionRequest = 7315
        private const val methodChannel = "life_tracker/speech"
        private const val eventChannel = "life_tracker/speech_events"
        private const val normalRestartDelayMillis = 180L
        private const val stopResultTimeoutMillis = 1_400L
        private const val soundLevelIntervalMillis = 90L
        private const val segmentSilenceMillis = 2_500L
        private const val segmentedSessionMillis = 10 * 60 * 1_000L
        private const val maxRecoverableFailures = 3
    }
}
