package com.afalphy.sylvakru

import com.ryanheise.audioservice.AudioServiceActivity

import android.net.ConnectivityManager
import android.os.Build
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Reports the system HTTP proxy (Wi-Fi/global proxy); Dart reads it via
        // the com.afalphy.system_proxy channel to route Dio and libmpv. VPN-mode
        // (TUN) proxies capture traffic transparently without a proxy config,
        // so this returns null then.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.afalphy.system_proxy").setMethodCallHandler { call, result ->
            when (call.method) {
                "getProxy" -> result.success(getSystemProxy())
                else -> result.notImplemented()
            }
        }

        // Turns an app-private cover file into a content:// URI (media_provider
        // FileProvider) so the media session metadata can carry artwork that
        // car head units are able to fetch. Returns null when the file is not
        // covered by the provider's configured paths.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.afalphy.media").setMethodCallHandler { call, result ->
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
}
