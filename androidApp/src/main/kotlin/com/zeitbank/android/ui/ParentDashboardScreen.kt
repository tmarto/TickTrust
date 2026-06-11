package com.zeitbank.android.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.zeitbank.shared.models.Child

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ParentDashboardScreen(
    children: List<Child>,
    onChildSelected: (Child) -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(title = { Text("ZeitBank") })
        }
    ) { padding ->
        if (children.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentAlignment = Alignment.Center,
            ) {
                Text("No children added yet.", style = MaterialTheme.typography.bodyLarge)
            }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(children) { child ->
                    ChildCard(child = child, onClick = { onChildSelected(child) })
                }
            }
        }
    }
}

@Composable
private fun ChildCard(child: Child, onClick: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(child.name, style = MaterialTheme.typography.titleMedium)
                Text(
                    "${child.devices.size} device(s)",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}
