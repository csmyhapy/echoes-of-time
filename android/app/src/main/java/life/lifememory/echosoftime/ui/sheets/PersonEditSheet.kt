package life.lifememory.echosoftime.ui.sheets

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
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
import life.lifememory.echosoftime.data.PersonEntity
import life.lifememory.echosoftime.ui.components.stringRes
import java.io.InputStream

/** 新建 / 编辑人物档案（对应 iOS PersonEditView） */
@Composable
fun PersonEditSheet(
    person: PersonEntity?,
    repo: EchoRepository,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    val scope = androidx.compose.runtime.rememberCoroutineScope()

    var name by remember { mutableStateOf("") }
    var birthYear by remember { mutableStateOf("") }
    var summary by remember { mutableStateOf("") }
    var story by remember { mutableStateOf("") }
    var coverBitmap by remember { mutableStateOf<Bitmap?>(null) }
    var bgmFileName by remember { mutableStateOf<String?>(null) }
    var bgmTitle by remember { mutableStateOf("") }

    val pid = person?.id ?: remember { repo.newId() }

    LaunchedEffect(person) {
        person?.let {
            name = it.name
            birthYear = it.birthYear
            summary = it.summary
            story = it.story
            bgmFileName = it.bgmFileName
            bgmTitle = it.bgmTitle ?: ""
            it.coverImageFileName?.let { f -> coverBitmap = MediaStore.loadImage(context, f, it.id) }
        }
    }

    val coverLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia(),
    ) { uri ->
        uri ?: return@rememberLauncherForActivityResult
        runCatching {
            context.contentResolver.openInputStream(uri)?.use { input: InputStream ->
                coverBitmap = BitmapFactory.decodeStream(input)
            }
        }
    }

    val audioLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument(),
    ) { uri ->
        uri ?: return@rememberLauncherForActivityResult
        runCatching {
            val ext = context.contentResolver.getType(uri)?.substringAfterLast('/') ?: "m4a"
            val old = bgmFileName
            val saved = MediaStore.saveAudioFile(context, uri, pid, ext) ?: return@rememberLauncherForActivityResult
            if (old != null) MediaStore.deleteFile(context, old, pid)
            bgmFileName = saved
            bgmTitle = uri.lastPathSegment?.substringBeforeLast('.') ?: "music"
        }
    }

    androidx.compose.ui.window.Dialog(onDismissRequest = onDismiss, properties = androidx.compose.ui.window.DialogProperties(usePlatformDefaultWidth = false)) {
        Column(
            Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background)
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
        ) {
            Row(
                Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                TextButton(onClick = onDismiss) { Text(stringRes(R.string.common_cancel)) }
                Spacer(Modifier.weight(1f))
                Text(
                    stringRes(if (person == null) R.string.edit_person_new_title else R.string.edit_person_edit_title),
                    fontWeight = FontWeight.Bold,
                    fontSize = 18.sp,
                )
                Spacer(Modifier.weight(1f))
                TextButton(
                    onClick = {
                        scope.launch {
                            val cover = coverBitmap
                            val oldCover = person?.coverImageFileName
                            val coverName = if (cover != null) {
                                if (oldCover != null) MediaStore.deleteFile(context, oldCover, pid)
                                MediaStore.saveImage(context, cover, pid)
                            } else person?.coverImageFileName

                            if (person == null) {
                                repo.createPerson(
                                    name = name.trim(),
                                    birthYear = birthYear.trim(),
                                    summary = summary,
                                    story = story,
                                    coverImageFileName = coverName,
                                    bgmFileName = bgmFileName,
                                    bgmTitle = bgmTitle.ifEmpty { null },
                                )
                            } else {
                                repo.updatePerson(
                                    person.copy(
                                        name = name.trim(),
                                        birthYear = birthYear.trim(),
                                        summary = summary,
                                        story = story,
                                        coverImageFileName = coverName,
                                        bgmFileName = bgmFileName,
                                        bgmTitle = bgmTitle.ifEmpty { null },
                                    ),
                                )
                            }
                            onDismiss()
                        }
                    },
                    enabled = name.trim().isNotEmpty(),
                ) { Text(stringRes(R.string.common_save)) }
            }

            SectionLabel(stringRes(R.string.edit_person_section_basics))
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text(stringRes(R.string.edit_person_name)) },
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                value = birthYear,
                onValueChange = { birthYear = it },
                label = { Text(stringRes(R.string.edit_person_birthYear)) },
                modifier = Modifier.fillMaxWidth(),
            )

            SectionLabel(stringRes(R.string.edit_person_section_summary))
            OutlinedTextField(
                value = summary,
                onValueChange = { summary = it },
                label = { Text(stringRes(R.string.edit_person_summary)) },
                minLines = 3,
                modifier = Modifier.fillMaxWidth(),
            )

            SectionLabel(stringRes(R.string.edit_person_section_story))
            OutlinedTextField(
                value = story,
                onValueChange = { story = it },
                label = { Text(stringRes(R.string.edit_person_story)) },
                minLines = 6,
                modifier = Modifier.fillMaxWidth(),
            )

            SectionLabel(stringRes(R.string.edit_person_section_cover))
            coverBitmap?.let { bmp ->
                Image(
                    bmp.asImageBitmap(),
                    contentDescription = null,
                    Modifier
                        .fillMaxWidth()
                        .height(150.dp)
                        .clip(RoundedCornerShape(12.dp)),
                )
                Spacer(Modifier.height(8.dp))
            }
            Button(onClick = { coverLauncher.launch(androidx.activity.result.PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }) {
                Text(stringRes(R.string.edit_cover_choose))
            }

            SectionLabel(stringRes(R.string.edit_person_section_bgm))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    bgmTitle.ifEmpty { stringRes(R.string.edit_bgm_none) },
                    color = if (bgmTitle.isEmpty()) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.weight(1f),
                )
                if (bgmFileName != null) {
                    TextButton(onClick = {
                        bgmFileName?.let { MediaStore.deleteFile(context, it, pid) }
                        bgmFileName = null
                        bgmTitle = ""
                    }) { Text(stringRes(R.string.common_delete), color = MaterialTheme.colorScheme.error) }
                }
            }
            Button(
                onClick = { audioLauncher.launch(arrayOf("audio/*", "audio/mpeg", "audio/mp4", "audio/wav", "audio/x-wav")) },
                colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.15f)),
            ) { Text(stringRes(R.string.edit_bgm_choose), color = MaterialTheme.colorScheme.primary) }
        }
    }
}

@Composable
fun SectionLabel(text: String) {
    Text(
        text,
        fontSize = 13.sp,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(vertical = 10.dp),
    )
}
