package com.afalphy.sylvakru.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.util.LruCache
import android.widget.RemoteViews
import com.afalphy.sylvakru.MainActivity
import com.afalphy.sylvakru.R
import java.io.File

/**
 * Builds the home screen widget views from the state the Flutter side pushed.
 *
 * Everything is flat by design: a solid rounded panel, monochrome icons and
 * text, no gradients or accent colours.
 */
object MusicWidgetRenderer {
    // Hard caps on top of the layouts' `maxLines="1" + ellipsize="end"`, so a very
    // long value cannot fill the whole widget before the width limit kicks in.
    private const val MAX_TITLE = 28
    private const val MAX_ARTIST = 32
    private const val MAX_LYRIC = 48

    // Cover cache files are square; 256px covers the 72dp slot even at 3x.
    private const val COVER_BOUND = 256
    private const val COVER_RADIUS_DP = 10f

    /// The 4x2 widget's progress bar is covered by this many invisible segments;
    /// a widget click cannot report a tap position, so each segment seeks to its
    /// share of the track.
    const val SEEK_SEGMENTS = 10

    private val seekIds = intArrayOf(
        R.id.widget_seek_1,
        R.id.widget_seek_2,
        R.id.widget_seek_3,
        R.id.widget_seek_4,
        R.id.widget_seek_5,
        R.id.widget_seek_6,
        R.id.widget_seek_7,
        R.id.widget_seek_8,
        R.id.widget_seek_9,
        R.id.widget_seek_10,
    )

    private val coverCache = LruCache<String, Bitmap>(4)
    private var transparentCover: Bitmap? = null

    private fun emptyCover(): Bitmap =
        transparentCover ?: Bitmap
            .createBitmap(1, 1, Bitmap.Config.ARGB_8888)
            .also { transparentCover = it }

    fun update(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
        data: SharedPreferences,
        detailed: Boolean,
    ) {
        val state = MusicWidgetStore.read(data)
        for (id in ids) {
            manager.updateAppWidget(id, build(context, id, state, detailed))
        }
    }

    private fun build(
        context: Context,
        widgetId: Int,
        state: MusicWidgetState,
        detailed: Boolean,
    ): RemoteViews {
        val layout = if (detailed) R.layout.widget_player_4x2 else R.layout.widget_player_2x2
        val views = RemoteViews(context.packageName, layout)

        val title = if (state.hasSong) {
            MusicWidgetStore.ellipsize(state.title, MAX_TITLE)
        } else {
            context.getString(R.string.widget_empty_title)
        }
        views.setTextViewText(R.id.widget_title, title)
        views.setTextViewText(
            R.id.widget_artist,
            MusicWidgetStore.ellipsize(state.artist, MAX_ARTIST),
        )
        if (detailed) {
            views.setTextViewText(
                R.id.widget_lyric,
                MusicWidgetStore.ellipsize(state.lyric, MAX_LYRIC),
            )
            views.setTextViewText(R.id.widget_position, clock(state.positionMillis))
            views.setTextViewText(R.id.widget_duration, clock(state.durationMillis))
            views.setProgressBar(
                R.id.widget_progress,
                PROGRESS_STEPS,
                progressOf(state),
                false,
            )
            for (segment in 1..SEEK_SEGMENTS) {
                views.setOnClickPendingIntent(
                    seekIds[segment - 1],
                    seek(context, widgetId, segment),
                )
            }
        }

        val cover = coverBitmap(context, state.coverPath)
        // A transparent 1x1 rather than a null bitmap: setting null through
        // RemoteViews is not reliably supported, and this keeps the rounded
        // placeholder background of the view visible.
        views.setImageViewBitmap(R.id.widget_cover, cover ?: emptyCover())

        views.setImageViewResource(
            R.id.widget_toggle,
            if (state.isPlaying) R.drawable.ic_widget_pause_filled else R.drawable.ic_widget_play_filled,
        )
        views.setContentDescription(
            R.id.widget_toggle,
            context.getString(
                if (state.isPlaying) R.string.widget_action_pause else R.string.widget_action_play,
            ),
        )

        views.setOnClickPendingIntent(
            R.id.widget_prev,
            action(context, widgetId, MusicWidgetActionReceiver.ACTION_PREVIOUS, 1, state.isPlaying),
        )
        views.setOnClickPendingIntent(
            R.id.widget_next,
            action(context, widgetId, MusicWidgetActionReceiver.ACTION_NEXT, 2, state.isPlaying),
        )
        views.setOnClickPendingIntent(
            R.id.widget_toggle,
            action(context, widgetId, MusicWidgetActionReceiver.ACTION_TOGGLE, 3, state.isPlaying),
        )
        views.setOnClickPendingIntent(R.id.widget_root, openApp(context, widgetId))
        return views
    }

    private const val PROGRESS_STEPS = 1000

    private fun progressOf(state: MusicWidgetState): Int {
        if (state.durationMillis <= 0) {
            return 0
        }
        val ratio = state.positionMillis.toLong() * PROGRESS_STEPS /
            state.durationMillis
        return ratio.toInt().coerceIn(0, PROGRESS_STEPS)
    }

    private fun clock(millis: Int): String {
        if (millis <= 0) {
            return "--:--"
        }
        val seconds = millis / 1000
        val hours = seconds / 3600
        val minutes = (seconds % 3600) / 60
        val rest = seconds % 60
        return if (hours > 0) {
            "%d:%02d:%02d".format(hours, minutes, rest)
        } else {
            "%02d:%02d".format(minutes, rest)
        }
    }

    private fun seek(context: Context, widgetId: Int, segment: Int): PendingIntent {
        val intent = Intent(context, MusicWidgetActionReceiver::class.java).apply {
            action = MusicWidgetActionReceiver.ACTION_SEEK
            putExtra(MusicWidgetActionReceiver.EXTRA_SEGMENT, segment)
        }
        return PendingIntent.getBroadcast(
            context,
            widgetId * 100 + segment,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun action(
        context: Context,
        widgetId: Int,
        action: String,
        slot: Int,
        isPlaying: Boolean,
    ): PendingIntent {
        val intent = Intent(context, MusicWidgetActionReceiver::class.java).apply {
            this.action = action
            putExtra(MusicWidgetActionReceiver.EXTRA_IS_PLAYING, isPlaying)
        }
        return PendingIntent.getBroadcast(
            context,
            widgetId * 10 + slot,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun openApp(context: Context, widgetId: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            context,
            widgetId * 10 + 9,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** Rounded, centre-cropped cover, or null when there is nothing to show. */
    private fun coverBitmap(context: Context, path: String?): Bitmap? {
        if (path.isNullOrEmpty()) return null

        val file = File(path)
        if (!file.isFile) return null

        // The key has to include the file's identity, not just its path:
        // home_widget overwrites the *same* cover file on every track change, so a
        // path-only key would keep serving the previous track's artwork (which is
        // exactly why the cover only refreshed after restarting the app).
        val cacheKey = "$path|${file.length()}|${file.lastModified()}"
        coverCache.get(cacheKey)?.let { return it }

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        val options = BitmapFactory.Options().apply {
            inSampleSize = sampleSize(bounds.outWidth, bounds.outHeight, COVER_BOUND)
        }
        val decoded = BitmapFactory.decodeFile(path, options) ?: return null

        val radius = COVER_RADIUS_DP * context.resources.displayMetrics.density
        val rounded = rounded(decoded, radius)
        coverCache.put(cacheKey, rounded)
        return rounded
    }

    private fun sampleSize(width: Int, height: Int, bound: Int): Int {
        var sample = 1
        var w = width
        var h = height
        while (w / 2 >= bound && h / 2 >= bound) {
            w /= 2
            h /= 2
            sample *= 2
        }
        return sample
    }

    private fun rounded(source: Bitmap, radiusPx: Float): Bitmap {
        val size = minOf(source.width, source.height)
        val square = if (source.width == size && source.height == size) {
            source
        } else {
            Bitmap.createBitmap(
                source,
                (source.width - size) / 2,
                (source.height - size) / 2,
                size,
                size,
            )
        }

        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = BitmapShader(square, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        }
        Canvas(output).drawRoundRect(
            RectF(0f, 0f, size.toFloat(), size.toFloat()),
            radiusPx,
            radiusPx,
            paint,
        )
        return output
    }
}