package com.zeitbank.shared.services

import com.zeitbank.shared.models.AppLimit
import com.zeitbank.shared.models.TimeAccount

data class KillWarning(val appPackage: String, val secondsRemaining: Int)

class ScheduleEngine {

    fun shouldKill(
        appPackage: String,
        account: TimeAccount,
        limits: List<AppLimit>,
    ): Boolean {
        val limit = limits.firstOrNull { it.appPackage == appPackage && it.enabled } ?: return false
        val effectiveLimit = (limit.dailyMinutes + account.bonusMinutes - account.debtMinutes).coerceAtLeast(0)
        return account.usedMinutes >= effectiveLimit
    }

    fun pendingWarnings(
        appPackage: String,
        account: TimeAccount,
        limits: List<AppLimit>,
        warningThresholdsSeconds: List<Int> = listOf(120, 60, 10),
    ): List<KillWarning> {
        val limit = limits.firstOrNull { it.appPackage == appPackage && it.enabled } ?: return emptyList()
        val effectiveLimitMinutes = (limit.dailyMinutes + account.bonusMinutes - account.debtMinutes).coerceAtLeast(0)
        val remainingSeconds = ((effectiveLimitMinutes - account.usedMinutes) * 60).coerceAtLeast(0)
        return warningThresholdsSeconds
            .filter { it >= remainingSeconds }
            .map { KillWarning(appPackage, it) }
    }
}
