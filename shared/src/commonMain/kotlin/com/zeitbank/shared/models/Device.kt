package com.zeitbank.shared.models

data class Device(
    val id: String,
    val name: String,
    val childId: String,
    val appLimits: List<AppLimit> = emptyList(),
)
