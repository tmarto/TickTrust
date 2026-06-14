package com.zeitbank.shared.services

import com.zeitbank.shared.models.TimeAccount

class TimeBankService {
    fun applyDebt(account: TimeAccount): TimeAccount {
        if (!account.isOverdrawn) return account
        val overage =
            (account.usedMinutes - account.allocatedMinutes - account.bonusMinutes + account.debtMinutes)
                .coerceAtLeast(0)
        return account.copy(debtMinutes = account.debtMinutes + overage)
    }

    fun grantBonus(
        account: TimeAccount,
        minutes: Int,
    ): TimeAccount {
        require(minutes > 0) { "Bonus minutes must be positive" }
        return account.copy(bonusMinutes = account.bonusMinutes + minutes)
    }

    fun recordUsage(
        account: TimeAccount,
        minutes: Int,
    ): TimeAccount {
        require(minutes >= 0) { "Usage minutes must be non-negative" }
        return account.copy(usedMinutes = account.usedMinutes + minutes)
    }

    fun rolloverDebt(
        today: TimeAccount,
        yesterday: TimeAccount,
    ): TimeAccount {
        val overage =
            (yesterday.usedMinutes - yesterday.allocatedMinutes - yesterday.bonusMinutes + yesterday.debtMinutes)
                .coerceAtLeast(0)
        return if (overage > 0) today.copy(debtMinutes = today.debtMinutes + overage) else today
    }
}
