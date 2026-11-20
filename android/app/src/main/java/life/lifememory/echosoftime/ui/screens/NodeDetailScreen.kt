package life.lifememory.echosoftime.ui.screens

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import coil.request.ImageRequest
import life.lifememory.echosoftime.R
import life.lifememory.echosoftime.audio.AudioPlayer
import life.lifememory.echosoftime.billing.PurchaseManager
import life.lifememory.echosoftime.data.ArchiveText
import life.lifememory.echosoftime.data.EchoRepository
import life.lifememory.echosoftime.data.NodeEntity
import life.lifememory.echosoftime.data.PersonBundle
import life.lifememory.echosoftime.data.belongsTo
import life.lifememory.echosoftime.ui.components.ArchiveParagraphView
import life.lifememory.echosoftime.ui.components.CoverImage
import life.lifememory.echosoftime.ui.components.MessageSection
import life.lifememory.echosoftime.ui.components.VoiceNotePlayButton
import life.lifememory.echosoftime.ui.components.stringRes
import life.lifememory.echosoftime.ui.sheets.AddFromLibrarySheet
import life.lifememory.echosoftime.ui.sheets.NodeEditSheet
import life.lifememory.echosoftime.ui.sheets.PhotoOrderSheet
import life.lifememory.echosoftime.ui.sheets.RecorderSheet
import kotlinx.coroutines.launch

@Composable
fun NodeDetailScreen(
    nodeId: String,
    isReader: Boolean,
    repo: EchoRepository,
    purchase: PurchaseManager,
    onShowPaywall: () -> Unit,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    var node by remember { mutableStateOf<NodeEntity?>(null) }
    var menuOpen by remember { mutableStateOf(false) }
    var showRecorder by remember { mutableStateOf(false) }
    var showEdit by remember { mutableStateOf(false) }
    var photoExpanded by remember { mutableStateOf(false) }
    var storyExpanded by remember { mutableStateOf(false) }
    var lightboxIndex by remember { mutableStateOf<Int?>(null) }
    var showAddFromLibrary by remember { mutableStateOf(false) }
    var showOrder by remember { mutableStateOf(false) }
    val player = remember { AudioPlayer(context) }

    LaunchedEffect(nodeId) { node = repo.node(nodeId) }
    val n = node ?: return
    val bundle by repo.observePerson(n.personId).collectAsStateWithLifecycle(null)
    val b: PersonBundle = bundle ?: return

    val photos = b.photos.filter { it.belongsTo(n) }.sortedBy { it.sortOrder }
    val visible = if (photoExpanded) photos else photos.take(6)
    val nodeVoice = b.nodeVoice(n.id)

    val picker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(20),
    ) { uris ->
        if (uris.isEmpty()) return@rememberLauncherForActivityResult
        scope.launch {
            var order = photos.maxOfOrNull { it.sortOrder } ?: -1
            for (uri in uris) {
                val name = MediaStoreSaveImageFromUri(context, uri, n.personId) ?: continue
                order += 1
                repo.insertPhoto(
                    personId = n.personId,
                    nodeId = n.id,
                    imageFileName = name,
                    sortOrder = order,
                    tags = n.id,
                )
            }
        }
    }

    Column(Modifier.fillMaxSize()) {
        Row(
            Modifier.fillMaxWidth().padding(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onBack) { Icon(Icons.Filled.ArrowBack, contentDescription = null) }
            Text(n.name, fontWeight = FontWeight.Bold, fontSize = 20.sp, modifier = Modifier.weight(1f))
            if (!isReader) {
                Box {
                    IconButton(onClick = { menuOpen = true }) { Icon(Icons.Filled.Add, contentDescription = null) }
                    DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                        DropdownMenuItem(
                            text = { Text(stringRes(R.string.node_action_add_photos)) },
                            onClick = {
                                menuOpen = false
                                if (purchase.canAddPhoto(b.photos.size)) picker.launch(
                                    androidx.activity.result.PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly),
                                ) else onShowPaywall()
                            },
                        )
                        DropdownMenuItem(
                            text = { Text(stringRes(R.string.node_action_voice)) },
                            onClick = {
                                menuOpen = false
                                if (nodeVoice != null || purchase.canAddVoice(b.voiceNotes.size)) showRecorder = true
                                else onShowPaywall()
                            },
                        )
                        DropdownMenuItem(
                            text = { Text(stringRes(R.string.node_action_edit)) },
                            onClick = { menuOpen = false; showEdit = true },
                        )
                        DropdownMenuItem(
                            text = { Text(stringRes(R.string.photo_library_add_title)) },
                            onClick = { menuOpen = false; showAddFromLibrary = true },
                        )
                        DropdownMenuItem(
                            text = { Text(stringRes(R.string.photo_order_title)) },
                            onClick = { menuOpen = false; showOrder = true },
                        )
                    }
                }
            }
        }

        Column(
            Modifier
                .fillMaxSize()
                .padding(horizontal = 20.dp, vertical = 8.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            CoverImage(
                fileName = b.resolvedCover(n),
                personId = n.personId,
                modifier = Modifier.fillMaxWidth().height((if (isReader) 190 else 130).dp),
            )

            if (n.yearRange.isNotEmpty()) {
                Text(n.yearRange, fontSize = (if (isReader) 22 else 15).sp, color = MaterialTheme.colorScheme.primary)
            }

            if (n.story.isNotEmpty()) {
                val body = ArchiveText.parse(n.story)
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    ArchiveParagraphView(
                        paragraphs = body.paragraphs,
                        expanded = isReader || storyExpanded,
                        fontSize = if (isReader) 24 else 16,
                        lineSpacing = 6,
                    )
                    if (!isReader && body.paragraphs.size > 1) {
                        TextButton(onClick = { storyExpanded = !storyExpanded }) {
                            Text(
                                stringRes(if (storyExpanded) R.string.person_story_collapse else R.string.person_story_expand),
                                color = MaterialTheme.colorScheme.primary,
                            )
                        }
                    }
                }
            }

            // 章节旁白
            if (nodeVoice != null) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(stringRes(R.string.node_voice_title), fontSize = (if (isReader) 26 else 20).sp, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.weight(1f))
                    if (!isReader) {
                        TextButton(onClick = { showRecorder = true }) {
                            Icon(Icons.Filled.Mic, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                            Text(stringRes(R.string.voice_record), color = MaterialTheme.colorScheme.primary)
                        }
                    }
                }
                VoiceNotePlayButton(nodeVoice.audioFileName, n.personId, player)
            } else {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.Mic, contentDescription = null, modifier = Modifier.padding(end = 8.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(stringRes(R.string.voice_empty), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.weight(1f))
                    if (!isReader) {
                        TextButton(onClick = {
                            if (purchase.canAddVoice(b.voiceNotes.size)) showRecorder = true else onShowPaywall()
                        }) { Text(stringRes(R.string.voice_record), color = MaterialTheme.colorScheme.primary) }
                    }
                }
            }

            // 照片网格
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(stringRes(R.string.node_section_photos), fontSize = (if (isReader) 26 else 20).sp, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.weight(1f))
                    Text("${photos.size}", fontSize = (if (isReader) 20 else 15).sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                if (photos.isEmpty()) {
                    Text(stringRes(R.string.node_empty_photos), fontSize = (if (isReader) 22 else 15).sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                } else {
                    // 静态三列（页面本身 verticalScroll，不能再嵌 LazyVerticalGrid，否则无限高度崩溃）
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        visible.chunked(3).forEach { rowPhotos ->
                            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                rowPhotos.forEach { photo ->
                                    Box(
                                        Modifier
                                            .weight(1f)
                                            .aspectRatio(1f)
                                            .clip(RoundedCornerShape(8.dp))
                                            .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.12f))
                                            .clickable { lightboxIndex = visible.indexOf(photo) },
                                    ) {
                                        AsyncImage(
                                            model = ImageRequest.Builder(context)
                                                .data(mediaFile(context, photo.imageFileName, n.personId))
                                                .build(),
                                            contentDescription = null,
                                            contentScale = androidx.compose.ui.layout.ContentScale.Crop,
                                            modifier = Modifier.fillMaxSize(),
                                        )
                                        if (photo.imageFileName == n.coverImageFileName) {
                                            Text(
                                                stringRes(R.string.node_cover_badge),
                                                fontSize = 10.sp,
                                                color = androidx.compose.ui.graphics.Color.White,
                                                modifier = Modifier
                                                    .align(Alignment.TopStart)
                                                    .padding(4.dp)
                                                    .clip(RoundedCornerShape(8.dp))
                                                    .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.9f))
                                                    .padding(horizontal = 5.dp, vertical = 2.dp),
                                            )
                                        }
                                    }
                                }
                                repeat(3 - rowPhotos.size) { Spacer(Modifier.weight(1f)) }
                            }
                        }
                    }
                    if (photos.size > 6) {
                        TextButton(onClick = { photoExpanded = !photoExpanded }) {
                            Text(
                                if (photoExpanded) "Show less" else "Show all ${photos.size} photos",
                                color = MaterialTheme.colorScheme.primary,
                            )
                        }
                    }
                }
            }

            MessageSection(
                person = b.person,
                messages = b.messages,
                nodeId = n.id,
                photoId = null,
                isReader = isReader,
                showsInput = true,
                repo = repo,
                purchase = purchase,
                onShowPaywall = onShowPaywall,
            )
        }
    }

    if (showRecorder) {
        RecorderSheet(
            personId = n.personId,
            titleKey = R.string.recorder_node_title,
            onDismiss = { showRecorder = false },
        ) { fileName, duration ->
            scope.launch { repo.saveNodeVoice(n.personId, n.id, nodeVoice, fileName, duration) }
        }
    }
    if (showEdit) {
        NodeEditSheet(person = b.person, node = n, repo = repo, onDismiss = { showEdit = false })
    }
    if (showAddFromLibrary) {
        AddFromLibrarySheet(
            person = b.person,
            node = n,
            allPhotos = b.photos,
            nodes = b.sortedNodes,
            repo = repo,
            onDismiss = { showAddFromLibrary = false },
        )
    }
    if (showOrder) {
        PhotoOrderSheet(
            photos = photos,
            personId = n.personId,
            repo = repo,
            onDismiss = { showOrder = false },
        )
    }
    lightboxIndex?.let { idx ->
        PhotoLightboxScreen(
            bundle = b,
            photos = visible,
            startIndex = idx,
            isReader = isReader,
            repo = repo,
            purchase = purchase,
            onShowPaywall = onShowPaywall,
            onBack = { lightboxIndex = null },
        )
    }
}

private fun mediaFile(context: android.content.Context, fileName: String, personId: String) =
    life.lifememory.echosoftime.data.MediaStore.url(context, fileName, personId)

private fun MediaStoreSaveImageFromUri(context: android.content.Context, uri: android.net.Uri, personId: String): String? =
    life.lifememory.echosoftime.data.MediaStore.saveImageFromUri(context, uri, personId)
