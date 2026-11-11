package com.intersmart.dynamic_notification_kit

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.Icon
import android.os.Build
import android.widget.RemoteViews

@Suppress("UNCHECKED_CAST")
class NotificationEngine(private val ctx: Context, private val sdk: Int = Build.VERSION.SDK_INT) {
    private val nm = ctx.getSystemService(NotificationManager::class.java)

    init { ChannelManager.ensure(ctx) }

    fun notifId(id: String): Int = id.hashCode()

    private fun contentIntent(): PendingIntent? {
        val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName) ?: return null
        return PendingIntent.getActivity(ctx, 0, launch, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    /** API 36.0 has no builder method; the request is the documented extra (same as NotificationCompat). */
    private fun requestPromoted(b: Notification.Builder) {
        b.addExtras(android.os.Bundle().apply { putBoolean("android.requestPromotedOngoing", true) })
    }

    fun canPromote(): Boolean =
        sdk >= 36 && runCatching { nm.canPostPromotedNotifications() }.getOrDefault(false)

    // ---------------------------------------------------------------- delivery
    fun postDelivery(args: Map<String, Any?>) {
        val id = args["id"] as String
        val state = args["state"] as Map<String, Any?>
        val template = args["template"] as Map<String, Any?>
        val progress = args["progress"] as Map<String, Any?>
        val to = (progress["to"] as? Number)?.toFloat()?.coerceIn(0f, 1f) ?: 0f
        val accent = (template["accentColor"] as? Number)?.toInt() ?: 0xFF1E88E5.toInt()
        val emoji = Formatting.vehicleEmoji(state["vehicle"] as? String)
        val status = state["status"] as? String
        val etaMs = (state["etaMs"] as? Number)?.toLong()
        val title = (state["headline"] as? String)
            ?: if (template["type"] == "completed" && status == "delivered")
                (template["message"] as? String ?: "Delivered") else Formatting.statusText(status)
        val parts = listOfNotNull(
            Formatting.etaClock(etaMs)?.let { "Arrives $it" },
            Formatting.distance((state["distanceMeters"] as? Number)?.toDouble(), state["unit"] as? String),
            state["driverName"] as? String,
        )
        val text = parts.joinToString(" · ").ifEmpty { "${(to * 100).toInt()}%" }
        val terminal = status == "delivered" || status == "cancelled"

        val b = Notification.Builder(ctx, ChannelManager.DELIVERY)
            .setSmallIcon(R.drawable.dnk_ic_notification)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(!terminal)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setColor(accent)
            .setContentIntent(contentIntent())
            .setWhen(state["updatedAtMs"].let { (it as? Number)?.toLong() ?: System.currentTimeMillis() })

        when (RenderPath.select(sdk)) {
            RenderPath.PROGRESS_STYLE -> applyProgressStyle(b, to, accent, emoji, etaMs)
            else -> applyRichOngoing(b, to, accent, emoji, title, text)
        }
        nm.notify(notifId(id), b.build())
    }

    private fun applyProgressStyle(b: Notification.Builder, p: Float, accent: Int, emoji: String, etaMs: Long?) {
        val max = 1000
        val done = (p * max).toInt().coerceIn(0, max)
        val segs = mutableListOf<Notification.ProgressStyle.Segment>()
        if (done > 0) segs += Notification.ProgressStyle.Segment(done).setColor(accent)
        if (done < max) segs += Notification.ProgressStyle.Segment(max - done).setColor(Color.LTGRAY)
        val style = Notification.ProgressStyle()
            .setStyledByProgress(false)
            .setProgressSegments(segs)
            .setProgressPoints(listOf(Notification.ProgressStyle.Point(max).setColor(accent)))
            .setProgress(done)
            .setProgressTrackerIcon(Icon.createWithBitmap(TrackRenderer.vehicleIcon(emoji)))
        b.setStyle(style)
        // Live Update (status-bar chip). Only requested when permitted.
        if (canPromote()) {
            requestPromoted(b)
            Formatting.shortCritical(etaMs, System.currentTimeMillis())?.let { b.setShortCriticalText(it) }
        }
    }

    private fun applyRichOngoing(b: Notification.Builder, p: Float, accent: Int, emoji: String, title: String, text: String) {
        val rv = RemoteViews(ctx.packageName, R.layout.dnk_delivery).apply {
            setTextViewText(R.id.dnk_title, title)
            setTextViewText(R.id.dnk_text, text)
            setImageViewBitmap(R.id.dnk_track, TrackRenderer.track(p, emoji, accent))
        }
        b.setStyle(Notification.DecoratedCustomViewStyle())
            .setCustomContentView(rv)
            .setCustomBigContentView(rv)
            .setProgress(100, (p * 100).toInt(), false)
    }

    // ----------------------------------------------------------------- minimal
    fun postMinimal(args: Map<String, Any?>) {
        val id = args["id"] as String
        val compact = args["compact"] as? Map<String, Any?>
        val title = (compact?.get("title") as? Map<String, Any?>)
        val body = (compact?.get("body") as? Map<String, Any?>)
        val layout = compact?.get("layout") as? String ?: "iconAndText"
        val shortTitle = title?.get("short") as? String ?: title?.get("text") as? String ?: ""

        val b = Notification.Builder(ctx, ChannelManager.MINIMAL)
            .setSmallIcon(R.drawable.dnk_ic_notification)
            .setContentTitle(title?.get("text") as? String ?: shortTitle)
            .setContentText(body?.get("text") as? String)
            .setCategory(Notification.CATEGORY_STATUS)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(contentIntent())
        val icon = compact?.get("icon") as? Map<String, Any?>
        (icon?.get("emoji") as? String)?.takeIf { it.isNotEmpty() }?.let {
            b.setLargeIcon(Icon.createWithBitmap(TrackRenderer.vehicleIcon(it)))
        }
        var chipText: String? = null
        when (layout) {
            "iconAndTimer" -> (compact?.get("countdownToMs") as? Number)?.toLong()?.let {
                b.setWhen(it).setUsesChronometer(true).setChronometerCountDown(true)
                chipText = Formatting.shortCritical(it, System.currentTimeMillis())
            }
            "iconAndProgress" -> ((compact?.get("progress") as? Map<String, Any?>)?.get("to") as? Number)?.let {
                b.setProgress(100, (it.toFloat() * 100).toInt(), false)
            }
        }
        // Status-bar chip text is only a Live Update feature, never claimed otherwise.
        if (canPromote()) {
            requestPromoted(b)
            (chipText ?: shortTitle.take(7)).takeIf { it.isNotEmpty() }?.let { b.setShortCriticalText(it) }
        }
        // Always show the countdown/progress bar in the shade even without a Live Update.
        nm.notify(notifId(id), b.build())
    }

    fun postStandard(args: Map<String, Any?>) {
        val id = args["id"] as String
        val n = Notification.Builder(ctx, ChannelManager.STANDARD)
            .setSmallIcon(R.drawable.dnk_ic_notification)
            .setContentTitle(args["title"] as? String)
            .setContentText(args["body"] as? String)
            .setAutoCancel(true)
            .setContentIntent(contentIntent())
            .build()
        nm.notify(notifId(id), n)
    }

    fun cancel(id: String) = nm.cancel(notifId(id))
}
