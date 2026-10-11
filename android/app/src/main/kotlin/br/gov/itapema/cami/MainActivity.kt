package br.gov.itapema.cami

import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Ikev2VpnProfile
import android.net.VpnManager
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private companion object {
        const val MEDIA_CHANNEL = "br.gov.itapema.cami/media"
        const val VPN_CHANNEL = "br.gov.itapema.cami/vpn"
        const val STORAGE_PERMISSION_REQUEST = 741
        const val VPN_CONSENT_REQUEST = 742
    }

    private var pendingSnapshot: ByteArray? = null
    private var pendingSnapshotResult: MethodChannel.Result? = null
    private var pendingVpnResult: MethodChannel.Result? = null

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VPN_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "connect" -> connectVpn(result)
                    "disconnect" -> disconnectVpn(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun connectVpn(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            result.error(
                "unsupported_android_version",
                "A VPN automática requer Android 11 ou superior.",
                null,
            )
            return
        }
        if (BuildConfig.CAMI_VPN_SERVER.isBlank() ||
            BuildConfig.CAMI_VPN_REMOTE_ID.isBlank() ||
            BuildConfig.CAMI_VPN_PSK.isBlank()) {
            result.error(
                "vpn_not_configured",
                "Configure CAMI_VPN_SERVER, CAMI_VPN_REMOTE_ID e CAMI_VPN_PSK em android/local.properties e gere um novo APK.",
                null,
            )
            return
        }
        if (pendingVpnResult != null) {
            result.error("vpn_consent_pending", "A autorização da VPN já está aberta.", null)
            return
        }

        try {
            val profile = Ikev2VpnProfile.Builder(
                BuildConfig.CAMI_VPN_SERVER,
                BuildConfig.CAMI_VPN_REMOTE_ID,
            ).setAuthPsk(BuildConfig.CAMI_VPN_PSK.toByteArray(Charsets.UTF_8))
                .setBypassable(false)
                .build()
            val manager = getSystemService(VpnManager::class.java)
            val consentIntent = manager.provisionVpnProfile(profile)
            if (consentIntent == null) {
                startProvisionedVpn(manager)
                result.success("connected")
            } else {
                pendingVpnResult = result
                startActivityForResult(consentIntent, VPN_CONSENT_REQUEST)
            }
        } catch (error: Exception) {
            result.error("vpn_connection_failed", "Não foi possível iniciar a VPN.", error.message)
        }
    }

    private fun startProvisionedVpn(manager: VpnManager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            manager.startProvisionedVpnProfileSession()
        } else {
            @Suppress("DEPRECATION")
            manager.startProvisionedVpnProfile()
        }
    }

    private fun disconnectVpn(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            result.success(false)
            return
        }
        try {
            getSystemService(VpnManager::class.java).stopProvisionedVpnProfile()
            result.success(true)
        } catch (error: Exception) {
            result.error("vpn_disconnect_failed", "Não foi possível desconectar a VPN.", error.message)
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

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != VPN_CONSENT_REQUEST) return
        val result = pendingVpnResult ?: return
        pendingVpnResult = null
        if (resultCode != RESULT_OK) {
            result.error("vpn_consent_denied", "A autorização da VPN foi negada.", null)
            return
        }
        try {
            startProvisionedVpn(getSystemService(VpnManager::class.java))
            result.success("connected")
        } catch (error: Exception) {
            result.error("vpn_connection_failed", "Não foi possível iniciar a VPN.", error.message)
        }
    }
}
