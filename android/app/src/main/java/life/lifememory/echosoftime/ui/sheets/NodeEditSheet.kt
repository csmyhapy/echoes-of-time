package life.lifememory.echosoftime.ui.sheets

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import life.lifememory.echosoftime.R
import life.lifememory.echosoftime.data.EchoRepository
import life.lifememory.echosoftime.data.MediaStore
import life.lifememory.echosoftime.data.NodeEntity
import life.lifememory.echosoftime.data.PersonEntity
import life.lifememory.echosoftime.ui.components.stringRes

/** 新建 / 编辑章节（对应 iOS NodeEditView） */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NodeEditSheet(
    person: PersonEntity,
    node: NodeEntity?,
    repo: EchoRepository,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    val scope = androidx.compose.runtime.rememberCoroutineScope()

    var name by remember { mutableStateOf("") }
    var yearRange by remember { mutableStateOf("") }
    var summary by remember { mutableStateOf("") }
    var story by remember { mutableStateOf("") }
    var isVisible by remember { mutableStateOf(true) }
    var coverBitmap by remember { mutableStateOf<Bitmap?>(null) }
    var suggestOpen by remember { mutableStateOf(false) }

    val suggestionKeys = listOf(
        R.string.suggestion_childhood, R.string.suggestion_adolescence,
        R.string.suggestion_youngAdulthood, R.string.suggestion_middleAdulthood,
        R.string.suggestion_laterYears, R.string.suggestion_marriage,
        R.string.suggestion_career, R.string.suggestion_family,
        R.string.suggestion_hobbies, R.string.suggestion_roots,
        R.string.suggestion_turningPoints,
    )

    LaunchedEffect(node) {
        node?.let {
            name = it.name
            yearRange = it.yearRange
            summary = it.summary
            story = it.story
            isVisible = it.isVisible
            it.coverImageFileName?.let { f -> coverBitmap = MediaStore.loadImage(context, f, person.id) }
        }
    }

    val coverLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia(),
    ) { uri ->
        uri ?: return@rememberLauncherForActivityResult
        runCatching {
            context.contentResolver.openInputStream(uri)?.use { input ->
                coverBitmap = BitmapFactory.decodeStream(input)
            }
        }
    }

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
                Text(
                    stringRes(if (node == null) R.string.edit_node_new_title else R.string.edit_node_edit_title),
                    fontWeight = FontWeight.Bold,
                    fontSize = 18.sp,
                )
                Spacer(Modifier.weight(1f))
                TextButton(
                    onClick = {
                        scope.launch {
                            val oldCover = node?.coverImageFileName
                            val coverName = if (coverBitmap != null) {
                                if (oldCover != null) MediaStore.deleteFile(context, oldCover, person.id)
                                MediaStore.saveImage(context, coverBitmap!!, person.id)
                            } else node?.coverImageFileName

                            if (node == null) {
                                val nextOrder = (repo.nodesOf(person.id).maxOfOrNull { it.sortOrder } ?: -1) + 1
                                repo.insertNode(
                                    personId = person.id,
                                    name = name.trim(),
                                    yearRange = yearRange.trim(),
                                    summary = summary,
                                    story = story,
                                    sortOrder = nextOrder,
                                    coverImageFileName = coverName,
                                    isVisible = isVisible,
                                )
                            } else {
                                repo.updateNode(
                                    node.copy(
                                        name = name.trim(),
                                        yearRange = yearRange.trim(),
                                        summary = summary,
                                        story = story,
                                        isVisible = isVisible,
                                        coverImageFileName = coverName,
                                    ),
                                )
                            }
                            onDismiss()
                        }
                    },
                    enabled = name.trim().isNotEmpty(),
                ) { Text(stringRes(R.string.common_save)) }
            }

            SectionLabel(stringRes(R.string.edit_node_section_basics))

            Box {
                TextButton(onClick = { suggestOpen = true }) {
                    Text(stringRes(R.string.edit_node_suggest), color = MaterialTheme.colorScheme.primary)
                }
                DropdownMenu(expanded = suggestOpen, onDismissRequest = { suggestOpen = false }) {
                    suggestionKeys.forEach { key ->
                        DropdownMenuItem(
                            text = { Text(stringRes(key)) },
                            onClick = {
                                name = context.getString(key)
                                suggestOpen = false
                            },
                        )
                    }
                }
            }

            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text(stringRes(R.string.edit_node_name)) },
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                value = yearRange,
                onValueChange = { yearRange = it },
                label = { Text(stringRes(R.string.edit_node_yearRange)) },
                modifier = Modifier.fillMaxWidth(),
            )
            Row(
                Modifier.fillMaxWidth().padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(stringRes(R.string.edit_node_visible), Modifier.weight(1f))
                Switch(checked = isVisible, onCheckedChange = { isVisible = it })
            }

            SectionLabel(stringRes(R.string.edit_node_section_summary))
            OutlinedTextField(
                value = summary,
                onValueChange = { summary = it },
                label = { Text(stringRes(R.string.edit_node_summary)) },
                minLines = 3,
                modifier = Modifier.fillMaxWidth(),
            )

            SectionLabel(stringRes(R.string.edit_node_section_story))
            OutlinedTextField(
                value = story,
                onValueChange = { story = it },
                label = { Text(stringRes(R.string.edit_node_story)) },
                minLines = 6,
                modifier = Modifier.fillMaxWidth(),
            )

            SectionLabel(stringRes(R.string.edit_node_section_cover))
            coverBitmap?.let { bmp ->
                Image(
                    bmp.asImageBitmap(),
                    contentDescription = null,
                    Modifier.fillMaxWidth().height(150.dp).clip(RoundedCornerShape(12.dp)),
                )
                Spacer(Modifier.height(8.dp))
            }
            Button(onClick = { coverLauncher.launch(androidx.activity.result.PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }) {
                Text(stringRes(R.string.edit_cover_choose))
            }
        }
    }
}
