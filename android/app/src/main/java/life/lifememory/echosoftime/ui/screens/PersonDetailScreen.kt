package life.lifememory.echosoftime.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import kotlinx.coroutines.launch
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.AlertDialog
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
import life.lifememory.echosoftime.R
import life.lifememory.echosoftime.audio.AudioPlayer
import life.lifememory.echosoftime.audio.BgmManager
import life.lifememory.echosoftime.billing.PurchaseManager
import life.lifememory.echosoftime.data.ArchiveText
import life.lifememory.echosoftime.data.ArchiveIO
import life.lifememory.echosoftime.data.EchoRepository
import life.lifememory.echosoftime.data.PersonBundle
import life.lifememory.echosoftime.services.PdfExporter
import life.lifememory.echosoftime.ui.components.ArchiveParagraphView
import life.lifememory.echosoftime.ui.components.CoverImage
import life.lifememory.echosoftime.ui.components.stringRes
import life.lifememory.echosoftime.ui.sheets.NodeEditSheet
import life.lifememory.echosoftime.ui.sheets.PersonEditSheet
import life.lifememory.echosoftime.ui.sheets.RecorderSheet

@Composable
fun PersonDetailScreen(
    personId: String,
    isReader: Boolean,
    repo: EchoRepository,
    purchase: PurchaseManager,
    onOpenNode: (String) -> Unit,
    onOpenPhotos: () -> Unit,
    onShowPaywall: () -> Unit,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val bundle by repo.observePerson(personId).collectAsStateWithLifecycle(null)
    val player = remember { AudioPlayer(context) }

    var showEditPerson by remember { mutableStateOf(false) }
    var showNewNode by remember { mutableStateOf(false) }
    var editingNode by remember { mutableStateOf<life.lifememory.echosoftime.data.NodeEntity?>(null) }
    var deletingNode by remember { mutableStateOf<life.lifememory.echosoftime.data.NodeEntity?>(null) }
    var showRecorder by remember { mutableStateOf(false) }
    var storyExpanded by remember { mutableStateOf(false) }
    var timelineExpanded by remember { mutableStateOf(false) }
    var menuOpen by remember { mutableStateOf(false) }
    var exporting by remember { mutableStateOf(false) }
    var exportError by remember { mutableStateOf(false) }
    val scope = androidx.compose.runtime.rememberCoroutineScope()

    val b = bundle ?: return

    fun shareFile(file: java.io.File, mime: String) {
        val uri = androidx.core.content.FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        val intent = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
            type = mime
            putExtra(android.content.Intent.EXTRA_STREAM, uri)
            addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(android.content.Intent.createChooser(intent, context.getString(R.string.export_pdf)))
    }

    fun runExport(album: Boolean) {
        exporting = true
        scope.launch {
            val file = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                if (album) PdfExporter.makeAlbumPdf(context, b) else ArchiveIO.makeArchive(context, b)
            }
            exporting = false
            if (file != null) shareFile(file, if (album) "application/pdf" else "application/zip")
            else exportError = true
        }
    }

    LaunchedEffect(b.person.bgmFileName, personId) {
        if (BgmManager.isEnabled(context)) {
            BgmManager.play(context, b.person.bgmFileName, personId)
        }
    }

    val sortedNodes = b.sortedNodes
    val personVoice = b.personVoice()
    val totalChars = b.person.story.length +
        b.nodes.sumOf { it.story.length + it.summary.length } +
        b.photos.sumOf { it.caption.length + it.story.length }
    val totalAudio = b.voiceNotes.sumOf { it.duration }
    val progressItems: List<Pair<Boolean, String>> = listOf(
        (b.person.summary.trim().isNotEmpty()) to stringRes(R.string.progress_item_summary),
        (b.person.story.isNotEmpty()) to stringRes(R.string.progress_item_story),
        (sortedNodes.isNotEmpty()) to stringRes(R.string.progress_item_chapter),
        (b.photos.isNotEmpty()) to stringRes(R.string.progress_item_photo),
        (personVoice != null) to stringRes(R.string.progress_item_voice),
    )
    val progressPercent = progressItems.count { it.first } * 20

    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize()) {
            // 顶栏
            Row(
                Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.background).padding(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = onBack) { Icon(Icons.Filled.ArrowBack, contentDescription = null) }
                Text(
                    b.person.name,
                    fontWeight = FontWeight.Bold,
                    fontSize = 20.sp,
                    modifier = Modifier.weight(1f),
                )
                if (!isReader) {
                    IconButton(onClick = { showEditPerson = true }) {
                        Text(stringRes(R.string.common_edit), color = MaterialTheme.colorScheme.primary)
                    }
                    Box {
                        IconButton(onClick = { menuOpen = true }) {
                            Icon(Icons.Filled.Share, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                        }
                        DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                            DropdownMenuItem(
                                text = { Text(stringRes(R.string.export_pdf)) },
                                onClick = {
                                    menuOpen = false
                                    if (purchase.canExport) runExport(true) else onShowPaywall()
                                },
                            )
                            DropdownMenuItem(
                                text = { Text(stringRes(R.string.export_archive)) },
                                onClick = {
                                    menuOpen = false
                                    if (purchase.canExport) runExport(false) else onShowPaywall()
                                },
                            )
                        }
                    }
                }
            }

            Column(
                Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(22.dp),
            ) {
                CoverImage(
                    fileName = b.resolvedCoverFileName,
                    personId = personId,
                    modifier = Modifier.fillMaxWidth().height((if (isReader) 260 else 200).dp),
                )

                // info
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(b.person.name, fontSize = (if (isReader) 32 else 26).sp, fontWeight = FontWeight.Bold)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        if (b.person.birthYear.isNotEmpty()) {
                            Text(
                                b.person.birthYear,
                                fontSize = (if (isReader) 20 else 15).sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        Spacer(Modifier.weight(1f))
                        StatValue(sortedNodes.size, R.string.unit_chapters, isReader)
                        Spacer(Modifier.width(12.dp))
                        StatValue(b.photos.size, R.string.unit_photos, isReader, onClick = if (!isReader) onOpenPhotos else null)
                        Spacer(Modifier.width(12.dp))
                        StatValue(b.messages.filter { !it.isDeleted }.size, R.string.unit_messages, isReader)
                    }
                    if (!b.person.bgmTitle.isNullOrEmpty()) {
                        Text(
                            b.person.bgmTitle!!,
                            fontSize = (if (isReader) 16 else 12).sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }

                if (b.person.summary.isNotEmpty()) {
                    Text(
                        ArchiveText.inline(b.person.summary),
                        fontSize = (if (isReader) 22 else 15).sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        lineHeight = (if (isReader) 28 else 19).sp,
                    )
                }

                OverviewCard(progressItems, progressPercent, totalChars, totalAudio, isReader)

                if (b.person.story.isNotEmpty()) {
                    StorySection(b.person.story, expanded = isReader || storyExpanded, isReader,
                        onToggle = { storyExpanded = !storyExpanded })
                }

                VoiceSection(
                    note = personVoice,
                    personId = personId,
                    isReader = isReader,
                    player = player,
                    canRecord = personVoice != null || purchase.canAddVoice(b.voiceNotes.size),
                    onRecord = { showRecorder = true },
                    onShowPaywall = onShowPaywall,
                )

                TimelineSection(
                    bundle = b,
                    isReader = isReader,
                    expanded = timelineExpanded,
                    onToggleExpand = { timelineExpanded = !timelineExpanded },
                    onOpenNode = onOpenNode,
                    onAddNode = {
                        if (purchase.canAddNode(sortedNodes.size)) showNewNode = true else onShowPaywall()
                    },
                    onEditNode = { editingNode = it },
                    onDeleteNode = { deletingNode = it },
                    onMoveNode = { node, dir ->
                        val list = b.sortedNodes.toMutableList()
                        val i = list.indexOf(node)
                        val j = i + dir
                        if (i in list.indices && j in list.indices) {
                            val t = list[i]; list[i] = list[j]; list[j] = t
                            scope.launch { repo.reorderNodes(list) }
                        }
                    },
                )

                life.lifememory.echosoftime.ui.components.MessageSection(
                    person = b.person,
                    messages = b.messages,
                    nodeId = null,
                    photoId = null,
                    isReader = isReader,
                    showsInput = true,
                    repo = repo,
                    purchase = purchase,
                    onShowPaywall = onShowPaywall,
                )
            }
        }

        if (!isReader) {
            Box(
                Modifier
                    .align(Alignment.BottomEnd)
                    .padding(end = 18.dp, bottom = 150.dp)
                    .size(52.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primary)
                    .clickable(onClick = onOpenPhotos),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Filled.PhotoLibrary, contentDescription = null, tint = androidx.compose.ui.graphics.Color.White)
            }
        }
    }

    if (showEditPerson) {
        PersonEditSheet(person = b.person, repo = repo, onDismiss = { showEditPerson = false })
    }
    if (showNewNode) {
        NodeEditSheet(person = b.person, node = null, repo = repo, onDismiss = { showNewNode = false })
    }
    editingNode?.let { n ->
        NodeEditSheet(person = b.person, node = n, repo = repo, onDismiss = { editingNode = null })
    }
    deletingNode?.let { n ->
        AlertDialog(
            onDismissRequest = { deletingNode = null },
            title = { Text(stringRes(R.string.common_delete)) },
            text = { Text(n.name) },
            confirmButton = {
                TextButton(onClick = {
                    scope.launch { repo.deleteNode(n) }
                    deletingNode = null
                }) { Text(stringRes(R.string.common_delete), color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { deletingNode = null }) { Text(stringRes(R.string.common_cancel)) } },
        )
    }
    if (showRecorder) {
        val scope = androidx.compose.runtime.rememberCoroutineScope()
        RecorderSheet(
            personId = personId,
            titleKey = R.string.recorder_person_title,
            onDismiss = { showRecorder = false },
        ) { fileName, duration ->
            scope.launch { repo.savePersonVoice(personId, personVoice, fileName, duration) }
        }
    }
    if (exportError) {
        AlertDialog(
            onDismissRequest = { exportError = false },
            confirmButton = { TextButton(onClick = { exportError = false }) { Text(stringRes(R.string.common_save)) } },
            title = { Text(stringRes(R.string.export_failed)) },
        )
    }
}

@Composable
private fun StatValue(count: Int, key: Int, isReader: Boolean, onClick: (() -> Unit)? = null) {
    val text = "${count} " + stringRes(key)
    val comp: @Composable () -> Unit = {
        Text(
            text,
            fontSize = (if (isReader) 18 else 13).sp,
            fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.primary.copy(alpha = 0.85f),
        )
    }
    if (onClick != null) {
        TextButton(onClick = onClick) { comp() }
    } else {
        comp()
    }
}

@Composable
private fun OverviewCard(
    items: List<Pair<Boolean, String>>,
    percent: Int,
    chars: Int,
    audioSeconds: Int,
    isReader: Boolean,
) {
    Card(
        Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(16.dp),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row {
                Text(stringRes(R.string.progress_title), fontSize = (if (isReader) 22 else 17).sp, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.weight(1f))
                Text("$percent%", fontSize = (if (isReader) 24 else 20).sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
            }
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(8.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.15f)),
            ) {
                Box(
                    Modifier
                        .fillMaxWidth(percent / 100f)
                        .height(8.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.primary),
                )
            }
            items.forEach { (done, title) ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        if (done) Icons.Filled.CheckCircle else Icons.Outlined.Circle,
                        contentDescription = null,
                        tint = if (done) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                        modifier = Modifier.size(15.dp),
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        title,
                        fontSize = (if (isReader) 18 else 14).sp,
                        color = if (done) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(28.dp)) {
                StatBlock("$chars", R.string.stats_chars, isReader)
                StatBlock(audioText(audioSeconds), R.string.stats_audio, isReader)
            }
        }
    }
}

@Composable
private fun StatBlock(value: String, key: Int, isReader: Boolean) {
    Column {
        Text(value, fontSize = (if (isReader) 22 else 19).sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
        Text(stringRes(key), fontSize = (if (isReader) 15 else 12).sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

private fun audioText(seconds: Int): String {
    if (seconds <= 0) return "0:00"
    val h = seconds / 3600; val m = (seconds % 3600) / 60; val s = seconds % 60
    return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%d:%02d".format(m, s)
}

@Composable
private fun StorySection(story: String, expanded: Boolean, isReader: Boolean, onToggle: () -> Unit) {
    val body = ArchiveText.parse(story)
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(stringRes(R.string.person_section_story), fontSize = (if (isReader) 26 else 20).sp, fontWeight = FontWeight.SemiBold)
        ArchiveParagraphView(
            paragraphs = body.paragraphs,
            expanded = expanded,
            fontSize = if (isReader) 24 else 16,
            lineSpacing = 6,
        )
        if (!isReader) {
            TextButton(onClick = onToggle) {
                Text(
                    stringRes(if (expanded) R.string.person_story_collapse else R.string.person_story_expand),
                    color = MaterialTheme.colorScheme.primary,
                )
            }
        }
    }
}

@Composable
private fun VoiceSection(
    note: life.lifememory.echosoftime.data.VoiceNoteEntity?,
    personId: String,
    isReader: Boolean,
    player: AudioPlayer,
    canRecord: Boolean,
    onRecord: () -> Unit,
    onShowPaywall: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(stringRes(R.string.person_voice_title), fontSize = (if (isReader) 26 else 18).sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.weight(1f))
            if (!isReader) {
                TextButton(onClick = { if (canRecord) onRecord() else onShowPaywall() }) {
                    Icon(Icons.Filled.PlayCircle, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                    Spacer(Modifier.width(4.dp))
                    Text(stringRes(R.string.voice_record), color = MaterialTheme.colorScheme.primary)
                }
            }
        }
        if (note != null) {
            life.lifememory.echosoftime.ui.components.VoiceNotePlayButton(note.audioFileName, personId, player)
        } else {
            Text(stringRes(R.string.voice_empty), fontSize = (if (isReader) 20 else 14).sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun TimelineSection(
    bundle: PersonBundle,
    isReader: Boolean,
    expanded: Boolean,
    onToggleExpand: () -> Unit,
    onOpenNode: (String) -> Unit,
    onAddNode: () -> Unit,
    onEditNode: (life.lifememory.echosoftime.data.NodeEntity) -> Unit,
    onDeleteNode: (life.lifememory.echosoftime.data.NodeEntity) -> Unit,
    onMoveNode: (life.lifememory.echosoftime.data.NodeEntity, Int) -> Unit,
) {
    val all = bundle.sortedNodes
    val visible = if (expanded) all else all.take(3)
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(stringRes(R.string.person_section_timeline), fontSize = (if (isReader) 26 else 20).sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.weight(1f))
            if (!isReader) {
                TextButton(onClick = onAddNode) {
                    Text("+", fontSize = 24.sp, color = MaterialTheme.colorScheme.primary)
                }
            }
        }
        if (!isReader && all.isNotEmpty()) {
            Text(stringRes(R.string.chapter_drag_hint), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        if (all.isEmpty()) {
            Text(stringRes(R.string.person_empty_nodes), fontSize = (if (isReader) 22 else 15).sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        } else {
            visible.forEach { node ->
                val idx = all.indexOf(node)
                NodeCard(
                    node = node,
                    coverFileName = bundle.resolvedCover(node),
                    personId = bundle.person.id,
                    large = isReader,
                    onClick = { onOpenNode(node.id) },
                    onEdit = { onEditNode(node) },
                    onDelete = { onDeleteNode(node) },
                    canMoveUp = idx > 0,
                    canMoveDown = idx < all.size - 1,
                    onMove = { dir -> onMoveNode(node, dir) },
                )
            }
            if (all.size > 3) {
                TextButton(onClick = onToggleExpand) {
                    Text(
                        if (expanded) "Show less" else "Show all ${all.size} chapters",
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
            }
        }
    }
}

@Composable
private fun NodeCard(
    node: life.lifememory.echosoftime.data.NodeEntity,
    coverFileName: String?,
    personId: String,
    large: Boolean,
    onClick: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    canMoveUp: Boolean,
    canMoveDown: Boolean,
    onMove: (Int) -> Unit,
) {
    var menuOpen by remember { mutableStateOf(false) }
    Card(
        Modifier.fillMaxWidth().clickable(onClick = onClick),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.06f)),
        shape = RoundedCornerShape(16.dp),
    ) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                CoverImage(
                    fileName = coverFileName,
                    personId = personId,
                    iconSize = if (large) 28 else 20,
                    modifier = Modifier.size((if (large) 88 else 64).dp),
                )
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(node.name, fontSize = (if (large) 26 else 18).sp, fontWeight = FontWeight.SemiBold)
                    if (node.yearRange.isNotEmpty()) {
                        Text(node.yearRange, fontSize = (if (large) 20 else 14).sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
                if (!large) {
                    Box {
                        IconButton(onClick = { menuOpen = true }) {
                            Icon(Icons.Filled.MoreVert, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                            DropdownMenuItem(
                                text = { Text(stringRes(R.string.common_edit)) },
                                onClick = { menuOpen = false; onEdit() },
                            )
                            if (canMoveUp) {
                                DropdownMenuItem(
                                    text = { Text(stringRes(R.string.photo_moveLeft)) },
                                    onClick = { menuOpen = false; onMove(-1) },
                                )
                            }
                            if (canMoveDown) {
                                DropdownMenuItem(
                                    text = { Text(stringRes(R.string.photo_moveRight)) },
                                    onClick = { menuOpen = false; onMove(1) },
                                )
                            }
                            DropdownMenuItem(
                                text = { Text(stringRes(R.string.common_delete), color = MaterialTheme.colorScheme.error) },
                                onClick = { menuOpen = false; onDelete() },
                            )
                        }
                    }
                }
            }
            if (node.summary.isNotEmpty()) {
                Text(ArchiveText.inline(node.summary), fontSize = (if (large) 22 else 15).sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}
