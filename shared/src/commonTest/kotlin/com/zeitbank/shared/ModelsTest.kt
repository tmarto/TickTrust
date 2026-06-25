package com.zeitbank.shared

import com.zeitbank.shared.models.AppLimit
import com.zeitbank.shared.models.Child
import com.zeitbank.shared.models.Device
import com.zeitbank.shared.models.TimeAccount
import com.zeitbank.shared.models.TimeEntry
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ModelsTest {
    @Test
    fun `time entry duration uses end minus start in minutes`() {
        val entry = TimeEntry("e1", "c1", "com.game", startEpochSeconds = 1_000, endEpochSeconds = 1_000 + 630)
        assertEquals(10, entry.durationMinutes) // 630s -> 10 min (truncated)
    }

    @Test
    fun `open time entry has zero duration`() {
        val entry = TimeEntry("e1", "c1", "com.game", startEpochSeconds = 1_000, endEpochSeconds = null)
        assertEquals(0, entry.durationMinutes)
    }

    @Test
    fun `time account available minutes and overdrawn`() {
        val over = TimeAccount("c1", "2026-01-01", allocatedMinutes = 60, usedMinutes = 70)
        assertEquals(0, over.availableMinutes)
        assertTrue(over.isOverdrawn)

        val under = TimeAccount("c1", "2026-01-01", allocatedMinutes = 60, usedMinutes = 30)
        assertEquals(30, under.availableMinutes)
        assertFalse(under.isOverdrawn)
    }

    @Test
    fun `time account factors in bonus and debt`() {
        val acc = TimeAccount("c1", "2026-01-01", allocatedMinutes = 60, usedMinutes = 50, debtMinutes = 20, bonusMinutes = 30)
        // 60 + 30 - 20 - 50 = 20
        assertEquals(20, acc.availableMinutes)
    }

    @Test
    fun `child composes devices and app limits`() {
        val limit = AppLimit("l1", "com.game.minecraft", "Minecraft", dailyMinutes = 60)
        val device = Device("d1", "iPhone", "c1", appLimits = listOf(limit))
        val child = Child("c1", "Ana", devices = listOf(device))

        assertEquals("Ana", child.name)
        assertEquals(1, child.devices.size)
        assertEquals("d1", child.devices.first().id)
        assertEquals("c1", child.devices.first().childId)
        assertEquals("com.game.minecraft", child.devices.first().appLimits.first().appPackage)
        assertTrue(limit.enabled)
    }
}
