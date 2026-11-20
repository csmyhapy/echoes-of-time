package life.lifememory.echosoftime.ui.sheets

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Stop
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import life.lifememory.echosoftime.R
import life.lifememory.echosoftime.audio.AudioRecorder
import life.lifememory.echosoftime.ui.components.stringRes

/** 录音面板（对应 iOS RecorderSheet）：大圆按钮开始/停止，0.3s 刷新计时 */
@Composable
fun RecorderSheet(
    personId: String,
    titleKey: Int,
    onDismiss: () -> Unit,
    onSave: (fileName: String, duration: Int) -> Unit,
) {
    val context = LocalContext.current
    val recorder = remember { AudioRecorder(context) }
    var elapsed by remember { mutableStateOf(0.0) }
    var denied by remember { mutableStateOf(false) }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) recorder.start(personId) else denied = true
    }

    LaunchedEffect(recorder.isRecording) {
        while (recorder.isRecording) {
            elapsed = recorder.elapsed
            delay(300)
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
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(stringRes(titleKey), fontSize = 22.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(24.dp))
            Text(
                formatMmSs(elapsed),
                fontSize = 40.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary,
            )
            Spacer(Modifier.height(32.dp))

            androidx.compose.foundation.layout.Box(
                Modifier
                    .size(130.dp)
                    .clip(CircleShape)
                    .background(if (recorder.isRecording) Color(0xFFD32F2F) else MaterialTheme.colorScheme.primary)
                    .clickable(
                        indication = null,
                        interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() },
                    ) {
                        if (recorder.isRecording) {
                            recorder.stop()
                        } else {
                            if (!recorder.hasPermission()) {
                                permissionLauncher.launch(android.Manifest.permission.RECORD_AUDIO)
                            } else {
                                recorder.start(personId)
                            }
                        }
                    },
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    if (recorder.isRecording) Icons.Filled.Stop else Icons.Filled.Mic,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(48.dp),
                )
            }

            if (denied) {
                Spacer(Modifier.height(16.dp))
                Text(
                    stringRes(R.string.recorder_permission_denied),
                    color = MaterialTheme.colorScheme.error,
                    fontSize = 13.sp,
                )
            }

            Spacer(Modifier.height(32.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                TextButton(onClick = {
                    recorder.cancel(personId)
                    onDismiss()
                }) { Text(stringRes(R.string.common_cancel)) }
                TextButton(
                    onClick = {
                        recorder.lastFileName?.let { name ->
                            onSave(name, recorder.lastDuration.toInt())
                        }
                        onDismiss()
                    },
                    enabled = !recorder.isRecording && recorder.lastDuration > 0.5,
                ) { Text(stringRes(R.string.common_save)) }
            }
        }
    }
}

private fun formatMmSs(seconds: Double): String {
    val total = Math.round(seconds).toInt()
    return "%d:%02d".format(total / 60, total % 60)
}
