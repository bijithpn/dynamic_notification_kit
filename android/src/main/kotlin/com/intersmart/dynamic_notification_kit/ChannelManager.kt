package com.intersmart.dynamic_notification_kit

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context

object ChannelManager {
    const val DELIVERY = "dnk_delivery"
    const val MINIMAL = "dnk_minimal"
    const val STANDARD = "dnk_standard"

    fun ensure(ctx: Context) {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        // LOW importance: silent updates, no heads-up on every progress tick.
        nm.createNotificationChannel(NotificationChannel(DELIVERY, "Delivery tracking", NotificationManager.IMPORTANCE_LOW))
        nm.createNotificationChannel(NotificationChannel(MINIMAL, "Ongoing status", NotificationManager.IMPORTANCE_LOW))
        nm.createNotificationChannel(NotificationChannel(STANDARD, "Notifications", NotificationManager.IMPORTANCE_DEFAULT))
    }
}
