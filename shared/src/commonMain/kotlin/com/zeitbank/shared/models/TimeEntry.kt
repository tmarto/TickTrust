package com.zeitbank.shared.models

data class TimeEntry(
    val id: String,
    val childId: String,
    val appPackage: String,
    val startEpochSeconds: Long,
    val endEpochSeconds: Long?,
) {
    val durationMinutes: Int
        get() {
            val end = endEpochSeconds ?: return 0
            return ((end - startEpochSeconds) / 60).toInt()
        }
}
