package com.zeitbank.android.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.zeitbank.shared.models.AppLimit
import com.zeitbank.shared.models.Child

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChildDetailScreen(
    child: Child,
    onBack: () -> Unit,
    onToggleLimit: (AppLimit, Boolean) -> Unit,
    onGrantBonus: (Int) -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(child.name) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            item {
                Text("Devices & App Limits", style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.height(8.dp))
            }
            child.devices.forEach { device ->
                item {
                    Text(device.name, style = MaterialTheme.typography.labelLarge)
                }
                items(device.appLimits) { limit ->
                    AppLimitRow(limit = limit, onToggle = { enabled -> onToggleLimit(limit, enabled) })
                }
            }
            item {
                Spacer(Modifier.height(16.dp))
                OutlinedButton(
                    onClick = { onGrantBonus(15) },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("Grant +15 min bonus")
                }
            }
        }
    }
}

@Composable
private fun AppLimitRow(
    limit: AppLimit,
    onToggle: (Boolean) -> Unit,
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(limit.appName, style = MaterialTheme.typography.bodyMedium)
                Text("${limit.dailyMinutes} min/day", style = MaterialTheme.typography.bodySmall)
            }
            Switch(checked = limit.enabled, onCheckedChange = onToggle)
        }
    }
}
