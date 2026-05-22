package com.azrng.myitems

import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "my_items/system"
        private const val TAG = "MyItems"
        private const val REQUEST_WRITE_STORAGE = 1001
    }

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingBackup: PendingBackup? = null
    private var pendingBackupResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openUrl" -> {
                        val url = call.argument<String>("url")
                        if (url.isNullOrBlank()) {
                            result.error("INVALID_URL", "URL cannot be empty", null)
                            return@setMethodCallHandler
                        }
                        val uri = Uri.parse(url)
                        val scheme = uri.scheme?.lowercase()
                        if (scheme != "http" && scheme != "https") {
                            result.error("INVALID_URL", "Only http and https URLs are allowed", null)
                            return@setMethodCallHandler
                        }
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, uri))
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("OPEN_URL_FAILED", error.message, null)
                        }
                    }
                    "saveBackupToDownloads" -> {
                        val fileName = call.argument<String>("fileName")
                        val content = call.argument<String>("content")
                        if (fileName.isNullOrBlank() || content == null) {
                            result.error("INVALID_BACKUP", "Backup file name or content is empty", null)
                            return@setMethodCallHandler
                        }
                        Log.d(TAG, "Backup fileName=$fileName contentLength=${content.length}")
                        saveBackupWithPermission(fileName, content, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun saveBackupWithPermission(
        fileName: String,
        content: String,
        result: MethodChannel.Result
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q || hasWriteStoragePermission()) {
            writeBackupAsync(fileName, content, result)
            return
        }
        if (pendingBackupResult != null) {
            result.error("SAVE_BACKUP_BUSY", "Another backup export is already waiting for storage permission", null)
            return
        }
        pendingBackup = PendingBackup(fileName, content)
        pendingBackupResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
            REQUEST_WRITE_STORAGE
        )
    }

    private fun hasWriteStoragePermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.WRITE_EXTERNAL_STORAGE
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun writeBackupAsync(
        fileName: String,
        content: String,
        result: MethodChannel.Result
    ) {
        executor.execute {
            try {
                val path = writeBackup(fileName, content)
                Log.d(TAG, "Backup written to: $path")
                mainHandler.post { result.success(path) }
            } catch (error: Exception) {
                Log.e(TAG, "Backup write failed", error)
                mainHandler.post { result.error("SAVE_BACKUP_FAILED", error.message, null) }
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_WRITE_STORAGE) return

        val backup = pendingBackup
        val result = pendingBackupResult
        pendingBackup = null
        pendingBackupResult = null
        if (backup == null || result == null) return

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            result.error("STORAGE_PERMISSION_DENIED", "存储权限被拒绝，请在系统设置中授权", null)
            return
        }
        writeBackupAsync(backup.fileName, backup.content, result)
    }

    override fun onDestroy() {
        pendingBackupResult?.error("ACTIVITY_DESTROYED", "Activity destroyed before backup export completed", null)
        pendingBackup = null
        pendingBackupResult = null
        executor.shutdownNow()
        super.onDestroy()
    }

    private fun writeBackup(fileName: String, content: String): String {
        val safeName = fileName.replace(Regex("""[\\/:*?"<>|]"""), "_")
        val bytes = content.toByteArray(Charsets.UTF_8)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, safeName)
                put(MediaStore.Downloads.MIME_TYPE, "application/json")
                put(MediaStore.Downloads.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/MyItems")
            }
            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("MediaStore insert failed")
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("Cannot open output stream")
            Log.d(TAG, "Backup saved via MediaStore: $uri")
            return uri.toString()
        } else {
            @Suppress("DEPRECATION")
            val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            val myDir = File(dir, "MyItems")
            if (!myDir.exists() && !myDir.mkdirs()) {
                throw IllegalStateException("Cannot create directory: ${myDir.absolutePath}")
            }
            val file = File(myDir, safeName)
            FileOutputStream(file).use { it.write(bytes) }
            Log.d(TAG, "Backup saved to: ${file.absolutePath}")
            return file.absolutePath
        }
    }

    private data class PendingBackup(val fileName: String, val content: String)
}
