package com.zeitbank.shared.models

data class TimeAccount(
    val childId: String,
    val date: String,
    val allocatedMinutes: Int,
    val usedMinutes: Int = 0,
    val debtMinutes: Int = 0,
    val bonusMinutes: Int = 0,
) {
    val availableMinutes: Int
        get() = (allocatedMinutes + bonusMinutes - debtMinutes - usedMinutes).coerceAtLeast(0)

    val isOverdrawn: Boolean
        get() = usedMinutes > (allocatedMinutes + bonusMinutes - debtMinutes)
}
