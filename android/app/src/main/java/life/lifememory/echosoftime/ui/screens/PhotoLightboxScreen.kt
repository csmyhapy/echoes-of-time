package life.lifememory.echosoftime.ui.screens

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
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MicNone
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import life.lifememory.echosoftime.R
import life.lifememory.echosoftime.audio.AudioPlayer
import life.lifememory.echosoftime.billing.PurchaseManager
import life.lifememory.echosoftime.data.EchoRepository
import life.lifememory.echosoftime.data.MediaStore
import life.lifememory.echosoftime.data.PersonBundle
import life.lifememory.echosoftime.data.PhotoEntity
import life.lifememory.echosoftime.ui.components.MessageSection
import life.lifememory.echosoftime.ui.components.stringRes
import life.lifememory.echosoftime.ui.sheets.PhotoEditSheet
import life.lifememory.echosoftime.ui.sheets.PhotoShareSheet
import life.lifememory.echosoftime.ui.sheets.RecorderSheet

/** 照片灯箱：横向翻页大图 + 下方信息面板（对应 iOS PhotoLightboxView） */
@Composable
fun PhotoLightboxScreen(
    bundle: PersonBundle,
    photos: List<PhotoEntity>,
    startIndex: Int,
    isReader: Boolean,
    repo: EchoRepository,
    purchase: PurchaseManager,
    onShowPaywall: () -> Unit,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    val pagerState = rememberPagerState(initialPage = startIndex.coerceIn(0, photos.lastIndex.coerceAtLeast(0))) { photos.size }
    val player = remember { AudioPlayer(context) }
    var storyExpanded by remember { mutableStateOf(false) }
    var showRecorder by remember { mutableStateOf(false) }
    var showEdit by remember { mutableStateOf(false) }
    var showMessages by remember { mutableStateOf(false) }
    var showShare by remember { mutableStateOf(false) }
    var tick by remember { mutableLongStateOf(0L) }

    val photo = photos.getOrNull(pagerState.currentPage)

    LaunchedEffect(pagerState.currentPage) {
        player.stop()
        storyExpanded = false
    }
    LaunchedEffect(photo?.id, player.isPlayingNow) {
        while (player.isPlayingNow) {
            delay(200)
            tick++
        }
    }

    androidx.compose.foundation.layout.Box(Modifier.fillMaxSize().background(Color.Black)) {
        Column(Modifier.fillMaxSize()) {
            // 顶栏
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "${pagerState.currentPage + 1} / ${photos.size}",
                    color = Color.White.copy(alpha = 0.7f),
                    fontSize = 13.sp,
                )
                Spacer(Modifier.weight(1f))
                if (!isReader) {
                    IconButton(onClick = { showEdit = true }) {
                        Icon(Icons.Filled.Edit, contentDescription = stringRes(R.string.photo_edit_action), tint = Color.White.copy(alpha = 0.92f))
                    }
                    IconButton(onClick = {
                        val existing = photo?.audioFileName != null
                        val count = bundle.voiceNotes.size
                        if (existing || purchase.canAddVoice(count)) showRecorder = true else onShowPaywall()
                    }) {
                        Icon(
                            if (photo?.audioFileName != null) Icons.Filled.Mic else Icons.Filled.MicNone,
                            contentDescription = stringRes(R.string.photo_record),
                            tint = Color.White.copy(alpha = 0.92f),
                        )
                    }
                    IconButton(onClick = { showMessages = true }) {
                        Icon(Icons.Filled.Forum, contentDescription = stringRes(R.string.photo_messages), tint = Color.White.copy(alpha = 0.92f))
                    }
                    IconButton(onClick = { if (purchase.canShare) showShare = true else onShowPaywall() }) {
                        Icon(Icons.Filled.Share, contentDescription = stringRes(R.string.share_title), tint = Color.White.copy(alpha = 0.92f))
                    }
                }
                IconButton(onClick = { player.stop(); onBack() }) {
                    Icon(Icons.Filled.Close, contentDescription = stringRes(R.string.common_close), tint = Color.White.copy(alpha = 0.92f))
                }
            }

            HorizontalPager(state = pagerState, modifier = Modifier.fillMaxWidth().height(320.dp)) { i ->
                val p = photos[i]
                AsyncImage(
                    model = ImageRequest.Builder(context)
                        .data(MediaStore.url(context, p.imageFileName, bundle.person.id))
                        .build(),
                    contentDescription = null,
                    contentScale = ContentScale.Fit,
                    modifier = Modifier.fillMaxSize(),
                )
            }

            // 信息面板
            Column(
                Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.background)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp, vertical = 16.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp),
            ) {
                if (photo != null) {
                    if (photo.caption.isNotEmpty()) {
                        Text(
                            photo.caption,
                            fontSize = if (isReader) 26.sp else 20.sp,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                    if (photo.story.isNotEmpty()) {
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(
                                stringRes(R.string.photo_story_title),
                                fontSize = 13.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Text(
                                photo.story,
                                fontSize = if (isReader) 19.sp else 15.sp,
                                lineHeight = (if (isReader) 26 else 20).sp,
                                maxLines = if (storyExpanded) Int.MAX_VALUE else 3,
                            )
                            if (photo.story.length > 50) {
                                TextButton(onClick = { storyExpanded = !storyExpanded }) {
                                    Text(
                                        stringRes(if (storyExpanded) R.string.person_story_collapse else R.string.person_story_expand),
                                        color = MaterialTheme.colorScheme.primary,
                                    )
                                }
                            }
                        }
                    }
                    NarrationRow(
                        photo = photo,
                        player = player,
                        isReader = isReader,
                        tick = tick,
                        onRecord = { showRecorder = true },
                    )
                    MessageSection(
                        person = bundle.person,
                        messages = bundle.messages,
                        nodeId = null,
                        photoId = photo.id,
                        isReader = isReader,
                        showsInput = false,
                        repo = repo,
                        purchase = purchase,
                        onShowPaywall = onShowPaywall,
                    )
                }
            }
        }
    }

    if (showRecorder && photo != null) {
        RecorderSheet(
            personId = bundle.person.id,
            titleKey = R.string.recorder_photo_title,
            onDismiss = { showRecorder = false },
        ) { fileName, duration ->
            scope.launch {
                repo.savePhotoVoice(bundle.person.id, photo.id, null, fileName, duration)
            }
        }
    }
    if (showEdit && photo != null) {
        PhotoEditSheet(
            photo = photo,
            person = bundle.person,
            nodes = bundle.sortedNodes,
            repo = repo,
            onDismiss = { showEdit = false },
        )
    }
    if (showMessages && photo != null) {
        androidx.compose.ui.window.Dialog(onDismissRequest = { showMessages = false }) {
            Column(
                Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.background)
                    .padding(20.dp),
            ) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text(stringRes(R.string.photo_messages), fontWeight = FontWeight.Bold, fontSize = 18.sp, modifier = Modifier.weight(1f))
                    TextButton(onClick = { showMessages = false }) { Text(stringRes(R.string.common_close)) }
                }
                MessageSection(
                    person = bundle.person,
                    messages = bundle.messages,
                    nodeId = null,
                    photoId = photo.id,
                    isReader = isReader,
                    showsInput = true,
                    repo = repo,
                    purchase = purchase,
                    onShowPaywall = onShowPaywall,
                )
            }
        }
    }
    if (showShare && photo != null) {
        PhotoShareSheet(
            photo = photo,
            person = bundle.person,
            repo = repo,
            purchase = purchase,
            onShowPaywall = onShowPaywall,
            onDismiss = { showShare = false },
        )
    }
}

@Composable
private fun NarrationRow(
    photo: PhotoEntity,
    player: AudioPlayer,
    isReader: Boolean,
    tick: Long,
    onRecord: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                stringRes(R.string.photo_narration_title),
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.weight(1f),
            )
            if (!isReader) {
                TextButton(onClick = onRecord) {
                    Text(
                        stringRes(if (photo.audioFileName == null) R.string.photo_record else R.string.photo_rerecord),
                        color = MaterialTheme.colorScheme.primary,
                        fontSize = 13.sp,
                    )
                }
            }
        }
        if (photo.audioFileName != null) {
            val context = LocalContext.current
            val uri = remember(photo.audioFileName) {
                android.net.Uri.fromFile(MediaStore.url(context, photo.audioFileName!!, photo.personId))
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                TextButton(onClick = { player.toggle(uri) }) {
                    Icon(
                        if (player.isPlayingNow) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                    )
                    Text(
                        stringRes(if (player.isPlayingNow) R.string.photo_narration_pause else R.string.photo_narration_play),
                        color = MaterialTheme.colorScheme.primary,
                        fontSize = 14.sp,
                    )
                }
                if (player.duration > 0) {
                    @Suppress("UNUSED_EXPRESSION") tick
                    Text(
                        AudioPlayer.timeText(if (player.isPlayingNow) player.currentTime else player.duration),
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        } else {
            Text(stringRes(R.string.voice_empty), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
