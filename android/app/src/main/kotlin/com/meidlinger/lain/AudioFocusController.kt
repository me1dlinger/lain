package com.meidlinger.lain

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build

/**
 * Audio focus handling modelled on ExoPlayer's AudioFocusManager.
 *
 * The player itself decides whether to pause, duck or keep playing when focus
 * changes. This class only asks Android for the right focus type and forwards
 * the raw focus code, instead of letting a plugin keep an old focus request
 * alive when the user switches playback mode.
 */
class AudioFocusController(
    private val context: Context,
    private val onFocusChange: (Int) -> Unit,
    private val onNoisy: () -> Unit,
) {
    private val noisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                onNoisy()
            }
        }
    }
    private var noisyRegistered = false

    private val audioManager: AudioManager
        get() = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private var request: AudioFocusRequest? = null
    private var legacyListener: AudioManager.OnAudioFocusChangeListener? = null

    fun request(mode: String): Boolean {
        abandon()
        // Mix means exactly that: no focus request, so every app keeps playing.
        if (mode == "mix") {
            registerNoisy()
            return true
        }
        // Music always requests AUDIOFOCUS_GAIN, as ExoPlayer does. The
        // player's mode decides how to react when another app asks us to duck;
        // requesting GAIN_TRANSIENT_MAY_DUCK here would make this app the
        // transient one and it would never receive a can-duck event.
        val gain = AudioManager.AUDIOFOCUS_GAIN
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()
            val listener = AudioManager.OnAudioFocusChangeListener { focus ->
                // A permanent loss invalidates this request. Release it here,
                // like ExoPlayer, instead of leaving a dead request registered.
                if (focus == AudioManager.AUDIOFOCUS_LOSS) {
                    abandon()
                }
                onFocusChange(focus)
            }
            val next = AudioFocusRequest.Builder(gain)
                .setAudioAttributes(attributes)
                .setWillPauseWhenDucked(mode == "exclusive")
                .setOnAudioFocusChangeListener(listener)
                .build()
            return if (
                audioManager.requestAudioFocus(next) ==
                AudioManager.AUDIOFOCUS_REQUEST_GRANTED
            ) {
                request = next
                registerNoisy()
                true
            } else {
                false
            }
        }

        val listener = AudioManager.OnAudioFocusChangeListener { focus ->
            if (focus == AudioManager.AUDIOFOCUS_LOSS) {
                abandon()
            }
            onFocusChange(focus)
        }
        val status = audioManager.requestAudioFocus(
            listener,
            AudioManager.STREAM_MUSIC,
            gain,
        )
        if (status == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
            legacyListener = listener
            registerNoisy()
            return true
        }
        return false
    }

    fun abandon() {
        unregisterNoisy()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            request?.let { audioManager.abandonAudioFocusRequest(it) }
            request = null
        } else {
            legacyListener?.let {
                audioManager.abandonAudioFocus(it)
            }
            legacyListener = null
        }
    }

    private fun registerNoisy() {
        if (noisyRegistered) return
        val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(
                noisyReceiver,
                filter,
                Context.RECEIVER_NOT_EXPORTED,
            )
        } else {
            context.registerReceiver(noisyReceiver, filter)
        }
        noisyRegistered = true
    }

    private fun unregisterNoisy() {
        if (!noisyRegistered) return
        try {
            context.unregisterReceiver(noisyReceiver)
        } catch (_: Exception) {
        }
        noisyRegistered = false
    }
}
