package com.meidlinger.sylvakru.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import es.antonborri.home_widget.HomeWidgetProvider

/** 2x2 player: cover, title, artist and the three playback controls. */
class PlayerWidget2x2Provider : HomeWidgetProvider() {
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
            withLyrics = false,
        )
    }
}
