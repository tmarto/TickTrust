package com.zeitbank.shared

import com.zeitbank.shared.models.AppLimit
import com.zeitbank.shared.models.TimeAccount
import com.zeitbank.shared.services.ScheduleEngine
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ScheduleEngineTest {
    private val engine = ScheduleEngine()
    private val limits =
        listOf(
            AppLimit(id = "l1", appPackage = "com.game.minecraft", appName = "Minecraft", dailyMinutes = 60),
            AppLimit(id = "l2", appPackage = "com.game.roblox", appName = "Roblox", dailyMinutes = 30, enabled = false),
        )
    private val baseAccount =
        TimeAccount(
            childId = "child1",
            date = "2026-06-11",
            allocatedMinutes = 120,
            usedMinutes = 0,
        )

    @Test
    fun `shouldKill false when under limit`() {
        val account = baseAccount.copy(usedMinutes = 30)
        assertFalse(engine.shouldKill("com.game.minecraft", account, limits))
    }

    @Test
    fun `shouldKill true when at limit`() {
        val account = baseAccount.copy(usedMinutes = 60)
        assertTrue(engine.shouldKill("com.game.minecraft", account, limits))
    }

    @Test
    fun `shouldKill true when over limit`() {
        val account = baseAccount.copy(usedMinutes = 90)
        assertTrue(engine.shouldKill("com.game.minecraft", account, limits))
    }

    @Test
    fun `shouldKill false for disabled limit`() {
        val account = baseAccount.copy(usedMinutes = 60)
        assertFalse(engine.shouldKill("com.game.roblox", account, limits))
    }

    @Test
    fun `shouldKill false for unknown app`() {
        val account = baseAccount.copy(usedMinutes = 999)
        assertFalse(engine.shouldKill("com.game.unknown", account, limits))
    }

    @Test
    fun `shouldKill respects debt reduction`() {
        val account = baseAccount.copy(usedMinutes = 50, debtMinutes = 15)
        assertTrue(engine.shouldKill("com.game.minecraft", account, limits))
    }

    @Test
    fun `shouldKill respects bonus extension`() {
        val account = baseAccount.copy(usedMinutes = 60, bonusMinutes = 15)
        assertFalse(engine.shouldKill("com.game.minecraft", account, limits))
    }

    @Test
    fun `pendingWarnings empty when time remaining exceeds all thresholds`() {
        val account = baseAccount.copy(usedMinutes = 0)
        val warnings = engine.pendingWarnings("com.game.minecraft", account, limits)
        assertTrue(warnings.isEmpty())
    }

    @Test
    fun `pendingWarnings returns warning at 10s threshold`() {
        val account = baseAccount.copy(usedMinutes = 59)
        val warnings = engine.pendingWarnings("com.game.minecraft", account, limits)
        assertEquals(1, warnings.size)
        assertEquals(10, warnings[0].secondsRemaining)
    }

    @Test
    fun `pendingWarnings returns multiple warnings near limit`() {
        val account = baseAccount.copy(usedMinutes = 58)
        val warnings = engine.pendingWarnings("com.game.minecraft", account, limits)
        assertEquals(2, warnings.size)
    }

    @Test
    fun `pendingWarnings empty for unknown app`() {
        val account = baseAccount.copy(usedMinutes = 59)
        val warnings = engine.pendingWarnings("com.game.unknown", account, limits)
        assertTrue(warnings.isEmpty())
    }
}
