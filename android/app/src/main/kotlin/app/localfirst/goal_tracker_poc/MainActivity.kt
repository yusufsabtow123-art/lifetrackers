package app.localfirst.goal_tracker_poc

import android.app.Activity
import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.CancellationSignal
import android.provider.OpenableColumns
import android.net.Uri
import java.io.File
import java.time.ZoneId
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import androidx.core.content.FileProvider

class MainActivity : FlutterActivity() {
    private var pendingFileResult: MethodChannel.Result? = null
    private var pendingAttachmentResult: MethodChannel.Result? = null
    private var pendingLocationResult: MethodChannel.Result? = null
    private var speechBridge: ContinuousSpeechBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        speechBridge = ContinuousSpeechBridge(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "life_tracker/files"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "chooseScheduleText" -> {
                    if (pendingFileResult != null) {
                        result.error("picker_busy", "A file picker is already open.", null)
                        return@setMethodCallHandler
                    }
                    pendingFileResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "text/*"
                        putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("text/plain", "text/csv", "text/tab-separated-values"))
                    }
                    startActivityForResult(intent, scheduleFileRequest)
                }
                "chooseAttachment" -> {
                    if (pendingAttachmentResult != null) {
                        result.error("picker_busy", "An attachment picker is already open.", null)
                        return@setMethodCallHandler
                    }
                    pendingAttachmentResult = result
                    val imageOnly = call.argument<Boolean>("imageOnly") == true
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = if (imageOnly) "image/*" else "*/*"
                    }
                    startActivityForResult(intent, attachmentRequest)
                }
                "importKeyboardContent" -> {
                    val uri = call.argument<String>("uri")
                    if (uri.isNullOrBlank()) {
                        result.error("invalid_content", "No pasted content was supplied.", null)
                    } else {
                        copyAttachment(Uri.parse(uri), result, call.argument<String>("mimeType"))
                    }
                }
                "currentLocation" -> requestCurrentLocation(result)
                "systemThemeColors" -> result.success(systemThemeColors())
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrBlank()) {
                        result.error("invalid_url", "No URL was supplied.", null)
                    } else {
                        runCatching {
                            startActivity(Intent(Intent.ACTION_VIEW, android.net.Uri.parse(url)))
                        }.onSuccess { result.success(true) }
                            .onFailure { result.error("open_failed", it.message, null) }
                    }
                }
                "openAttachment" -> openAttachment(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun systemThemeColors(): Map<String, Long>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return null
        fun systemColor(name: String): Long? {
            val id = resources.getIdentifier(name, "color", "android")
            if (id == 0) return null
            @Suppress("DEPRECATION")
            return (resources.getColor(id).toLong() and 0xFFFFFFFFL)
        }
        val light = systemColor("system_accent1_600") ?: return null
        val dark = systemColor("system_accent1_200") ?: light
        return mapOf("light" to light, "dark" to dark)
    }

    private fun requestCurrentLocation(result: MethodChannel.Result) {
        if (pendingLocationResult != null) {
            result.error("location_busy", "A location request is already active.", null)
            return
        }
        pendingLocationResult = result
        if (checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(
                arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION, Manifest.permission.ACCESS_FINE_LOCATION),
                locationPermissionRequest,
            )
            return
        }
        readCurrentLocation()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == ContinuousSpeechBridge.permissionRequest) {
            speechBridge?.onPermissionResult(
                grantResults.any { it == PackageManager.PERMISSION_GRANTED },
            )
            return
        }
        if (requestCode != locationPermissionRequest) return
        if (grantResults.any { it == PackageManager.PERMISSION_GRANTED }) {
            readCurrentLocation()
        } else {
            pendingLocationResult?.error(
                "location_denied",
                "Location permission was not granted. You can enter a place manually instead.",
                null,
            )
            pendingLocationResult = null
        }
    }

    private fun readCurrentLocation() {
        val result = pendingLocationResult ?: return
        val manager = getSystemService(LocationManager::class.java)
        val provider = when {
            manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
            manager.isProviderEnabled(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
            else -> null
        }
        if (provider == null) {
            result.error("location_unavailable", "Turn on device location and try again.", null)
            pendingLocationResult = null
            return
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                manager.getCurrentLocation(provider, CancellationSignal(), mainExecutor) { location ->
                    finishLocation(location)
                }
            } else {
                @Suppress("DEPRECATION")
                val location = manager.getLastKnownLocation(provider)
                finishLocation(location)
            }
        } catch (error: SecurityException) {
            result.error("location_denied", error.message, null)
            pendingLocationResult = null
        }
    }

    private fun finishLocation(location: Location?) {
        val result = pendingLocationResult ?: return
        pendingLocationResult = null
        if (location == null) {
            result.error("location_unavailable", "The device has not found its location yet.", null)
            return
        }
        result.success(
            mapOf(
                "latitude" to location.latitude,
                "longitude" to location.longitude,
                "timeZone" to ZoneId.systemDefault().id,
            )
        )
    }

    @Deprecated("Android activity result bridge")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == attachmentRequest) {
            handleAttachmentResult(resultCode, data)
            return
        }
        if (requestCode != scheduleFileRequest) return
        val result = pendingFileResult ?: return
        pendingFileResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }
        val uri = data.data!!
        try {
            val text = contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }
                ?: throw IllegalStateException("The selected file could not be read.")
            var name = "schedule"
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) name = cursor.getString(0)
            }
            result.success(mapOf("name" to name, "text" to text))
        } catch (error: Exception) {
            result.error("file_read_failed", error.message, null)
        }
    }

    private fun handleAttachmentResult(resultCode: Int, data: Intent?) {
        val result = pendingAttachmentResult ?: return
        pendingAttachmentResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }
        val uri = data.data!!
        copyAttachment(uri, result)
    }

    private fun copyAttachment(
        uri: Uri,
        result: MethodChannel.Result,
        suppliedMimeType: String? = null,
    ) {
        try {
            var displayName = "attachment"
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) displayName = cursor.getString(0)
            }
            val safeName = displayName.replace(Regex("[^A-Za-z0-9._-]"), "_")
            val folder = File(filesDir, "attachments").apply { mkdirs() }
            val destination = File(folder, "${System.currentTimeMillis()}-$safeName")
            contentResolver.openInputStream(uri)?.use { input ->
                destination.outputStream().use { output -> input.copyTo(output) }
            } ?: throw IllegalStateException("The selected file could not be read.")
            result.success(mapOf(
                "name" to displayName,
                "path" to destination.absolutePath,
                "mimeType" to (suppliedMimeType ?: contentResolver.getType(uri) ?: ""),
                "sizeBytes" to destination.length(),
            ))
        } catch (error: Exception) {
            result.error("attachment_failed", error.message, null)
        }
    }

    private fun openAttachment(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        val path = call.argument<String>("path")
        val file = path?.let(::File)
        val attachmentsRoot = File(filesDir, "attachments").canonicalFile
        if (file == null ||
            !file.exists() ||
            !file.canonicalFile.toPath().startsWith(attachmentsRoot.toPath())
        ) {
            result.error("attachment_missing", "This attachment is no longer available.", null)
            return
        }
        val mimeType = call.argument<String>("mimeType").orEmpty().ifBlank { "*/*" }
        runCatching {
            val uri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.files",
                file,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mimeType)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(intent, "Open attachment"))
        }.onSuccess { result.success(true) }
            .onFailure { result.error("open_failed", it.message, null) }
    }

    override fun onDestroy() {
        speechBridge?.dispose()
        speechBridge = null
        super.onDestroy()
    }

    companion object {
        private const val scheduleFileRequest = 7312
        private const val attachmentRequest = 7313
        private const val locationPermissionRequest = 7314
    }
}
