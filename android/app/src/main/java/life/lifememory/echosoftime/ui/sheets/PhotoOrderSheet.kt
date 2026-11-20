package life.lifememory.echosoftime.ui.sheets

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
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
import life.lifememory.echosoftime.data.ArchiveText
import life.lifememory.echosoftime.data.EchoRepository
import life.lifememory.echosoftime.data.MediaStore
import life.lifememory.echosoftime.data.PhotoEntity
import life.lifememory.echosoftime.ui.components.stringRes

/** 章节内照片排序：上移 / 下移（对应 iOS PhotoOrderSheet 的 onMove） */
@Composable
fun PhotoOrderSheet(
    photos: List<PhotoEntity>,
    personId: String,
    repo: EchoRepository,
    onDismiss: () -> Unit,
) {
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    val context = LocalContext.current
    var ordered by remember { mutableStateOf(photos) }

    fun move(index: Int, delta: Int) {
        val target = index + delta
        if (target < 0 || target >= ordered.size) return
        val list = ordered.toMutableList()
        val item = list.removeAt(index)
        list.add(target, item)
        ordered = list
    }

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
                Spacer(Modifier.weight(1f))
                Text(stringRes(R.string.photo_order_title), fontWeight = FontWeight.Bold, fontSize = 18.sp)
                Spacer(Modifier.weight(1f))
                TextButton(onClick = {
                    scope.launch {
                        ordered.forEachIndexed { i, p -> repo.updatePhoto(p.copy(sortOrder = i)) }
                        onDismiss()
                    }
                }) {
                    Text(stringRes(R.string.common_done), fontWeight = FontWeight.SemiBold)
                }
            }
            Spacer(Modifier.height(12.dp))
            Column(
                Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                ordered.forEachIndexed { i, photo ->
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(10.dp))
                            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f))
                            .padding(8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        AsyncImage(
                            model = ImageRequest.Builder(context)
                                .data(MediaStore.url(context, photo.imageFileName, personId))
                                .build(),
                            contentDescription = null,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .size(44.dp)
                                .clip(RoundedCornerShape(6.dp)),
                        )
                        Spacer(Modifier.width(12.dp))
                        Text(
                            if (photo.caption.isEmpty()) stringRes(R.string.photo_untitled)
                            else ArchiveText.inline(photo.caption),
                            fontSize = 14.sp,
                            maxLines = 2,
                            modifier = Modifier.weight(1f),
                        )
                        IconButton(onClick = { move(i, -1) }, enabled = i > 0) {
                            Icon(Icons.Filled.KeyboardArrowUp, contentDescription = null)
                        }
                        IconButton(onClick = { move(i, 1) }, enabled = i < ordered.size - 1) {
                            Icon(Icons.Filled.KeyboardArrowDown, contentDescription = null)
                        }
                    }
                }
            }
        }
    }
}
