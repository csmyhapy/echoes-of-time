package life.lifememory.echosoftime.ui.screens

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import coil.request.ImageRequest
import kotlinx.coroutines.launch
import life.lifememory.echosoftime.R
import life.lifememory.echosoftime.billing.PurchaseManager
import life.lifememory.echosoftime.data.EchoRepository
import life.lifememory.echosoftime.data.MediaStore
import life.lifememory.echosoftime.data.NodeEntity
import life.lifememory.echosoftime.data.PhotoEntity
import life.lifememory.echosoftime.data.belongsTo
import life.lifememory.echosoftime.data.taggedNodeIds
import life.lifememory.echosoftime.data.withTaggedNodes
import life.lifememory.echosoftime.ui.components.stringRes

/**
 * 照片库：全部照片网格 + 章节筛选 + 多选批量分配/移出/删除（对齐 iOS PhotoLibraryView）
 */
@Composable
fun PhotoLibraryScreen(
    personId: String,
    isReader: Boolean,
    repo: EchoRepository,
    purchase: PurchaseManager,
    onShowPaywall: () -> Unit,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val bundle by repo.observePerson(personId).collectAsStateWithLifecycle(null)
    val b = bundle ?: return
    var filterNodeId by remember { mutableStateOf<String?>(null) }
    var unassignedOnly by remember { mutableStateOf(false) }

    val all = b.photos.sortedWith(compareBy({ it.sortOrder }, { it.createdAt }))
    val displayed = when {
        unassignedOnly -> all.filter { it.taggedNodeIds().isEmpty() }
        filterNodeId != null -> all.filter { p -> b.nodes.firstOrNull { n -> n.id == filterNodeId }?.let { p.belongsTo(it) } == true }
        else -> all
    }
    var lightboxIndex by remember { mutableStateOf<Int?>(null) }

    // 多选状态
    var selecting by remember { mutableStateOf(false) }
    var selected by remember { mutableStateOf<Set<String>>(emptySet()) }
    var showNodePicker by remember { mutableStateOf(false) }
    var showDeleteConfirm by remember { mutableStateOf(false) }

    val selectedPhotos = all.filter { selected.contains(it.id) }

    fun applyAssign(nodeIds: Set<String>) {
        val chosen = b.nodes.filter { nodeIds.contains(it.id) }
        scope.launch {
            for (photo in selectedPhotos) {
                repo.updatePhoto(photo.withTaggedNodes(chosen))
            }
            selected = emptySet(); selecting = false
        }
    }

    fun unassignSelected() {
        scope.launch {
            for (photo in selectedPhotos) {
                repo.updatePhoto(photo.withTaggedNodes(emptyList()))
            }
            selected = emptySet(); selecting = false
        }
    }

    fun deleteSelected() {
        scope.launch {
            for (photo in selectedPhotos) repo.deletePhoto(photo)
            selected = emptySet(); selecting = false
        }
    }

    androidx.compose.foundation.layout.Column(Modifier.fillMaxSize()) {
        Row(
            Modifier.fillMaxWidth().padding(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onBack) { Icon(Icons.Filled.ArrowBack, contentDescription = null) }
            Text(stringRes(R.string.library_photos_title), fontWeight = FontWeight.Bold, fontSize = 18.sp, modifier = Modifier.weight(1f))
            if (!isReader && all.isNotEmpty()) {
                TextButton(onClick = {
                    selecting = !selecting
                    if (!selecting) selected = emptySet()
                }) {
                    Text(stringRes(if (selecting) R.string.common_done else R.string.library_photos_select))
                }
            }
        }

        // 筛选条（横向）
        Row(
            Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
                FilterChip(stringRes(R.string.library_photos_all), all.size, !unassignedOnly && filterNodeId == null) {
                    unassignedOnly = false; filterNodeId = null
                }
                val unassigned = all.filter { it.taggedNodeIds().isEmpty() }
                if (unassigned.isNotEmpty()) {
                    FilterChip(stringRes(R.string.library_photos_unassigned), unassigned.size, unassignedOnly) {
                        unassignedOnly = true; filterNodeId = null
                    }
                }
                b.sortedNodes.forEach { node ->
                    FilterChip(node.name, all.count { it.belongsTo(node) }, filterNodeId == node.id && !unassignedOnly) {
                        unassignedOnly = false
                        filterNodeId = if (filterNodeId == node.id) null else node.id
                    }
                }
        }

        if (displayed.isEmpty()) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text(stringRes(R.string.library_photos_empty), color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        } else {
            LazyVerticalGrid(
                columns = GridCells.Fixed(3),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp, 16.dp, 16.dp, 96.dp),
                modifier = Modifier.fillMaxSize(),
            ) {
                items(displayed, key = { it.id }) { photo ->
                    val idx = displayed.indexOf(photo)
                    PhotoCell(
                        photo = photo,
                        personId = personId,
                        selected = selected.contains(photo.id),
                        selecting = selecting,
                        onClick = {
                            if (selecting) {
                                selected = if (selected.contains(photo.id)) selected - photo.id else selected + photo.id
                            } else {
                                lightboxIndex = idx
                            }
                        },
                        onLongPress = {
                            if (!selecting) {
                                selecting = true
                                selected = setOf(photo.id)
                            }
                        },
                    )
                }
            }
        }
    }

    // 底部批量操作条
    if (selecting && selected.isNotEmpty()) {
        Row(
            Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Button(onClick = { showNodePicker = true }) {
                Text(stringRes(R.string.library_photos_assign), fontSize = 13.sp)
            }
            TextButton(onClick = { unassignSelected() }) {
                Text(stringRes(R.string.library_photos_unassign), fontSize = 13.sp)
            }
            Spacer(Modifier.weight(1f))
            TextButton(
                onClick = { showDeleteConfirm = true },
                colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error),
            ) {
                Text(stringRes(R.string.common_delete), fontSize = 13.sp)
            }
            Text("${selected.size}", fontWeight = FontWeight.SemiBold)
        }
    }

    lightboxIndex?.let { idx ->
        PhotoLightboxScreen(
            bundle = b,
            photos = displayed,
            startIndex = idx,
            isReader = isReader,
            repo = repo,
            purchase = purchase,
            onShowPaywall = onShowPaywall,
            onBack = { lightboxIndex = null },
        )
    }

    if (showNodePicker) {
        val common = selectedPhotos
            .map { it.taggedNodeIds().toSet() }
            .reduce { acc, s -> acc intersect s }
        NodePickerDialog(
            nodes = b.sortedNodes,
            preselected = common,
            onDismiss = { showNodePicker = false },
            onConfirm = { chosen ->
                showNodePicker = false
                applyAssign(chosen)
            },
        )
    }

    if (showDeleteConfirm) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm = false },
            title = { Text(stringRes(R.string.library_photos_delete_confirm)) },
            confirmButton = {
                TextButton(onClick = { showDeleteConfirm = false; deleteSelected() }) {
                    Text(stringRes(R.string.common_delete), color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirm = false }) { Text(stringRes(R.string.common_cancel)) }
            },
            text = { Text(stringRes(R.string.library_photos_delete_confirm) + " (${selected.size})") },
        )
    }
}

@Composable
private fun NodePickerDialog(
    nodes: List<NodeEntity>,
    preselected: Set<String>,
    onDismiss: () -> Unit,
    onConfirm: (Set<String>) -> Unit,
) {
    var chosen by remember { mutableStateOf(preselected) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringRes(R.string.library_photos_assign_title)) },
        text = {
            androidx.compose.foundation.layout.Column {
                Text(stringRes(R.string.library_photos_assign_footer), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.height(8.dp))
                nodes.forEach { node ->
                    val checked = chosen.contains(node.id)
                    Row(
                        Modifier.fillMaxWidth().clickable {
                            chosen = if (checked) chosen - node.id else chosen + node.id
                        }.padding(vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        androidx.compose.foundation.layout.Box(
                            Modifier
                                .width(24.dp).height(24.dp)
                                .clip(RoundedCornerShape(6.dp))
                                .background(if (checked) MaterialTheme.colorScheme.primary else Color.Transparent)
                                .padding(4.dp),
                        ) {
                            if (checked) Icon(Icons.Outlined.Check, null, tint = Color.White)
                        }
                        Spacer(Modifier.width(12.dp))
                        Text(node.name)
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = { onConfirm(chosen) }) { Text(stringRes(R.string.common_save)) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringRes(R.string.common_cancel)) } },
    )
}

@Composable
private fun FilterChip(label: String, count: Int, selected: Boolean, onClick: () -> Unit) {
    Row(
        Modifier
            .clickable(onClick = onClick)
            .clip(RoundedCornerShape(16.dp))
            .background(if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.primary.copy(alpha = 0.12f))
            .padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(
            label,
            fontSize = 13.sp,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
            color = if (selected) Color.White else MaterialTheme.colorScheme.primary,
        )
        Text(
            "$count",
            fontSize = 12.sp,
            color = if (selected) Color.White.copy(alpha = 0.85f) else MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun PhotoCell(
    photo: PhotoEntity,
    personId: String,
    selected: Boolean,
    selecting: Boolean,
    onClick: () -> Unit,
    onLongPress: () -> Unit,
) {
    val context = LocalContext.current
    Box(
        Modifier
            .aspectRatio(1f)
            .clip(RoundedCornerShape(8.dp))
            .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.12f))
            .combinedClickable(
                onClick = onClick,
                onLongClick = if (selecting) null else onLongPress,
            ),
    ) {
        AsyncImage(
            model = ImageRequest.Builder(context)
                .data(MediaStore.url(context, photo.imageFileName, personId))
                .build(),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize(),
        )
        if (selecting) {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(if (selected) MaterialTheme.colorScheme.primary.copy(alpha = 0.18f) else Color.Transparent)
                    .then(
                        Modifier.clip(RoundedCornerShape(8.dp))
                    ),
            )
            if (selected) {
                androidx.compose.foundation.layout.Box(
                    Modifier.align(Alignment.TopEnd).padding(4.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        Icons.Outlined.Check, null, tint = Color.White,
                        modifier = Modifier
                            .width(24.dp).height(24.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(MaterialTheme.colorScheme.primary)
                            .padding(3.dp),
                    )
                }
            }
        }
        // 多章节徽标
        val tags = photo.taggedNodeIds()
        if (!selecting && tags.size > 1) {
            Text(
                "${tags.size}",
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White,
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(4.dp)
                    .background(Color.Black.copy(alpha = 0.55f), RoundedCornerShape(8.dp))
                    .padding(horizontal = 5.dp, vertical = 2.dp),
            )
        }
        if (!selecting && tags.isEmpty()) {
            Text(
                stringRes(R.string.library_photos_tag_unassigned),
                fontSize = 10.sp,
                color = Color.White,
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(4.dp)
                    .background(Color(0xDDFF8A00), RoundedCornerShape(8.dp))
                    .padding(horizontal = 4.dp, vertical = 2.dp),
            )
        }
    }
}
