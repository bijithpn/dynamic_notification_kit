package com.intersmart.dynamic_notification_kit

import java.text.DateFormat
import java.util.Date
import java.util.Locale

/** Pure helpers (unit-testable, no Android deps). */
object Formatting {
    fun vehicleEmoji(vehicle: String?): String = when (vehicle) {
        "bike" -> "🚲"
        "scooter" -> "🛵"
        "car" -> "🚗"
        "van" -> "🚐"
        "truck" -> "🚚"
        "walking" -> "🚶"
        else -> "🛵"
    }

    fun statusText(status: String?): String = when (status) {
        "preparing" -> "Preparing your order"
        "pickedUp" -> "Picked up"
        "onTheWay" -> "On the way"
        "approaching" -> "Driver is approaching"
        "arrived" -> "Driver has arrived"
        "delivered" -> "Delivered"
        "cancelled" -> "Cancelled"
        else -> "On the way"
    }

    fun distance(meters: Double?, unit: String?): String? {
        if (meters == null) return null
        return if (unit == "miles") {
            val mi = meters / 1609.344
            if (mi < 0.1) "${(meters * 3.28084).toInt()} ft" else String.format(Locale.US, "%.1f mi", mi)
        } else {
            if (meters < 1000) "${meters.toInt()} m" else String.format(Locale.US, "%.1f km", meters / 1000)
        }
    }

    fun etaMinutes(etaMs: Long?, nowMs: Long): Int? =
        etaMs?.let { maxOf(0L, (it - nowMs + 59_999) / 60_000).toInt() }

    /** Short chip text, e.g. "5 min". */
    fun shortCritical(etaMs: Long?, nowMs: Long): String? =
        etaMinutes(etaMs, nowMs)?.let { if (it <= 0) "Now" else "$it min" }

    fun etaClock(etaMs: Long?): String? =
        etaMs?.let { DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(it)) }
}

/** Which rendering path to use. Separated so it can be unit tested by SDK. */
enum class RenderPath {
    PROGRESS_STYLE, RICH_ONGOING, STANDARD;

    companion object {
        fun select(sdk: Int): RenderPath = when {
            sdk >= 36 -> PROGRESS_STYLE
            else -> RICH_ONGOING
        }
    }
}
