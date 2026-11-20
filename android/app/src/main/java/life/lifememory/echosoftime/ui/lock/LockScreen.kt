package life.lifememory.echosoftime.ui.lock

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.fragment.app.FragmentActivity
import life.lifememory.echosoftime.R
import life.lifememory.echosoftime.security.PrivacyLock
import life.lifememory.echosoftime.ui.components.stringRes

/** 隐私锁屏遮罩：出现即拉起生物识别/设备密码验证 */
@Composable
fun LockScreen(lock: PrivacyLock, onUnlock: () -> Unit, errorMessage: String?) {
    val activity = LocalContext.current as FragmentActivity
    val title = stringRes(R.string.lock_title)
    val reason = stringRes(R.string.lock_reason)
    val cancel = stringRes(R.string.lock_cancel)

    LaunchedEffect(Unit) {
        lock.authenticate(activity, title = title, reason = reason, cancel = cancel)
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            Icons.Filled.Lock,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(56.dp),
        )
        Spacer(Modifier.height(16.dp))
        Text(stringRes(R.string.lock_title), fontSize = 22.sp, fontWeight = FontWeight.Bold)
        errorMessage?.let {
            Spacer(Modifier.height(8.dp))
            Text(it, color = MaterialTheme.colorScheme.error, fontSize = 13.sp)
        }
    }
}
