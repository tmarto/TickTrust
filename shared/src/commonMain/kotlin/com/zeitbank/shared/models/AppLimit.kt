package com.zeitbank.shared.models

data class AppLimit(
    val id: String,
    val appPackage: String,
    val appName: String,
    val dailyMinutes: Int,
    val enabled: Boolean = true,
)
