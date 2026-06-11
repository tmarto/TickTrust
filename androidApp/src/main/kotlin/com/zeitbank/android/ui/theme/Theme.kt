package com.zeitbank.android.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val PrimaryBlue = Color(0xFF1565C0)
private val SecondaryOrange = Color(0xFFE65100)

private val LightColors = lightColorScheme(
    primary = PrimaryBlue,
    secondary = SecondaryOrange,
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFF90CAF9),
    secondary = Color(0xFFFFCC02),
)

@Composable
fun ZeitBankTheme(
    darkTheme: Boolean = false,
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        content = content,
    )
}
