package com.azrng.myitems

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream

class MainActivity : FlutterActivity() {
    private var pendingBackupResult: MethodChannel.Result? = null
    private var pendingBackupContent: String? = null

    companion object {
        private const val REQUEST_CREATE_BACKUP = 9302
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
                        launchSaveDialog(fileName, content, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun launchSaveDialog(
        fileName: String,
        content: String,
        result: MethodChannel.Result
    ) {
        pendingBackupResult = result
        pendingBackupContent = content
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
            putExtra(Intent.EXTRA_TITLE, fileName)
        }
        @Suppress("DEPRECATION")
        startActivityForResult(intent, REQUEST_CREATE_BACKUP)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_CREATE_BACKUP) return

        val result = pendingBackupResult ?: return
        val content = pendingBackupContent ?: return
        pendingBackupResult = null
        pendingBackupContent = null

        if (resultCode != RESULT_OK || data == null || data.data == null) {
            result.error("SAVE_CANCELLED", "User cancelled or no location selected", null)
            return
        }

        try {
            val uri = data.data!!
            contentResolver.openOutputStream(uri, "w")?.use { output: OutputStream ->
                output.write(content.toByteArray(Charsets.UTF_8))
            } ?: throw IllegalStateException("Cannot open output stream")
            result.success(uri.toString())
        } catch (error: Exception) {
            result.error("SAVE_BACKUP_FAILED", error.message, null)
        }
    }
}
