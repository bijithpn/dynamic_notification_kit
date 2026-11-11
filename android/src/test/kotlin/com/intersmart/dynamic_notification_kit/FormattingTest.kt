package com.intersmart.dynamic_notification_kit

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class FormattingTest {
    @Test fun renderPathBySdk() {
        assertEquals(RenderPath.PROGRESS_STYLE, RenderPath.select(36))
        assertEquals(RenderPath.PROGRESS_STYLE, RenderPath.select(40))
        assertEquals(RenderPath.RICH_ONGOING, RenderPath.select(35))
        assertEquals(RenderPath.RICH_ONGOING, RenderPath.select(24))
    }
    @Test fun distanceUnits() {
        assertEquals("500 m", Formatting.distance(500.0, "km"))
        assertEquals("1.5 km", Formatting.distance(1500.0, "km"))
        assertEquals("1.0 mi", Formatting.distance(1609.344, "miles"))
        assertNull(Formatting.distance(null, "km"))
    }
    @Test fun etaChip() {
        assertEquals("5 min", Formatting.shortCritical(5 * 60_000L, 0))
        assertEquals("Now", Formatting.shortCritical(0, 1000))
        assertNull(Formatting.shortCritical(null, 0))
    }
    @Test fun status() {
        assertEquals("Delivered", Formatting.statusText("delivered"))
        assertEquals("🚲", Formatting.vehicleEmoji("bike"))
    }
}
