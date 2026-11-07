package com.afalphy.sylvakru.widget

import android.content.SharedPreferences

/** What the Flutter side last pushed through `home_widget`. */
data class MusicWidgetState(
    val title: String?,
    val artist: String?,
    val lyric: String?,
    val coverPath: String?,
    val isPlaying: Boolean,
    val positionMillis: Int,
    val durationMillis: Int,
) {
    val hasSong: Boolean get() = !title.isNullOrBlank()
}

object MusicWidgetStore {
    private const val KEY_TITLE = "title"
    private const val KEY_ARTIST = "artist"
    private const val KEY_LYRICS = "lyrics"
    private const val KEY_LYRICS_INDEX = "lyricsIndex"
    private const val KEY_IS_PLAYING = "is_playing"
    private const val KEY_COVER_PATH = "coverPath"

    // Read by the action receiver as well, to turn a seek tap into a position.
    const val KEY_POSITION = "positionMs"
    const val KEY_DURATION = "durationMs"

    // `home_widget` joins a lyric line's translations to the original text with
    // U+001F; the widget only shows the original line.
    private const val TRANSLATION_SEPARATOR = '\u001F'

    fun read(data: SharedPreferences): MusicWidgetState = MusicWidgetState(
        title = data.getString(KEY_TITLE, null),
        artist = data.getString(KEY_ARTIST, null),
        lyric = currentLyricLine(data),
        coverPath = data.getString(KEY_COVER_PATH, null),
        isPlaying = data.getBoolean(KEY_IS_PLAYING, false),
        positionMillis = data.getInt(KEY_POSITION, 0),
        durationMillis = data.getInt(KEY_DURATION, 0),
    )

    private fun currentLyricLine(data: SharedPreferences): String? {
        val lyrics = data.getString(KEY_LYRICS, null)
        if (lyrics.isNullOrEmpty()) return null
        val index = data.getInt(KEY_LYRICS_INDEX, -1)
        if (index < 0) return null
        val lines = lyrics.split('\n')
        if (index >= lines.size) return null
        return lines[index]
            .substringBefore(TRANSLATION_SEPARATOR)
            .trim()
            .ifEmpty { null }
    }

    /**
     * Collapses the value to one line and caps it at [max] characters, adding an
     * ellipsis when it had to be cut (the layouts also ellipsize by width).
     */
    fun ellipsize(value: String?, max: Int): String {
        val text = value?.replace('\n', ' ')?.trim().orEmpty()
        if (text.length <= max) return text
        return text.take(max).trimEnd() + '…'
    }
}