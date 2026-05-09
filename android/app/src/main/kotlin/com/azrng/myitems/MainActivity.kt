package com.azrng.myitems

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import androidx.core.content.FileProvider
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
                            saveAndShareBackup(fileName, content)
                            result.success(fileName)
                        } catch (error: Exception) {
                            result.error("SAVE_BACKUP_FAILED", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun saveAndShareBackup(fileName: String, content: String) {
        val safeName = fileName.replace(Regex("""[\\/:*?"<>|]"""), "_")
        val bytes = content.toByteArray(Charsets.UTF_8)

        // Try public Download/MyItems first (no permission needed on API 28-)
        val savedPath = tryWriteToPublicDownloads(safeName, bytes)

        // Always write to app cache as fallback / for sharing
        val cacheFile = File(cacheDir, "backups").also { it.mkdirs() }
        val shareFile = File(cacheFile, safeName)
        FileOutputStream(shareFile).use { it.write(bytes) }

        // Share via system chooser so user can save wherever they want
        val uri = FileProvider.getUriForFile(
            this,
            "${packageName}.fileprovider",
            shareFile
        )
        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = "application/json"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(shareIntent, "保存备份文件到..."))

        // If direct write also succeeded, the file is in two places
    }

    private fun tryWriteToPublicDownloads(fileName: String, bytes: ByteArray): String? {
        return try {
            if (Build.VERSION.SDK_INT >= 29) {
                // Android 10+: Use app-specific external directory (visible in file manager)
                val dir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                    ?: return null
                val myDir = File(dir, "MyItems")
                if (!myDir.exists() && !myDir.mkdirs()) return null
                val file = File(myDir, fileName)
                FileOutputStream(file).use { it.write(bytes) }
                file.absolutePath
            } else {
                // Android 9-: Direct write to public Downloads (no permission needed in app context)
                val downloads = Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_DOWNLOADS
                )
                val myDir = File(downloads, "MyItems")
                if (!myDir.exists() && !myDir.mkdirs()) return null
                val file = File(myDir, fileName)
                FileOutputStream(file).use { it.write(bytes) }
                file.absolutePath
            }
        } catch (_: Exception) {
            null
        }
    }
}
