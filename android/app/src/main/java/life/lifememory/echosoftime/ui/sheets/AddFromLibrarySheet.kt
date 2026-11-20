package life.lifememory.echosoftime.ui.sheets

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import kotlinx.coroutines.launch
import life.lifememory.echosoftime.R
import life.lifememory.echosoftime.data.EchoRepository
import life.lifememory.echosoftime.data.MediaStore
import life.lifememory.echosoftime.data.NodeEntity
import life.lifememory.echosoftime.data.PhotoEntity
import life.lifememory.echosoftime.data.PersonEntity
import life.lifememory.echosoftime.data.belongsTo
import life.lifememory.echosoftime.data.taggedNodeIds
import life.lifememory.echosoftime.data.withTaggedNodes
import life.lifememory.echosoftime.ui.components.stringRes

/** 从全部照片里勾选挂到本章节（对应 iOS AddFromLibrarySheet） */
@Composable
fun AddFromLibrarySheet(
    person: PersonEntity,
    node: NodeEntity,
    allPhotos: List<PhotoEntity>,
    nodes: List<NodeEntity>,
    repo: EchoRepository,
    onDismiss: () -> Unit,
) {
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    val context = LocalContext.current
    val sorted = remember(allPhotos) { allPhotos.sortedWith(compareBy({ it.sortOrder }, { it.createdAt })) }
    var chosen by remember { mutableStateOf(sorted.filter { it.belongsTo(node) }.map { it.id }.toSet()) }
    var onlyUnassigned by remember { mutableStateOf(false) }

    val shown = if (onlyUnassigned) sorted.filter { it.taggedNodeIds().isEmpty() } else sorted

    androidx.compose.ui.window.Dialog(
        onDismissRequest = onDismiss,
        properties = androidx.compose.ui.window.DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Column(
            Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background)
                .padding(20.dp),
        ) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = onDismiss) { Text(stringRes(R.string.common_cancel)) }
                Spacer(Modifier.weight(1f))
                Text(stringRes(R.string.photo_library_add_title), fontWeight = FontWeight.Bold, fontSize = 18.sp)
                Spacer(Modifier.weight(1f))
                TextButton(onClick = {
                    scope.launch {
                        for (photo in sorted) {
                            val tagged = nodes.filter {
                                val ids = photo.taggedNodeIds().toMutableSet()
                                if (chosen.contains(photo.id)) ids.add(node.id) else ids.remove(node.id)
                                it.id in ids
                            }
                            repo.updatePhoto(photo.withTaggedNodes(tagged))
                        }
                        onDismiss()
                    }
                }) {
                    Text(stringRes(R.string.common_done), fontWeight = FontWeight.SemiBold)
                }
            }

            Row(
                Modifier.fillMaxWidth().padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(stringRes(R.string.photo_library_only_unassigned), fontSize = 14.sp, modifier = Modifier.weight(1f))
                Switch(checked = onlyUnassigned, onCheckedChange = { onlyUnassigned = it })
            }

            LazyVerticalGrid(
                columns = GridCells.Fixed(4),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
                modifier = Modifier.fillMaxSize(),
            ) {
                items(shown, key = { it.id }) { photo ->
                    val selected = chosen.contains(photo.id)
                    Box(
                        Modifier
                            .aspectRatio(1f)
                            .clip(RoundedCornerShape(4.dp))
                            .border(
                                width = if (selected) 3.dp else 0.dp,
                                color = if (selected) MaterialTheme.colorScheme.primary else androidx.compose.ui.graphics.Color.Transparent,
                                shape = RoundedCornerShape(4.dp),
                            )
                            .background(MaterialTheme.colorScheme.primary.copy(alpha = if (selected) 0.2f else 0.12f))
                            .clickable {
                                chosen = if (selected) chosen - photo.id else chosen + photo.id
                            },
                    ) {
                        AsyncImage(
                            model = ImageRequest.Builder(context)
                                .data(MediaStore.url(context, photo.imageFileName, person.id))
                                .build(),
                            contentDescription = null,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier.fillMaxSize(),
                        )
                        if (selected) {
                            Icon(
                                Icons.Filled.CheckCircle,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.align(Alignment.TopEnd).padding(3.dp).size(16.dp),
                            )
                        }
                    }
                }
            }
        }
    }
}
