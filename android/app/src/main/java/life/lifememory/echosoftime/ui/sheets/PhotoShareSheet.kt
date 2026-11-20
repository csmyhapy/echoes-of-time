package life.lifememory.echosoftime.ui.sheets

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import life.lifememory.echosoftime.R
import life.lifememory.echosoftime.billing.PurchaseManager
import life.lifememory.echosoftime.data.EchoRepository
import life.lifememory.echosoftime.data.PersonEntity
import life.lifememory.echosoftime.data.PhotoEntity
import life.lifememory.echosoftime.services.ShareExporter
import life.lifememory.echosoftime.ui.components.stringRes

/** 照片分享面板：网页 / 卡片图 / 复制说明 / 导入亲友回信（对应 iOS PhotoShareSheet） */
@Composable
fun PhotoShareSheet(
    photo: PhotoEntity,
    person: PersonEntity,
    repo: EchoRepository,
    purchase: PurchaseManager,
    onShowPaywall: () -> Unit,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var working by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var copied by remember { mutableStateOf(false) }
    var showImport by remember { mutableStateOf(false) }

    fun shareFile(file: java.io.File, mime: String) {
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(intent, context.getString(R.string.share_title)))
    }

    fun gate(block: () -> Unit) {
        if (purchase.canShare) block() else onShowPaywall()
    }

    androidx.compose.ui.window.Dialog(onDismissRequest = onDismiss) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(20.dp)
                .background(MaterialTheme.colorScheme.background),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(stringRes(R.string.share_title), fontWeight = FontWeight.Bold, fontSize = 18.sp)

            ShareRow(stringRes(R.string.share_option_page)) {
                gate {
                    working = true; error = null
                    scope.launch {
                        val file = withContext(Dispatchers.IO) { ShareExporter.makePageHtml(context, photo, person) }
                        working = false
                        if (file != null) shareFile(file, "text/html") else error = context.getString(R.string.share_error_page)
                    }
                }
            }
            ShareRow(stringRes(R.string.share_option_card)) {
                gate {
                    working = true; error = null
                    scope.launch {
                        val file = withContext(Dispatchers.IO) {
                            ShareExporter.makeCard(context, photo, person)?.let {
                                ShareExporter.writeCard(context, it, person, photo.caption)
                            }
                        }
                        working = false
                        if (file != null) shareFile(file, "image/jpeg") else error = context.getString(R.string.share_error_card)
                    }
                }
            }
            ShareRow(stringRes(R.string.share_option_copy)) {
                gate {
                    val note = listOf(
                        context.getString(R.string.share_head_title),
                        context.getString(R.string.share_head_p1, person.name),
                        context.getString(R.string.share_head_p2),
                    ).joinToString("\n\n")
                    val cm = context.getSystemService(android.content.ClipboardManager::class.java)
                    cm?.setPrimaryClip(android.content.ClipData.newPlainText("note", note))
                    copied = true
                    scope.launch { kotlinx.coroutines.delay(2000); copied = false }
                }
            }

            Text(
                stringRes(R.string.share_send_footer),
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            ShareRow(stringRes(R.string.share_option_import)) { showImport = true }
            Text(
                stringRes(R.string.share_import_footer),
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            if (copied) {
                Text(stringRes(R.string.share_copied), fontSize = 13.sp, color = MaterialTheme.colorScheme.primary)
            }
            if (working) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    CircularProgressIndicator(modifier = Modifier.size(18.dp))
                    Text(stringRes(R.string.share_working), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            error?.let { Text(it, fontSize = 13.sp, color = MaterialTheme.colorScheme.error) }

            TextButton(onClick = onDismiss, modifier = Modifier.align(Alignment.End)) {
                Text(stringRes(R.string.common_close))
            }
        }
    }

    if (showImport) {
        ReplyImportSheet(photo = photo, person = person, repo = repo, onDismiss = { showImport = false })
    }
}

@Composable
private fun ShareRow(label: String, onClick: () -> Unit) {
    TextButton(onClick = onClick, modifier = Modifier.fillMaxWidth()) {
        Text(label, fontSize = 16.sp, modifier = Modifier.weight(1f))
    }
}

@Composable
private fun ReplyImportSheet(photo: PhotoEntity, person: PersonEntity, repo: EchoRepository, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var raw by remember { mutableStateOf("") }
    val parsed = remember(raw) { ShareExporter.parseReply(context, raw) }

    androidx.compose.ui.window.Dialog(onDismissRequest = onDismiss) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(20.dp)
                .background(MaterialTheme.colorScheme.background),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(stringRes(R.string.share_import_title), fontWeight = FontWeight.Bold, fontSize = 18.sp)
            OutlinedTextField(
                value = raw,
                onValueChange = { raw = it },
                label = { Text(stringRes(R.string.share_import_field)) },
                minLines = 5,
                modifier = Modifier.fillMaxWidth(),
            )
            Text(stringRes(R.string.share_import_hint), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)

            val reply = parsed
            if (reply != null) {
                Text(stringRes(R.string.share_import_preview), fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                Text(reply.name, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.primary)
                Text(reply.content, fontSize = 15.sp)
            } else if (raw.isNotBlank()) {
                Text(stringRes(R.string.share_import_invalid), fontSize = 13.sp, color = MaterialTheme.colorScheme.error)
            }

            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                TextButton(onClick = onDismiss) { Text(stringRes(R.string.common_cancel)) }
                TextButton(
                    enabled = parsed != null,
                    onClick = {
                        val reply = parsed ?: return@TextButton
                        scope.launch {
                            repo.insertMessage(
                                personId = person.id,
                                nodeId = null,
                                photoId = photo.id,
                                userName = reply.name,
                                content = reply.content,
                                role = "visitor",
                            )
                            onDismiss()
                        }
                    },
                ) { Text(stringRes(R.string.common_save)) }
            }
        }
    }
}
