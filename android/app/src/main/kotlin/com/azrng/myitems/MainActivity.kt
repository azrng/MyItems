package com.azrng.myitems

import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private var pendingBackupExport: PendingBackupExport? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "my_items/system")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openUrl" -> {
                        val url = call.argument<String>("url")
                        if (url.isNullOrBlank()) {
                            result.error("INVALID_URL", "URL 不能为空", null)
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
                            result.error("INVALID_BACKUP", "备份文件名或内容为空", null)
                            return@setMethodCallHandler
                        }
                        saveBackupToDownloads(fileName, content, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun saveBackupToDownloads(
        fileName: String,
        content: String,
        result: MethodChannel.Result
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            if (pendingBackupExport != null) {
                result.error("EXPORT_PENDING", "已有备份导出正在等待授权", null)
                return
            }
            pendingBackupExport = PendingBackupExport(fileName, content, result)
            requestPermissions(
                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                REQUEST_WRITE_BACKUP
            )
            return
        }

        writeBackupFile(fileName, content, result)
    }

    private fun writeBackupFile(
        fileName: String,
        content: String,
        result: MethodChannel.Result
    ) {
        try {
            val safeFileName = sanitizeFileName(fileName)
            val bytes = content.toByteArray(Charsets.UTF_8)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, safeFileName)
                    put(MediaStore.Downloads.MIME_TYPE, "application/json")
                    put(
                        MediaStore.Downloads.RELATIVE_PATH,
                        Environment.DIRECTORY_DOWNLOADS + "/MyItems"
                    )
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }
                val uri = contentResolver.insert(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    values
                ) ?: throw IllegalStateException("无法创建下载文件")
                contentResolver.openOutputStream(uri, "wt").use { output ->
                    if (output == null) {
                        throw IllegalStateException("无法打开下载文件")
                    }
                    output.write(bytes)
                }
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
                result.success("Download/MyItems/$safeFileName")
            } else {
                val downloads = Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_DOWNLOADS
                )
                val directory = File(downloads, "MyItems")
                if (!directory.exists() && !directory.mkdirs()) {
                    throw IllegalStateException("无法创建目录：${directory.absolutePath}")
                }
                val file = File(directory, safeFileName)
                FileOutputStream(file).use { output -> output.write(bytes) }
                result.success(file.absolutePath)
            }
        } catch (error: Exception) {
            result.error("SAVE_BACKUP_FAILED", error.message, null)
        }
    }

    private fun sanitizeFileName(fileName: String): String {
        return fileName.replace(Regex("""[\\/:*?"<>|]"""), "_")
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_WRITE_BACKUP) return

        val pending = pendingBackupExport ?: return
        pendingBackupExport = null
        if (grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        ) {
            writeBackupFile(pending.fileName, pending.content, pending.result)
        } else {
            pending.result.error("PERMISSION_DENIED", "未授予写入下载目录权限", null)
        }
    }

    private data class PendingBackupExport(
        val fileName: String,
        val content: String,
        val result: MethodChannel.Result
    )

    companion object {
        private const val REQUEST_WRITE_BACKUP = 9301
    }
}
