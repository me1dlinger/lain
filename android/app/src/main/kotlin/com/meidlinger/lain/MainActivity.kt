package com.meidlinger.lain

import com.ryanheise.audioservice.AudioServiceActivity

import android.content.Intent
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.storage.StorageManager
import android.provider.DocumentsContract
import android.hardware.input.InputManager
import android.os.Handler
import android.os.Looper
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.flame_engine.gamepads_android.GamepadsCompatibleActivity
import java.io.File

class MainActivity: AudioServiceActivity(), GamepadsCompatibleActivity {
    var keyListener: ((KeyEvent) -> Boolean)? = null
    var motionListener: ((MotionEvent) -> Boolean)? = null

    private var audioFocusController: AudioFocusController? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Reports the system HTTP proxy (Wi-Fi/global proxy); Dart reads it via
        // the com.meidlinger.lain.system_proxy channel to route Dio and libmpv. VPN-mode
        // (TUN) proxies capture traffic transparently without a proxy config,
        // so this returns null then.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.meidlinger.lain.system_proxy").setMethodCallHandler { call, result ->
            when (call.method) {
                "getProxy" -> result.success(getSystemProxy())
                else -> result.notImplemented()
            }
        }

        // Audio focus is owned here, not by audio_session: Android's focus
        // request cannot be changed in place, so switching exclusive/duck/mix
        // needs an explicit abandon + request. The raw focus code is forwarded
        // to the Dart interruption controller.
        val focusChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.meidlinger.lain.audio_focus"
        )
        audioFocusController = AudioFocusController(
            this,
            onFocusChange = { code ->
                focusChannel.invokeMethod("onAudioFocusChange", code)
            },
            onNoisy = {
                focusChannel.invokeMethod("onAudioBecomingNoisy", null)
            },
        )
        focusChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "request" -> {
                    val mode = call.argument<String>("mode") ?: "exclusive"
                    result.success(audioFocusController?.request(mode) ?: false)
                }
                "abandon" -> {
                    audioFocusController?.abandon()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Turns an app-private cover file into a content:// URI (media_provider
        // FileProvider) so the media session metadata can carry artwork that
        // car head units are able to fetch. Returns null when the file is not
        // covered by the provider's configured paths.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.meidlinger.lain.media").setMethodCallHandler { call, result ->
            when (call.method) {
                "getContentUri" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrEmpty()) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    try {
                        val uri = FileProvider.getUriForFile(
                            this,
                            "$packageName.media_provider",
                            File(path)
                        )
                        result.success(uri.toString())
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }
                "shareFile" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrEmpty()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        val uri = FileProvider.getUriForFile(
                            this,
                            "$packageName.media_provider",
                            File(path)
                        )
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = "image/png"
                            putExtra(Intent.EXTRA_STREAM, uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(Intent.createChooser(intent, "Lain"))
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "isMusicActive" -> {
                    try {
                        val manager = getSystemService(AUDIO_SERVICE) as AudioManager
                        result.success(manager.isMusicActive)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "getAudioOutputInfo" -> {
                    try {
                        val manager = getSystemService(AUDIO_SERVICE) as AudioManager
                        val rate = manager.getProperty(
                            AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE
                        )?.toIntOrNull()
                        val frames = manager.getProperty(
                            AudioManager.PROPERTY_OUTPUT_FRAMES_PER_BUFFER
                        )?.toIntOrNull()
                        val devices = manager.getDevices(
                            AudioManager.GET_DEVICES_OUTPUTS
                        ).map { device ->
                            mapOf(
                                "type" to device.type,
                                "name" to (
                                    device.productName?.toString()
                                        ?: device.type.toString()
                                )
                            )
                        }
                        result.success(
                            mapOf(
                                "sampleRate" to rate,
                                "framesPerBuffer" to frames,
                                "devices" to devices
                            )
                        )
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }
                "showInFolder" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrEmpty()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        val folder = File(path).parentFile ?: File(path)
                        val uri = folderDocumentUri(folder)
                        val view = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(
                                uri,
                                DocumentsContract.Document.MIME_TYPE_DIR
                            )
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        try {
                            startActivity(view)
                            result.success(true)
                            return@setMethodCallHandler
                        } catch (_: Exception) {
                            // Some devices have no handler for a folder URI;
                            // the document picker still opens at the folder.
                        }
                        val picker = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            type = "*/*"
                            putExtra(DocumentsContract.EXTRA_INITIAL_URI, uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(picker)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "getFileCreatedTimes" -> {
                    val paths = call.argument<List<String>>("paths")
                    if (paths == null) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    // Stat-ing a whole library must not run on the main thread.
                    Thread {
                        val times = paths.map { fileCreatedTime(it) }
                        Handler(Looper.getMainLooper()).post { result.success(times) }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }

        // Whether the active network is cellular. Dart uses it for the
        // one-time data reminder before streaming starts.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.meidlinger.lain.mobile_network").setMethodCallHandler { call, result ->
            when (call.method) {
                "isCellular" -> result.success(isCellularData())
                else -> result.notImplemented()
            }
        }
    }

    // The DocumentsUI id of a folder on shared storage: "primary:Music/..."
    // for internal storage, "<uuid>:Music/..." for an SD card. This is what
    // lets "show in folder" open the system file browser at the right place.
    private fun folderDocumentUri(folder: File): Uri {
        val storage = getSystemService(StorageManager::class.java)
        val volume = try {
            storage?.getStorageVolume(folder)
        } catch (_: Exception) {
            null
        }
        val root = volume?.directory ?: Environment.getExternalStorageDirectory()
        val relative = try {
            folder.canonicalFile.relativeTo(root.canonicalFile).path
        } catch (_: Exception) {
            folder.name
        }
        val prefix = when {
            volume == null || volume.isPrimary -> "primary"
            else -> volume.uuid ?: "primary"
        }
        return DocumentsContract.buildDocumentUri(
            "com.android.externalstorage.documents",
            "$prefix:$relative"
        )
    }

    private fun isCellularData(): Boolean {
        return try {
            val manager = getSystemService(CONNECTIVITY_SERVICE) as? ConnectivityManager
            val network = manager?.activeNetwork ?: return false
            val capabilities = manager.getNetworkCapabilities(network) ?: return false
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) &&
                !capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) &&
                !capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) &&
                !capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
        } catch (_: Exception) {
            false
        }
    }

    // Birth ("added") time of a file. java.nio exposes the real creation time
    // on API 26+; older devices and file systems that do not keep one fall back
    // to the last-modified time.
    private fun fileCreatedTime(path: String): Long? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val attributes = java.nio.file.Files.readAttributes(
                    java.nio.file.Paths.get(path),
                    java.nio.file.attribute.BasicFileAttributes::class.java
                )
                val millis = attributes.creationTime().toMillis()
                if (millis > 0) {
                    return millis
                }
            } catch (_: Exception) {
            }
        }
        return try {
            File(path).lastModified().takeIf { it > 0 }
        } catch (_: Exception) {
            null
        }
    }

    private fun getSystemProxy(): String? {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val info = (getSystemService(CONNECTIVITY_SERVICE) as? ConnectivityManager)?.defaultProxy
                if (info != null && !info.host.isNullOrEmpty() && info.port != 0) {
                    return "http://${info.host}:${info.port}"
                }
            }

            val host = System.getProperty("http.proxyHost")
            val port = System.getProperty("http.proxyPort")?.toIntOrNull()
            if (!host.isNullOrEmpty() && port != null && port != 0) {
                return "http://$host:$port"
            }
        } catch (_: Exception) {
        }
        return null
    }

    override fun dispatchGenericMotionEvent(motionEvent: MotionEvent): Boolean {
        return motionListener?.invoke(motionEvent) ?: false
    }

    override fun dispatchKeyEvent(keyEvent: KeyEvent): Boolean {
        if (keyListener?.invoke(keyEvent) == true) {
            return true
        }
        return super.dispatchKeyEvent(keyEvent)
    }

    override fun registerInputDeviceListener(
      listener: InputManager.InputDeviceListener, handler: Handler?) {
        val inputManager = getSystemService(INPUT_SERVICE) as InputManager
        inputManager.registerInputDeviceListener(listener, null)
    }

    override fun registerKeyEventHandler(handler: (KeyEvent) -> Boolean) {
        keyListener = handler
    }

    override fun registerMotionEventHandler(handler: (MotionEvent) -> Boolean) {
        motionListener = handler
    }

    override fun onDestroy() {
        audioFocusController?.abandon()
        audioFocusController = null
        super.onDestroy()
    }
}
