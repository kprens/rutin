package com.alper.rutin

import android.appwidget.AppWidgetManager
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

/// Ana ekran widget'ı — o günün alışkanlıklarını (en fazla 5) gösterir.
/// Flutter tarafı (bkz. lib/home_widget_service.dart) veriyi
/// `rutin_widget_tasks` anahtarında bir JSON dizisi olarak SharedPreferences'a
/// yazar: [{"id":1,"name":"Su iç","emoji":"💧","done":false}, ...].
///
/// Bir satıra dokunmak, uygulamayı AÇMADAN `HomeWidgetBackgroundIntent` ile
/// Flutter'ın arka plan callback'ini (backgroundCallback, ayrı/minimal bir
/// Flutter motorunda) tetikler; o da JSON'daki "done" bayrağını çevirip
/// widget'ı hemen günceller. Widget'ın kendi başlığına dokunmak ise
/// uygulamayı açar (HomeWidgetLaunchIntent).
class HabitWidgetProvider : HomeWidgetProvider() {

    private val rowIds = intArrayOf(
        R.id.widget_row_0, R.id.widget_row_1, R.id.widget_row_2,
        R.id.widget_row_3, R.id.widget_row_4
    )
    private val emojiIds = intArrayOf(
        R.id.widget_emoji_0, R.id.widget_emoji_1, R.id.widget_emoji_2,
        R.id.widget_emoji_3, R.id.widget_emoji_4
    )
    private val nameIds = intArrayOf(
        R.id.widget_name_0, R.id.widget_name_1, R.id.widget_name_2,
        R.id.widget_name_3, R.id.widget_name_4
    )
    private val checkIds = intArrayOf(
        R.id.widget_check_0, R.id.widget_check_1, R.id.widget_check_2,
        R.id.widget_check_3, R.id.widget_check_4
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            // Widget çizimi ASLA yayın alıcısını çökertmemeli.
            //
            // onUpdate'te fırlayan her istisna Android tarafından
            // "RuntimeException: Unable to start receiver" olarak yüzeye
            // çıkar; kullanıcı, uygulamayı hiç açmamışken çökme görür.
            // Ana ekran widget'ı ikincil bir özellik — çizilemiyorsa
            // sessizce atlanmalı, uygulamayı aşağı çekmemeli.
            //
            // Sahada gerçekleşti (Sentry RUTIN-6, ölümcül, Android 16 /
            // Galaxy S25): home_widget 0.6.0 aşağıdaki
            // HomeWidgetLaunchIntent.getActivity çağrısında PendingIntent'i
            // `pendingIntentBackgroundActivityStartMode` ile oluşturuyordu.
            // Android 15+ bunu OLUŞTURMA anında reddediyor
            // (IllegalArgumentException); paket 0.7.0+1'de SDK 35+ için
            // `setPendingIntentCreatorBackgroundActivityStartMode`'a geçerek
            // düzeltildi ve bağımlılık oraya yükseltildi.
            //
            // Bu try/catch çökmeyi durdurur ama widget'ı ONARMAZ: istisna
            // updateAppWidget'tan ÖNCE atıldığı için widget boş/eski kalır.
            // Yani asıl düzeltme sürüm yükseltmesi; burası emniyet ağı.
            try {
                renderWidget(context, appWidgetManager, widgetId, widgetData)
            } catch (e: Exception) {
                // Yutuluyor: bir sonraki güncelleme döngüsünde tekrar denenir.
            }
        }
    }

    private fun renderWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        widgetData: android.content.SharedPreferences
    ) {
        val views = RemoteViews(context.packageName, R.layout.habit_widget)

        val summary = widgetData.getString("rutin_widget_summary", "") ?: ""
        views.setTextViewText(R.id.widget_summary, summary)

        // Başlığa/boşluğa dokunmak uygulamayı açar.
        val launchPending = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
        views.setOnClickPendingIntent(R.id.widget_title, launchPending)
        views.setOnClickPendingIntent(R.id.widget_summary, launchPending)

        val tasksJson = widgetData.getString("rutin_widget_tasks", null)
        val tasks = try {
            if (tasksJson != null) JSONArray(tasksJson) else JSONArray()
        } catch (e: Exception) {
            JSONArray()
        }

        for (i in rowIds.indices) {
            // optJSONObject: getJSONObject try bloğunun DIŞINDAYDI ve
            // dizide nesne olmayan bir eleman varsa fırlatıp alıcıyı
            // çökertiyordu. Bozuk eleman artık satırı gizletir, yeter.
            val task = if (i < tasks.length()) tasks.optJSONObject(i) else null
            if (task != null) {
                val id = task.optInt("id")
                val name = task.optString("name")
                val emoji = task.optString("emoji", "✅")
                val done = task.optBoolean("done", false)

                views.setViewVisibility(rowIds[i], android.view.View.VISIBLE)
                views.setTextViewText(emojiIds[i], emoji)
                views.setTextViewText(nameIds[i], name)
                views.setImageViewResource(
                    checkIds[i],
                    if (done) R.drawable.widget_check_on else R.drawable.widget_check_off
                )

                val togglePending = HomeWidgetBackgroundIntent.getBroadcast(
                    context, android.net.Uri.parse("homeWidget://toggle?id=$id")
                )
                views.setOnClickPendingIntent(rowIds[i], togglePending)
            } else {
                views.setViewVisibility(rowIds[i], android.view.View.GONE)
            }
        }

        appWidgetManager.updateAppWidget(widgetId, views)
    }
}
