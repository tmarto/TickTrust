package com.zeitbank.shared

import com.zeitbank.shared.models.TimeAccount
import com.zeitbank.shared.services.TimeBankService
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import kotlin.test.assertFailsWith

class TimeBankServiceTest {

    private val service = TimeBankService()
    private val baseAccount = TimeAccount(
        childId = "child1",
        date = "2026-06-11",
        allocatedMinutes = 60,
    )

    @Test
    fun `availableMinutes equals allocated when nothing used`() {
        assertEquals(60, baseAccount.availableMinutes)
    }

    @Test
    fun `availableMinutes decreases with usage`() {
        val account = baseAccount.copy(usedMinutes = 20)
        assertEquals(40, account.availableMinutes)
    }

    @Test
    fun `availableMinutes never goes below zero`() {
        val account = baseAccount.copy(usedMinutes = 100)
        assertEquals(0, account.availableMinutes)
    }

    @Test
    fun `isOverdrawn true when used exceeds allocated`() {
        val account = baseAccount.copy(usedMinutes = 70)
        assertTrue(account.isOverdrawn)
    }

    @Test
    fun `isOverdrawn false when within limit`() {
        val account = baseAccount.copy(usedMinutes = 60)
        assertFalse(account.isOverdrawn)
    }

    @Test
    fun `grantBonus increases bonus minutes`() {
        val result = service.grantBonus(baseAccount, 15)
        assertEquals(15, result.bonusMinutes)
        assertEquals(75, result.availableMinutes)
    }

    @Test
    fun `grantBonus throws on non-positive minutes`() {
        assertFailsWith<IllegalArgumentException> {
            service.grantBonus(baseAccount, 0)
        }
    }

    @Test
    fun `recordUsage adds to used minutes`() {
        val result = service.recordUsage(baseAccount, 30)
        assertEquals(30, result.usedMinutes)
    }

    @Test
    fun `recordUsage throws on negative minutes`() {
        assertFailsWith<IllegalArgumentException> {
            service.recordUsage(baseAccount, -5)
        }
    }

    @Test
    fun `applyDebt does nothing when not overdrawn`() {
        val result = service.applyDebt(baseAccount)
        assertEquals(baseAccount, result)
    }

    @Test
    fun `applyDebt adds overage as debt`() {
        val overdrawn = baseAccount.copy(usedMinutes = 80)
        val result = service.applyDebt(overdrawn)
        assertEquals(20, result.debtMinutes)
    }

    @Test
    fun `rolloverDebt carries yesterday overage to today`() {
        val yesterday = baseAccount.copy(date = "2026-06-10", usedMinutes = 80)
        val today = baseAccount.copy(date = "2026-06-11")
        val result = service.rolloverDebt(today, yesterday)
        assertEquals(20, result.debtMinutes)
    }

    @Test
    fun `rolloverDebt no debt when yesterday was within limit`() {
        val yesterday = baseAccount.copy(date = "2026-06-10", usedMinutes = 50)
        val today = baseAccount.copy(date = "2026-06-11")
        val result = service.rolloverDebt(today, yesterday)
        assertEquals(0, result.debtMinutes)
    }

    @Test
    fun `debt reduces available minutes`() {
        val account = baseAccount.copy(debtMinutes = 20)
        assertEquals(40, account.availableMinutes)
    }

    @Test
    fun `bonus and debt cancel out`() {
        val account = baseAccount.copy(bonusMinutes = 10, debtMinutes = 10)
        assertEquals(60, account.availableMinutes)
    }
}
