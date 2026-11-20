package life.lifememory.echosoftime.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** App 内隐私政策（对应 iOS PrivacyPolicyView，中英按所选语言） */
@Composable
fun PrivacyPolicyScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val isZh = context.resources.configuration.locales[0].language.startsWith("zh")
    val summary = if (isZh)
        "岁月回声把你的内容完全保存在这台设备上。你录入的照片、录音、文字和留言不会被上传、收集或分析；购买由应用商店单独处理。"
    else
        "Echoes of Time keeps your content entirely on this device. The photos, recordings, text and messages you add are never uploaded, collected or analysed. Purchases are handled separately by the app store."

    val sections = if (isZh) zhSections else enSections

    Column(
        Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 22.dp, vertical = 20.dp),
    ) {
        Row {
            IconButton(onClick = onBack) { Icon(Icons.Filled.ArrowBack, contentDescription = null) }
            Column {
                Text(if (isZh) "隐私政策" else "Privacy Policy", fontWeight = FontWeight.Bold, fontSize = 26.sp)
                Text(
                    if (isZh) "最后更新：2026 年 11 月" else "Last updated: November 2026",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        Spacer(Modifier.height(16.dp))
        Text(
            summary,
            fontSize = 15.sp,
            lineHeight = 22.sp,
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.10f))
                .padding(14.dp),
        )
        Spacer(Modifier.height(20.dp))
        sections.forEach { (heading, body) ->
            Column(verticalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(bottom = 18.dp)) {
                Text(heading, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                Text(body, fontSize = 14.sp, lineHeight = 20.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        Text(
            if (isZh) "如对本政策有疑问，请联系：support@lifememory.life"
            else "Questions about this policy? Contact us at support@lifememory.life",
            fontSize = 12.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

private data class Section(val heading: String, val body: String)

private val enSections = listOf(
    Section(
        "What we collect",
        "Nothing. There is no account, no sign-in, no server and no analytics SDK. The app does not contain any third-party tracking, advertising or crash-reporting frameworks. It never sees your payment details.",
    ),
    Section(
        "Where your content is stored",
        "All archives, images, audio recordings and messages are written to the app's private storage area on this device. The app's data folder is not shared with other apps unless you explicitly export something.",
    ),
    Section(
        "Device backups",
        "If you have a device or computer backup enabled, the system may include the app's data in that backup. Those backups are handled by the platform under its terms — we never receive a copy.",
    ),
    Section(
        "Permissions we ask for",
        "Photos: to pick images from your library. Microphone: only while you record a voice note. Biometric unlock: only to unlock the app when you enable the privacy lock. All of this happens on the device; nothing is sent anywhere.",
    ),
    Section(
        "Sharing and export",
        "Exporting a PDF or an archive package is always started by you. When you use the share sheet, the exported file leaves the app and is handled by the destination you choose.",
    ),
    Section(
        "In-app purchases",
        "Purchases are processed by the app store. The app never receives your card number or payment details; it only checks your current entitlements on-device and uses restore purchases to verify them.",
    ),
    Section(
        "No advertising, no profiling",
        "We do not build profiles, do not track you across apps or websites, and do not sell or share data with anyone.",
    ),
    Section(
        "Children",
        "The app is intended for adults keeping family memories. It is not directed at children under 13 and collects no personal information from anyone.",
    ),
    Section(
        "Deleting your data",
        "Deleting an archive inside the app removes its photos and audio immediately. Deleting the app removes all of its data from the device. There is no copy on our side, because we never had one.",
    ),
    Section(
        "Changes",
        "If this policy changes, the updated version will appear in the app and the date above will be revised.",
    ),
)

private val zhSections = listOf(
    Section("我们收集什么", "什么都不收集。App 没有账号、没有登录、没有服务器，也没有任何统计 SDK。App 内不含第三方追踪、广告或崩溃上报框架；支付信息由应用商店处理，App 不接触。"),
    Section("内容存在哪里", "所有档案、图片、录音和留言，都写入这台设备上 App 自己的私有存储空间。除非你主动导出，否则这些文件不会与其他 App 共享。"),
    Section("设备备份", "如果你为这台设备开启了系统备份或电脑备份，系统可能会把 App 的数据一并包含在备份中。这类备份由平台按其条款处理，我们不会收到副本。"),
    Section("我们申请的权限", "相册：用于从图库中选择照片。麦克风：仅在你录制语音旁白时使用。生物识别解锁：仅在你开启隐私锁时用于解锁。以上处理全部在设备本地完成，不会发往任何地方。"),
    Section("分享与导出", "导出 PDF 或档案包始终由你主动发起。使用系统分享面板时，导出文件会离开 App，交由你选择的目标处理。"),
    Section("内购与支付", "购买由应用商店完成，App 不会获取你的卡号或支付信息。App 只在本机查询当前权益，并通过“恢复购买”校验。我们不存储交易记录，也不处理退款。"),
    Section("无广告、无画像", "我们不做用户画像，不跨 App 或网站追踪你，也不向任何人出售或共享数据。"),
    Section("儿童", "本 App 面向为家人保存记忆的成年人，不面向 13 岁以下儿童，也不向任何人收集个人信息。"),
    Section("删除你的数据", "在 App 内删除档案会立即删除对应的照片与音频；删除 App 会从设备上清除它的全部数据。我们这边没有副本，因为我们从未持有。"),
    Section("政策变更", "本政策如有变更，更新后的版本会显示在 App 内，并修订上方的日期。"),
)
