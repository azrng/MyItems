package com.azrng.myitems

import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "my_items/system"
        private const val TAG = "MyItems"
    }

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
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
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
                        try {
                            val path = writeBackup(fileName, content)
                            Log.d(TAG, "Backup written to: $path")
                            result.success(path)
                        } catch (error: Exception) {
                            Log.e(TAG, "Backup write failed", error)
                            result.error("SAVE_BACKUP_FAILED", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun writeBackup(fileName: String, content: String): String {
        val safeName = fileName.replace(Regex("""[\\/:*?"<>|]"""), "_")
        val bytes = content.toByteArray(Charsets.UTF_8)

        // Write to app-specific external Downloads (always works, no permissions)
        val dir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
            ?: throw IllegalStateException("External storage not available")
        val myDir = File(dir, "MyItems")
        if (!myDir.exists() && !myDir.mkdirs()) {
            throw IllegalStateException("Cannot create directory: ${myDir.absolutePath}")
        }
        val file = File(myDir, safeName)
        FileOutputStream(file).use { it.write(bytes) }
        return file.absolutePath
    }
}
