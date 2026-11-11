package com.meidlinger.sylvakru.widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.view.KeyEvent
import com.meidlinger.sylvakru.MainActivity
import com.ryanheise.audioservice.AudioService

/**
 * Handles the widget buttons.
 *
 * Previous / play-pause / next are driven as media buttons: `AudioService` handles
 * `ACTION_MEDIA_BUTTON` in `onStartCommand` and forwards the key event to the Dart
 * handler, so they work while the playback service is alive without the Flutter
 * UI being on screen.
 */
class MusicWidgetActionReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_PREVIOUS = "com.meidlinger.sylvakru.widget.PREVIOUS"
        const val ACTION_NEXT = "com.meidlinger.sylvakru.widget.NEXT"
        const val ACTION_TOGGLE = "com.meidlinger.sylvakru.widget.TOGGLE"
        const val EXTRA_IS_PLAYING = "isPlaying"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val keyCode = when (intent.action) {
            ACTION_PREVIOUS -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
            ACTION_NEXT -> KeyEvent.KEYCODE_MEDIA_NEXT
            ACTION_TOGGLE -> if (intent.getBooleanExtra(EXTRA_IS_PLAYING, false)) {
                KeyEvent.KEYCODE_MEDIA_PAUSE
            } else {
                KeyEvent.KEYCODE_MEDIA_PLAY
            }
            else -> return
        }
        dispatchMediaButton(context, keyCode)
    }

    private fun dispatchMediaButton(context: Context, keyCode: Int) {
        val intent = Intent(context, AudioService::class.java).apply {
            action = Intent.ACTION_MEDIA_BUTTON
            putExtra(
                Intent.EXTRA_KEY_EVENT,
                KeyEvent(KeyEvent.ACTION_DOWN, keyCode),
            )
        }
        try {
            context.startService(intent)
        } catch (_: Exception) {
            // Nothing is playing (or the process cannot start the service from
            // the background): bring the app up instead of doing nothing.
            openApp(context)
        }
    }

    private fun openApp(context: Context) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        try {
            context.startActivity(intent)
        } catch (_: Exception) {
        }
    }
}