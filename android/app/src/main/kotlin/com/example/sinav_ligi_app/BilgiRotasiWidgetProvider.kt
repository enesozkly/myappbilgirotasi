package com.sonerlerbilisim.bilgirotasi

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class BilgiRotasiWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val name = widgetData.getString("br_name", "Bilgi Rotası") ?: "Bilgi Rotası"
            val energy = widgetData.getInt("br_energy", 0)
            val maxEnergy = widgetData.getInt("br_maxEnergy", 50)
            val bonusEnergy = widgetData.getInt("br_bonusEnergy", 0)
            val totalXp = widgetData.getInt("br_totalXp", 0)
            val league = widgetData.getString("br_league", "Bronz") ?: "Bronz"
            val streak = widgetData.getInt("br_streak", 0)
            val yksDays = widgetData.getInt("br_yksDays", 0)

            val energyText = if (bonusEnergy > 0) {
                "⚡ Enerji: $energy/$maxEnergy +$bonusEnergy"
            } else {
                "⚡ Enerji: $energy/$maxEnergy"
            }

            val views = RemoteViews(context.packageName, R.layout.bilgi_rotasi_widget).apply {
                setTextViewText(R.id.widget_title, "Bilgi Rotası")
                setTextViewText(R.id.widget_subtitle, name)
                setTextViewText(R.id.widget_energy, energyText)
                setTextViewText(R.id.widget_streak, "🔥 Seri: $streak gün")
                setTextViewText(R.id.widget_xp, "⭐ XP: $totalXp")
                setTextViewText(R.id.widget_league, "🏆 Lig: $league")
                setTextViewText(R.id.widget_countdown, "YKS’ye $yksDays gün")

                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}