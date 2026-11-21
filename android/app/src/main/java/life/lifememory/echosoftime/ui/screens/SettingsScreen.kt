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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import kotlinx.coroutines.launch
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
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
import life.lifememory.echosoftime.R
import life.lifememory.echosoftime.billing.EntitlementTier
import life.lifememory.echosoftime.billing.PurchaseManager
import life.lifememory.echosoftime.data.AppLanguage
import life.lifememory.echosoftime.data.ArchiveIO
import life.lifememory.echosoftime.data.DemoData
import life.lifememory.echosoftime.data.EchoRepository
import life.lifememory.echosoftime.security.PrivacyLock
import life.lifememory.echosoftime.ui.AppMode
import life.lifememory.echosoftime.ui.AppViewModel
import life.lifememory.echosoftime.ui.components.stringRes

@Composable
fun SettingsScreen(
    vm: AppViewModel,
    repo: EchoRepository,
    purchase: PurchaseManager,
    lock: PrivacyLock,
    onShowPaywall: () -> Unit,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val state by vm.state.collectAsState()
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    val prefs = remember { context.getSharedPreferences("app", android.content.Context.MODE_PRIVATE) }
    var familyName by remember { mutableStateOf(prefs.getString("familyName", "Family") ?: "Family") }
    var langMenuOpen by remember { mutableStateOf(false) }
    var versionTaps by remember { mutableIntStateOf(0) }
    var bgmOn by remember { mutableStateOf(true) }
    var showFaq by remember { mutableStateOf(false) }
    var showPrivacy by remember { mutableStateOf(false) }
    var importResult by remember { mutableStateOf<String?>(null) }
    var showDemoExists by remember { mutableStateOf(false) }

    val importLauncher = androidx.activity.compose.rememberLauncherForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.OpenDocument(),
    ) { uri ->
        uri ?: return@rememberLauncherForActivityResult
        scope.launch {
            val result = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                runCatching {
                    val tmp = java.io.File(context.cacheDir, "import.zip")
                    context.contentResolver.openInputStream(uri)?.use { input ->
                        java.io.FileOutputStream(tmp).use { output -> input.copyTo(output) }
                    }
                    ArchiveIO.importArchive(context, repo, tmp)
                }.getOrNull()
            }
            importResult = when (result) {
                null -> context.getString(R.string.export_failed)
                else -> {
                    val base = context.getString(R.string.settings_import_result) + ": " +
                        "${result.personName} · ${result.nodeCount} ${context.getString(R.string.settings_section_mode)} · " +
                        "${result.photoCount}"
                    if (result.skippedPhotos > 0) {
                        base + "\n" + context.getString(R.string.settings_import_missing, result.skippedPhotos)
                    } else base
                }
            }
        }
    }

    LaunchedEffect(Unit) {
        bgmOn = life.lifememory.echosoftime.audio.BgmManager.isEnabled(context)
    }

    val tier by purchase.tier.collectAsState()
    val tierLabel = when (tier) {
        EntitlementTier.PRO -> stringRes(R.string.settings_premium_tier_pro)
        EntitlementTier.BASIC -> stringRes(R.string.settings_premium_tier_basic)
        EntitlementTier.UNPAID -> stringRes(R.string.settings_premium_tier_unpaid)
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) { Icon(Icons.Filled.ArrowBack, contentDescription = null) }
            Text(stringRes(R.string.settings_title), fontWeight = FontWeight.Bold, fontSize = 20.sp)
        }
        Spacer(Modifier.height(16.dp))

        // 语言
        SettingsSection(stringRes(R.string.settings_section_language)) {
            Box {
                Row(
                    Modifier.fillMaxWidth().clickable { langMenuOpen = true }.padding(vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(stringRes(R.string.settings_language), Modifier.weight(1f))
                    Text(state.language.displayName, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                DropdownMenu(expanded = langMenuOpen, onDismissRequest = { langMenuOpen = false }) {
                    AppLanguage.all.forEach { lang ->
                        DropdownMenuItem(
                            text = { Text(lang.displayName) },
                            onClick = {
                                vm.setLanguage(lang)
                                langMenuOpen = false
                            },
                        )
                    }
                }
            }
            Text(stringRes(R.string.settings_language_note), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }

        // 模式
        SettingsSection(stringRes(R.string.settings_section_mode)) {
            ModeRow(stringRes(R.string.mode_editor), state.mode == AppMode.EDITOR) { vm.setMode(AppMode.EDITOR) }
            ModeRow(stringRes(R.string.mode_reader), state.mode == AppMode.READER) { vm.setMode(AppMode.READER) }
            Text(stringRes(R.string.settings_mode_note), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }

        // 隐私
        SettingsSection(stringRes(R.string.settings_section_privacy)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(stringRes(R.string.settings_requireFaceID), Modifier.weight(1f))
                Switch(checked = lock.enabled, onCheckedChange = { lock.setEnabled(it) })
            }
            OutlinedTextField(
                value = familyName,
                onValueChange = {
                    familyName = it
                    prefs.edit().putString("familyName", it).apply()
                },
                label = { Text(stringRes(R.string.settings_familyName)) },
                modifier = Modifier.fillMaxWidth(),
            )
        }

        // 付费
        SettingsSection(stringRes(R.string.settings_section_premium)) {
            Row {
                Text(stringRes(R.string.settings_premium_status), Modifier.weight(1f))
                Text(tierLabel, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            if (!purchase.isPro) {
                TextButton(onClick = onShowPaywall) {
                    Text(stringRes(R.string.settings_premium_upgrade), color = MaterialTheme.colorScheme.primary)
                }
            }
            TextButton(onClick = { purchase.restore() }) {
                Text(stringRes(R.string.settings_premium_restore), color = MaterialTheme.colorScheme.primary)
            }
        }

        // 显示
        SettingsSection(stringRes(R.string.settings_section_display)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(stringRes(R.string.settings_largeText), Modifier.weight(1f))
                Switch(checked = state.largeText, onCheckedChange = { vm.setLargeText(it) })
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(stringRes(R.string.settings_bgm), Modifier.weight(1f))
                Switch(checked = bgmOn, onCheckedChange = {
                    bgmOn = it
                    life.lifememory.echosoftime.audio.BgmManager.setEnabled(context, it)
                })
            }
        }

        // 开发者：添加示例
        SettingsSection(stringRes(R.string.settings_section_developer)) {
            if (state.isDeveloper) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(stringRes(R.string.settings_developer_on), Modifier.weight(1f))
                    Switch(checked = state.isDeveloper, onCheckedChange = { vm.setDeveloper(it) })
                }
            }
            TextButton(onClick = {
                scope.launch {
                    val exists = repo.allPeople().any { it.isDemo }
                    if (exists) {
                        showDemoExists = true
                    } else {
                        DemoData.insert(repo, context, state.language)
                    }
                }
            }) { Text(stringRes(R.string.settings_demo_add), color = MaterialTheme.colorScheme.primary) }
        }

        // 数据说明
        SettingsSection(stringRes(R.string.settings_section_data)) {
            Row(
                Modifier.fillMaxWidth().clickable { showFaq = true }.padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(stringRes(R.string.faq_entry), Modifier.weight(1f))
            }
            Row(
                Modifier.fillMaxWidth().clickable { showPrivacy = true }.padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(stringRes(R.string.privacy_title), Modifier.weight(1f))
            }
            Row(
                Modifier.fillMaxWidth().clickable {
                    importLauncher.launch(arrayOf("application/zip", "application/octet-stream", "*/*"))
                }.padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(stringRes(R.string.settings_import_archive), Modifier.weight(1f), color = MaterialTheme.colorScheme.primary)
            }
            Text(stringRes(R.string.settings_import_note), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(stringRes(R.string.settings_data_note), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }

        // 版本号：连点 5 次解锁开发者
        Row(
            Modifier.fillMaxWidth().clickable {
                versionTaps += 1
                if (versionTaps >= 5) {
                    vm.setDeveloper(true)
                    versionTaps = 0
                }
            }.padding(vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(stringRes(R.string.settings_version), Modifier.weight(1f))
            val version = remember { runCatching { context.packageManager.getPackageInfo(context.packageName, 0) }.getOrNull() }
            Text(
                "${version?.versionName ?: "1.0"} (${version?.longVersionCode ?: 1})",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        if (!state.isDeveloper) {
            Text(stringRes(R.string.settings_developer_hint), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }

    if (showFaq) {
        FaqScreen(onBack = { showFaq = false })
    }
    if (showPrivacy) {
        PrivacyPolicyScreen(onBack = { showPrivacy = false })
    }
    importResult?.let { msg ->
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { importResult = null },
            confirmButton = { TextButton(onClick = { importResult = null }) { Text(stringRes(R.string.common_save)) } },
            text = { Text(msg) },
        )
    }
    if (showDemoExists) {
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { showDemoExists = false },
            title = { Text(stringRes(R.string.demo_exists_title)) },
            confirmButton = { TextButton(onClick = { showDemoExists = false }) { Text(stringRes(R.string.common_save)) } },
            text = { Text(stringRes(R.string.demo_exists_message)) },
        )
    }
}

@Composable
private fun SettingsSection(title: String, content: @Composable () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(MaterialTheme.colorScheme.surface)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(title, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
        content()
    }
    Spacer(Modifier.height(8.dp))
}

@Composable
private fun ModeRow(title: String, selected: Boolean, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable(onClick = onClick).padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, Modifier.weight(1f), color = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface)
        if (selected) Text("✓", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
    }
}
