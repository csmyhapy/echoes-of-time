package life.lifememory.echosoftime.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Send
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import life.lifememory.echosoftime.R
import life.lifememory.echosoftime.billing.PurchaseManager
import life.lifememory.echosoftime.data.ArchiveText
import life.lifememory.echosoftime.data.EchoRepository
import life.lifememory.echosoftime.data.MessageEntity
import life.lifememory.echosoftime.data.PersonEntity

/** 家人留言区（对应 iOS MessageSection）：挂在人物/章节/照片，只读模式隐藏输入框 */
@Composable
fun MessageSection(
    person: PersonEntity,
    messages: List<MessageEntity>,
    nodeId: String?,
    photoId: String?,
    isReader: Boolean,
    showsInput: Boolean,
    repo: EchoRepository,
    purchase: PurchaseManager,
    onShowPaywall: () -> Unit,
) {
    val context = LocalContext.current
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    var expanded by remember { mutableStateOf(false) }
    var draft by remember { mutableStateOf("") }
    val author = remember {
        context.getSharedPreferences("app", android.content.Context.MODE_PRIVATE)
            .getString("familyName", null) ?: "Family"
    }

    val filtered = messages
        .filter { msg ->
            if (msg.isDeleted) return@filter false
            when {
                photoId != null -> msg.photoId == photoId
                nodeId != null -> msg.nodeId == nodeId && msg.photoId == null
                else -> msg.nodeId == null && msg.photoId == null
            }
        }
        .sortedBy { it.createdAt }

    val visible = if (expanded) filtered else filtered.takeLast(2)

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                stringRes(R.string.messages_title),
                fontSize = (if (isReader) 24 else 18).sp,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(Modifier.weight(1f))
            Text(
                "${filtered.size}",
                fontSize = (if (isReader) 20 else 14).sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        if (filtered.isEmpty()) {
            Text(
                stringRes(R.string.messages_empty),
                fontSize = (if (isReader) 20 else 14).sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        } else {
            visible.forEach { msg -> MessageRow(msg, isReader, onDelete = {
                scope.launch { repo.softDeleteMessage(msg) }
            }) }
            if (filtered.size > 2) {
                TextButton(onClick = { expanded = !expanded }) {
                    Text(
                        if (expanded) "Show less" else "Show all ${filtered.size} messages",
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
            }
        }

        if (showsInput && !isReader) {
            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = draft,
                    onValueChange = { draft = it },
                    label = { Text(stringRes(R.string.messages_placeholder)) },
                    minLines = 1,
                    modifier = Modifier.weight(1f),
                )
                IconButton(
                    onClick = {
                        val text = draft.trim()
                        if (text.isEmpty()) return@IconButton
                        val total = messages.filter { !it.isDeleted }.size
                        if (!purchase.canAddMessage(total)) {
                            onShowPaywall()
                            return@IconButton
                        }
                        scope.launch {
                            repo.insertMessage(
                                personId = person.id,
                                nodeId = nodeId,
                                photoId = photoId,
                                userName = author.ifEmpty { "Family" },
                                content = text,
                            )
                            draft = ""
                        }
                    },
                    enabled = draft.trim().isNotEmpty(),
                ) {
                    Icon(Icons.Filled.Send, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                }
            }
        }
    }
}

@Composable
private fun MessageRow(msg: MessageEntity, isReader: Boolean, onDelete: () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.07f))
            .padding(10.dp),
        verticalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                if (msg.userName.isEmpty()) "Family" else msg.userName,
                fontSize = (if (isReader) 19 else 13).sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.weight(1f),
            )
            Text(
                formatDate(msg.createdAt),
                fontSize = (if (isReader) 16 else 11).sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Text(
            ArchiveText.inline(msg.content),
            fontSize = (if (isReader) 22 else 15).sp,
            lineHeight = (if (isReader) 26 else 19).sp,
        )
    }
    Spacer(Modifier.height(8.dp))
}
