package com.zeitbank.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.zeitbank.android.ui.ParentDashboardScreen
import com.zeitbank.android.ui.theme.ZeitBankTheme
import com.zeitbank.shared.models.AppLimit
import com.zeitbank.shared.models.Child
import com.zeitbank.shared.models.Device

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val sampleChildren = listOf(
            Child(
                id = "c1",
                name = "Ines",
                devices = listOf(
                    Device(
                        id = "d1",
                        name = "Ines iPhone",
                        childId = "c1",
                        appLimits = listOf(
                            AppLimit("a1", "com.mojang.minecraftpe", "Minecraft", 60),
                            AppLimit("a2", "com.roblox.client", "Roblox", 45),
                        ),
                    )
                ),
            ),
            Child(
                id = "c2",
                name = "Pedro",
                devices = listOf(
                    Device(
                        id = "d2",
                        name = "Pedro iPad",
                        childId = "c2",
                        appLimits = listOf(
                            AppLimit("a3", "com.mojang.minecraftpe", "Minecraft", 90),
                        ),
                    )
                ),
            ),
        )

        setContent {
            ZeitBankTheme {
                ParentDashboardScreen(
                    children = sampleChildren,
                    onChildSelected = {},
                )
            }
        }
    }
}
