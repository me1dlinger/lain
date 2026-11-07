package com.afalphy.sylvakru.widget

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.session.MediaControllerCompat
import android.view.KeyEvent
import com.afalphy.sylvakru.MainActivity
import com.ryanheise.audioservice.AudioService
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Handles the widget buttons.
 *
 * Previous / play-pause / next are driven as media buttons: `AudioService` handles
 * `ACTION_MEDIA_BUTTON` in `onStartCommand` and forwards the key event to the Dart
 * handler, so they work while the playback service is alive without the Flutter
 * UI being on screen.
 *
 * Seeking needs the session's transport controls instead, which is why that path
 * connects a [MediaBrowserCompat] to our own service.
 */
class MusicWidgetActionReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_PREVIOUS = "com.afalphy.sylvakru.widget.PREVIOUS"
        const val ACTION_NEXT = "com.afalphy.sylvakru.widget.NEXT"
        const val ACTION_TOGGLE = "com.afalphy.sylvakru.widget.TOGGLE"
        const val ACTION_SEEK = "com.afalphy.sylvakru.widget.SEEK"
        const val EXTRA_IS_PLAYING = "isPlaying"
        const val EXTRA_SEGMENT = "segment"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_SEEK) {
            seek(context, intent.getIntExtra(EXTRA_SEGMENT, 0))
            return
        }

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

    /// The progress bar is covered by [MusicWidgetRenderer.SEEK_SEGMENTS] fixed
    /// segments, so a tap only says which share of the track was asked for.
    private fun seek(context: Context, segment: Int) {
        if (segment <= 0) {
            return
        }
        val duration = HomeWidgetPlugin.getData(context)
            .getInt(MusicWidgetStore.KEY_DURATION, 0)
        if (duration <= 0) {
            return
        }
        val target = duration.toLong() * segment / MusicWidgetRenderer.SEEK_SEGMENTS

        // The connection is asynchronous and the receiver would be killed before
        // it finishes, so keep it alive until the seek has been sent.
        val pending = goAsync()
        var browser: MediaBrowserCompat? = null
        try {
            browser = MediaBrowserCompat(
                context,
                ComponentName(context, AudioService::class.java),
                object : MediaBrowserCompat.ConnectionCallback() {
                    override fun onConnected() {
                        val connected = browser
                        try {
                            if (connected != null) {
                                MediaControllerCompat(context, connected.sessionToken)
                                    .transportControls
                                    .seekTo(target)
                            }
                        } catch (_: Exception) {
                        } finally {
                            connected?.disconnect()
                            pending.finish()
                        }
                    }

                    override fun onConnectionFailed() {
                        pending.finish()
                    }
                },
                null,
            )
            browser.connect()
        } catch (_: Exception) {
            browser?.disconnect()
            pending.finish()
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