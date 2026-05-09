package com.azrng.myitems

import android.content.Intent
import android.net.Uri
import android.os.Environment
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "my_items/system"
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
                        try {
                            val path = writeBackupToExternal(fileName, content)
                            result.success(path)
                        } catch (error: Exception) {
                            result.error("SAVE_BACKUP_FAILED", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Write backup to app-specific external storage (no permissions needed).
     * Path: /Android/data/com.azrng.myitems/files/Download/MyItems/
     * Visible via USB file transfer on all Android versions.
     */
    private fun writeBackupToExternal(fileName: String, content: String): String {
        val safeName = fileName.replace(Regex("""[\\/:*?"<>|]"""), "_")
        val dir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
            ?: throw IllegalStateException("External storage not available")
        val myDir = File(dir, "MyItems")
        if (!myDir.exists() && !myDir.mkdirs()) {
            throw IllegalStateException("Cannot create directory: ${myDir.absolutePath}")
        }
        val file = File(myDir, safeName)
        FileOutputStream(file).use { it.write(content.toByteArray(Charsets.UTF_8)) }
        return file.absolutePath
    }
}
