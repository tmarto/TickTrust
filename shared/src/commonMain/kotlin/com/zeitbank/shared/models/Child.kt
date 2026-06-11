package com.zeitbank.shared.models

data class Child(
    val id: String,
    val name: String,
    val devices: List<Device> = emptyList(),
)
