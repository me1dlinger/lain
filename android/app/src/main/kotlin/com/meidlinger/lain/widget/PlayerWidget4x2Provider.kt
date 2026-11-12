package com.meidlinger.lain.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import es.antonborri.home_widget.HomeWidgetProvider

/** 4x2 player: the 2x2 content plus the current lyric line. */
class PlayerWidget4x2Provider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        MusicWidgetRenderer.update(
            context,
            appWidgetManager,
            appWidgetIds,
            widgetData,
            withLyrics = true,
        )
    }
}
