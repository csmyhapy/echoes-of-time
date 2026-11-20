package life.lifememory.echosoftime.ui.components

import android.content.Context
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PauseCircle
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material3.Icon
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import kotlinx.coroutines.delay
import life.lifememory.echosoftime.audio.AudioPlayer
import life.lifememory.echosoftime.data.MediaStore
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** 封面图通用组件：有图显示图，无图显示棕色渐变 + 人形图标 */
@Composable
fun CoverImage(
    fileName: String?,
    personId: String,
    iconSize: Int = 32,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val file = fileName?.let { MediaStore.url(context, it, personId) }
    Box(
        modifier.clip(RoundedCornerShape(16)),
        contentAlignment = Alignment.Center,
    ) {
        if (file?.exists() == true) {
            AsyncImage(
                model = ImageRequest.Builder(context).data(file).build(),
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
        } else {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(
                        Brush.linearGradient(
                            listOf(
                                MaterialTheme.colorScheme.primary.copy(alpha = 0.35f),
                                MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
                            ),
                        ),
                    ),
            )
            Icon(
                Icons.Filled.Person,
                contentDescription = null,
                tint = Color.White.copy(alpha = 0.85f),
                modifier = Modifier.padding(iconSize.dp / 2),
            )
        }
    }
}

/** 旁白播放按钮（章节级 / 人物级复用），与 iOS VoiceNotePlayButton 一致 */
@Composable
fun VoiceNotePlayButton(fileName: String, personId: String, player: AudioPlayer) {
    val context = LocalContext.current
    val uri: Uri = remember(fileName, personId) {
        Uri.fromFile(MediaStore.url(context, fileName, personId))
    }
    var total by remember { mutableStateOf(0.0) }
    var tick by remember { mutableStateOf(0L) }

    LaunchedEffect(uri) {
        total = player.durationOf(uri)
    }
    LaunchedEffect(player.isPlayingNow) {
        while (player.isPlayingNow) {
            tick = System.currentTimeMillis()
            delay(200)
        }
    }

    Row(verticalAlignment = Alignment.CenterVertically) {
        TextButton(onClick = { player.toggle(uri) }) {
            Icon(
                if (player.isPlayingNow) Icons.Filled.PauseCircle else Icons.Filled.PlayCircle,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
            )
            Text(
                if (player.isPlayingNow) "photo.narration.pause" else "voice.play",
                color = MaterialTheme.colorScheme.primary,
            )
        }
        Text(
            remember(total, player.isPlayingNow, tick) {
                when {
                    total <= 0.0 -> ""
                    player.isPlayingNow ->
                        "${AudioPlayer.timeText(player.currentTime)} / ${AudioPlayer.timeText(total)}"
                    else -> AudioPlayer.timeText(total)
                }
            },
            fontSize = 12.sp,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )
    }
}

/** 正文段落渲染：段间不留空行，段距比行距大 30%；折叠按行数截断 */
@Composable
fun ArchiveParagraphView(
    paragraphs: List<String>,
    expanded: Boolean,
    fontSize: Int,
    lineSpacing: Int,
    collapsedLines: Int = 4,
) {
    val paragraphSpacing = ((fontSize * 0.18f + lineSpacing) * 1.3f).dp
    if (expanded) {
        Column(verticalArrangement = Arrangement.spacedBy(paragraphSpacing)) {
            paragraphs.forEach { p ->
                Text(
                    p,
                    fontSize = fontSize.sp,
                    lineHeight = (fontSize + lineSpacing).sp,
                    modifier = Modifier.fillMaxSize(),
                )
            }
        }
    } else {
        Text(
            paragraphs.joinToString("\n"),
            fontSize = fontSize.sp,
            lineHeight = (fontSize + lineSpacing).sp,
            maxLines = collapsedLines,
        )
    }
}

/** 本地取字符串的轻量包装，避免每个 Composable 都拿 context */
@Composable
fun stringRes(id: Int): String = androidx.compose.ui.res.stringResource(id)

fun formatDate(epochMs: Long): String =
    SimpleDateFormat("MMM d, yyyy", Locale.getDefault()).format(Date(epochMs))

fun archiveParagraphs(text: String): List<String> =
    text.split(Regex("\n\\s*\n")).map { it.trim() }.filter { it.isNotEmpty() }
