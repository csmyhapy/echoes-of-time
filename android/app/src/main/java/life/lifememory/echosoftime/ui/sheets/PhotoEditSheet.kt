package life.lifememory.echosoftime.ui.sheets

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import life.lifememory.echosoftime.R
import life.lifememory.echosoftime.data.ArchiveText
import life.lifememory.echosoftime.data.EchoRepository
import life.lifememory.echosoftime.data.NodeEntity
import life.lifememory.echosoftime.data.PhotoEntity
import life.lifememory.echosoftime.data.PersonEntity
import life.lifememory.echosoftime.data.taggedNodeIds
import life.lifememory.echosoftime.data.withTaggedNodes
import life.lifememory.echosoftime.ui.components.stringRes

/** 照片编辑：说明 / 故事 / 配对 / 挂章节（对应 iOS PhotoEditSheet） */
@Composable
fun PhotoEditSheet(
    photo: PhotoEntity,
    person: PersonEntity,
    nodes: List<NodeEntity>,
    repo: EchoRepository,
    onDismiss: () -> Unit,
) {
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    var caption by remember { mutableStateOf(photo.caption) }
    var story by remember { mutableStateOf(photo.story) }
    var pairWithNext by remember { mutableStateOf(photo.pairWithNext) }
    var chosenNodes by remember { mutableStateOf(photo.taggedNodeIds().toSet()) }
    var showPicker by remember { mutableStateOf(false) }

    val chapterSummary = nodes.filter { chosenNodes.contains(it.id) }.map { it.name }
        .joinToString("、")
        .ifEmpty { stringRes(R.string.photo_edit_no_chapter) }

    androidx.compose.ui.window.Dialog(
        onDismissRequest = onDismiss,
        properties = androidx.compose.ui.window.DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Column(
            Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background)
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
        ) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = onDismiss) { Text(stringRes(R.string.common_cancel)) }
                Spacer(Modifier.weight(1f))
                Text(stringRes(R.string.photo_edit_title), fontWeight = FontWeight.Bold, fontSize = 18.sp)
                Spacer(Modifier.weight(1f))
                TextButton(onClick = {
                    scope.launch {
                        val tagged = nodes.filter { chosenNodes.contains(it.id) }
                        repo.updatePhoto(
                            photo.withTaggedNodes(tagged).copy(
                                caption = ArchiveText.inline(caption),
                                story = ArchiveText.clean(story),
                                pairWithNext = pairWithNext,
                            ),
                        )
                        onDismiss()
                    }
                }) {
                    Text(stringRes(R.string.common_save), fontWeight = FontWeight.SemiBold)
                }
            }
            Spacer(Modifier.height(16.dp))

            SectionLabel(stringRes(R.string.photo_edit_caption))
            OutlinedTextField(
                value = caption,
                onValueChange = { caption = it },
                placeholder = { Text(stringRes(R.string.photo_edit_caption_placeholder)) },
                minLines = 2,
                maxLines = 4,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(12.dp))

            SectionLabel(stringRes(R.string.photo_edit_story))
            OutlinedTextField(
                value = story,
                onValueChange = { story = it },
                placeholder = { Text(stringRes(R.string.photo_edit_story_placeholder)) },
                minLines = 4,
                maxLines = 12,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(12.dp))

            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(stringRes(R.string.photo_edit_pairWithNext), fontSize = 15.sp, modifier = Modifier.weight(1f))
                Switch(checked = pairWithNext, onCheckedChange = { pairWithNext = it })
            }
            Text(
                stringRes(R.string.photo_edit_pairWithNext_hint),
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(12.dp))

            SectionLabel(stringRes(R.string.photo_edit_chapters))
            Row(
                Modifier
                    .fillMaxWidth()
                    .clickable { showPicker = true }
                    .padding(vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    chapterSummary,
                    color = if (chosenNodes.isEmpty()) MaterialTheme.colorScheme.onSurfaceVariant
                    else MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.weight(1f),
                )
                Icon(Icons.Filled.ChevronRight, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }

    if (showPicker) {
        NodePickerSheet(
            nodes = nodes,
            preselected = chosenNodes,
            onDismiss = { showPicker = false },
            onConfirm = { chosenNodes = it; showPicker = false },
        )
    }
}
