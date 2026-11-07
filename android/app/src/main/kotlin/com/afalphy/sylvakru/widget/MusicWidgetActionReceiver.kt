package com.afalphy.sylvakru.widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.view.KeyEvent
import com.afalphy.sylvakru.MainActivity
import com.ryanheise.audioservice.AudioService

/**
 * Handles the widget's previous / play-pause / next buttons.
 *
 * Playback is driven through the audio_service MediaSession: `AudioService`
 * handles `ACTION_MEDIA_BUTTON` in `onStartCommand` and forwards the key event
 * to the Dart handler, so the buttons work while the playback service is alive
 * without needing the Flutter UI to be on screen.
 */
class MusicWidgetActionReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_PREVIOUS = "com.afalphy.sylvakru.widget.PREVIOUS"
        const val ACTION_NEXT = "com.afalphy.sylvakru.widget.NEXT"
        const val ACTION_TOGGLE = "com.afalphy.sylvakru.widget.TOGGLE"
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
        dispatch(context, keyCode)
    }

    private fun dispatch(context: Context, keyCode: Int) {
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