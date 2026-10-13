package br.gov.itapema.cami

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private companion object {
        const val MEDIA_CHANNEL = "br.gov.itapema.cami/media"
        const val STORAGE_PERMISSION_REQUEST = 741
    }

    private var pendingSnapshot: ByteArray? = null
    private var pendingSnapshotResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "saveSnapshot") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null || bytes.isEmpty()) {
                    result.error("invalid_snapshot", "Imagem inválida.", null)
                    return@setMethodCallHandler
                }
                saveSnapshot(bytes, result)
            }
    }

    private fun saveSnapshot(bytes: ByteArray, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            pendingSnapshot = bytes
            pendingSnapshotResult = result
            requestPermissions(
                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                STORAGE_PERMISSION_REQUEST,
            )
            return
        }

        try {
            val fileName = "CAMI_${System.currentTimeMillis()}.jpg"
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/CAMI")
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
            }
            val uri = contentResolver.insert(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                values,
            ) ?: throw IllegalStateException("Não foi possível criar o arquivo.")
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("Não foi possível salvar o arquivo.")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
            }
            result.success("Galeria > CAMI > $fileName")
        } catch (error: Exception) {
            result.error("snapshot_save_failed", "Não foi possível salvar o snapshot.", error.message)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != STORAGE_PERMISSION_REQUEST) return
        val result = pendingSnapshotResult
        val bytes = pendingSnapshot
        pendingSnapshotResult = null
        pendingSnapshot = null
        if (result == null || bytes == null) return
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            saveSnapshot(bytes, result)
        } else {
            result.error("storage_permission_denied", "Permissão para salvar imagens foi negada.", null)
        }
    }

}
