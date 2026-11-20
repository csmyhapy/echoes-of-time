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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlinx.coroutines.launch
import life.lifememory.echosoftime.R
import life.lifememory.echosoftime.audio.BgmManager
import life.lifememory.echosoftime.billing.PurchaseManager
import life.lifememory.echosoftime.data.EchoRepository
import life.lifememory.echosoftime.data.PersonEntity
import life.lifememory.echosoftime.ui.AppViewModel
import life.lifememory.echosoftime.ui.components.CoverImage
import life.lifememory.echosoftime.ui.components.stringRes
import life.lifememory.echosoftime.ui.sheets.NodeEditSheet
import life.lifememory.echosoftime.ui.sheets.PersonEditSheet

@Composable
fun LibraryScreen(
    isReader: Boolean,
    repo: EchoRepository,
    purchase: PurchaseManager,
    vm: AppViewModel,
    onOpenPerson: (String) -> Unit,
    onOpenSettings: () -> Unit,
    onShowPaywall: () -> Unit,
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val people by repo.observePeople().collectAsStateWithLifecycle(emptyList())

    var showingNewPerson by remember { mutableStateOf(false) }
    var editingPerson by remember { mutableStateOf<PersonEntity?>(null) }
    var addingChapterFor by remember { mutableStateOf<PersonEntity?>(null) }
    var showLimitAlert by remember { mutableStateOf(false) }
    var deletingPerson by remember { mutableStateOf<PersonEntity?>(null) }
    var bgmOn by remember { mutableStateOf(BgmManager.isEnabled(context)) }
    val scope = androidx.compose.runtime.rememberCoroutineScope()

    LaunchedEffect(Unit) { BgmManager.stop() }

    val realPersons = people.filter { !it.isDemo }
    val demoPersons = people.filter { it.isDemo }

    val taglineKeys = listOf(
        R.string.library_tagline_1, R.string.library_tagline_2, R.string.library_tagline_3,
        R.string.library_tagline_4, R.string.library_tagline_5,
    )
    val taglineIndex = remember { (0 until taglineKeys.size).random() }

    Box(Modifier.fillMaxSize()) {
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(top = 6.dp, bottom = 28.dp),
        ) {
            // 顶部：标题 + 随机标语（设置与背景音乐按钮移至右下角）
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(
                        stringRes(R.string.app_title),
                        fontSize = (if (isReader) 40 else 32).sp,
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        stringRes(taglineKeys[taglineIndex]),
                        fontSize = (if (isReader) 20 else 13).sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            Spacer(Modifier.height(16.dp))

            if (realPersons.isEmpty() && demoPersons.isEmpty()) {
                EmptyCard(isReader) { showingNewPerson = true }
            } else {
                realPersons.forEach { person ->
                    ArchiveCard(
                        person = person,
                        large = isReader,
                        isReader = isReader,
                        onClick = { onOpenPerson(person.id) },
                        onEdit = { editingPerson = person },
                        onDelete = { deletingPerson = person },
                    )
                    Spacer(Modifier.height(12.dp))
                }

                when {
                    realPersons.isEmpty() -> CreatePrompt(isReader) { showingNewPerson = true }
                    realPersons.size == 1 -> ActionButtons(
                        person = realPersons.first(),
                        isReader = isReader,
                        purchase = purchase,
                        onAddChapter = { addingChapterFor = realPersons.first() },
                        onEditArchive = { editingPerson = realPersons.first() },
                        onCreatePerson = {
                            if (vm.state.value.isDeveloper) showingNewPerson = true
                            else showLimitAlert = true
                        },
                        onShowPaywall = onShowPaywall,
                    )
                    vm.state.value.isDeveloper -> CapsuleButton(
                        title = stringRes(R.string.library_create_person),
                        icon = Icons.Filled.PersonAdd,
                        role = CapsuleRole.Secondary,
                        onClick = { showingNewPerson = true },
                    )
                }

                if (demoPersons.isNotEmpty()) {
                    Spacer(Modifier.height(16.dp))
                    DemoSection(demoPersons, onOpenPerson)
                }
            }
        }

        // 右下角浮动：背景音乐开关 + 设置
        Row(
            Modifier
                .align(Alignment.BottomEnd)
                .padding(20.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            CircleFab(
                active = bgmOn,
                icon = Icons.Filled.MusicNote,
                onClick = {
                    bgmOn = !bgmOn
                    BgmManager.setEnabled(context, bgmOn)
                },
            )
            CircleFab(active = true, icon = Icons.Filled.Settings, onClick = onOpenSettings)
        }
    }

    if (showingNewPerson) {
        PersonEditSheet(person = null, repo = repo, onDismiss = { showingNewPerson = false })
    }
    editingPerson?.let { p ->
        PersonEditSheet(person = p, repo = repo, onDismiss = { editingPerson = null })
    }
    addingChapterFor?.let { p ->
        NodeEditSheet(person = p, node = null, repo = repo, onDismiss = { addingChapterFor = null })
    }

    if (showLimitAlert) {
        AlertDialog(
            onDismissRequest = { showLimitAlert = false },
            title = { Text(stringRes(R.string.one_archive_limit_title)) },
            text = { Text(stringRes(R.string.one_archive_limit_message)) },
            confirmButton = { TextButton(onClick = { showLimitAlert = false }) { Text(stringRes(R.string.common_save)) } },
        )
    }
    deletingPerson?.let { p ->
        AlertDialog(
            onDismissRequest = { deletingPerson = null },
            title = { Text(stringRes(R.string.common_delete)) },
            text = { Text("${p.name}？") },
            confirmButton = {
                TextButton(onClick = {
                    scope.launch { repo.deletePerson(p.id) }
                    deletingPerson = null
                }) { Text(stringRes(R.string.common_delete), color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { deletingPerson = null }) { Text(stringRes(R.string.common_cancel)) } },
        )
    }
}

@Composable
private fun CircleFab(active: Boolean, icon: androidx.compose.ui.graphics.vector.ImageVector, onClick: () -> Unit) {
    Box(
        Modifier
            .size(52.dp)
            .clip(CircleShape)
            .background(
                if (active) MaterialTheme.colorScheme.primary
                else MaterialTheme.colorScheme.surfaceVariant,
            )
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = if (active) MaterialTheme.colorScheme.onPrimary
            else MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

enum class CapsuleRole { Primary, Secondary, Ghost }

@Composable
fun CapsuleButton(
    title: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    role: CapsuleRole,
    onClick: () -> Unit,
) {
    val bg = when (role) {
        CapsuleRole.Primary -> MaterialTheme.colorScheme.primary
        CapsuleRole.Secondary -> MaterialTheme.colorScheme.primary.copy(alpha = 0.13f)
        CapsuleRole.Ghost -> MaterialTheme.colorScheme.surfaceVariant
    }
    val fg = when (role) {
        CapsuleRole.Primary -> androidx.compose.ui.graphics.Color.White
        CapsuleRole.Secondary -> MaterialTheme.colorScheme.primary
        CapsuleRole.Ghost -> MaterialTheme.colorScheme.onSurfaceVariant
    }
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(28.dp))
            .background(bg)
            .clickable(onClick = onClick)
            .padding(vertical = 15.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, contentDescription = null, tint = fg, modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(8.dp))
        Text(title, color = fg, fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
    }
}

@Composable
private fun EmptyCard(isReader: Boolean, onCreate: () -> Unit) {
    Card(
        Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(18.dp),
    ) {
        Column(
            Modifier.padding(24.dp).fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Icon(
                Icons.Filled.PersonAdd,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary.copy(alpha = 0.75f),
                modifier = Modifier.size(64.dp),
            )
            Text(stringRes(R.string.library_empty_title), fontWeight = FontWeight.Bold)
            Text(
                stringRes(R.string.library_empty_desc),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            )
            if (!isReader) {
                CapsuleButton(
                    stringRes(R.string.library_create_person),
                    Icons.Filled.PersonAdd,
                    CapsuleRole.Primary,
                    onCreate,
                )
            }
        }
    }
}

@Composable
private fun CreatePrompt(isReader: Boolean, onCreate: () -> Unit) {
    Card(
        Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(18.dp),
    ) {
        Column(
            Modifier.padding(20.dp).fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Icon(
                Icons.Filled.PersonAdd,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary.copy(alpha = 0.8f),
                modifier = Modifier.size(44.dp),
            )
            Text(stringRes(R.string.library_create_first), fontWeight = FontWeight.Bold)
            Text(
                stringRes(R.string.library_create_first_desc),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            )
            if (!isReader) {
                CapsuleButton(
                    stringRes(R.string.library_create_person),
                    Icons.Filled.PersonAdd,
                    CapsuleRole.Primary,
                    onCreate,
                )
            }
        }
    }
}

@Composable
private fun ActionButtons(
    person: PersonEntity,
    isReader: Boolean,
    purchase: PurchaseManager,
    onAddChapter: () -> Unit,
    onEditArchive: () -> Unit,
    onCreatePerson: () -> Unit,
    onShowPaywall: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        CapsuleButton(
            title = stringRes(R.string.library_action_addChapter),
            icon = Icons.Filled.Add,
            role = CapsuleRole.Primary,
        ) {
            if (purchase.canAddNode(/* count */ 0)) onAddChapter() else onShowPaywall()
        }
        CapsuleButton(
            title = stringRes(R.string.library_action_editArchive),
            icon = Icons.Filled.SwapHoriz,
            role = CapsuleRole.Secondary,
            onClick = onEditArchive,
        )
        CapsuleButton(
            title = stringRes(R.string.library_create_person),
            icon = Icons.Filled.PersonAdd,
            role = CapsuleRole.Ghost,
            onClick = onCreatePerson,
        )
    }
}

@Composable
private fun ArchiveCard(
    person: PersonEntity,
    large: Boolean,
    isReader: Boolean,
    onClick: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
) {
    var menuOpen by remember { mutableStateOf(false) }
    Card(
        Modifier.fillMaxWidth().clickable(onClick = onClick),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(18.dp),
    ) {
        Column {
            CoverImage(
                fileName = person.coverImageFileName,
                personId = person.id,
                iconSize = if (large) 56 else 40,
                modifier = Modifier
                    .fillMaxWidth()
                    .height((if (large) 240 else 190).dp),
            )
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(
                            person.name,
                            fontSize = (if (large) 32 else 24).sp,
                            fontWeight = FontWeight.Bold,
                        )
                        if (person.birthYear.isNotEmpty()) {
                            Text(
                                person.birthYear,
                                fontSize = (if (large) 22 else 14).sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                    if (!isReader) {
                        Box {
                            IconButton(onClick = { menuOpen = true }) {
                                Icon(Icons.Filled.MoreVert, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                                DropdownMenuItem(
                                    text = { Text(stringRes(R.string.common_edit)) },
                                    onClick = { menuOpen = false; onEdit() },
                                )
                                DropdownMenuItem(
                                    text = { Text(stringRes(R.string.common_delete), color = MaterialTheme.colorScheme.error) },
                                    onClick = { menuOpen = false; onDelete() },
                                )
                            }
                        }
                    } else {
                        Icon(
                            Icons.Filled.SwapHoriz,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                Text(
                    "${person.summary}",
                    fontSize = (if (large) 20 else 13).sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                )
            }
        }
    }
}

@Composable
private fun DemoSection(people: List<PersonEntity>, onOpen: (String) -> Unit) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            stringRes(R.string.demo_section_title),
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.weight(1f))
        Text(
            stringRes(R.string.demo_section_note),
            fontSize = 11.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
        )
    }
    Spacer(Modifier.height(9.dp))
    people.forEach { p ->
        DemoRow(p, onClick = { onOpen(p.id) })
        Spacer(Modifier.height(8.dp))
    }
}

@Composable
private fun DemoRow(person: PersonEntity, onClick: () -> Unit) {
    Card(
        Modifier.fillMaxWidth().clickable(onClick = onClick),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(14.dp),
    ) {
        Row(
            Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            CoverImage(
                fileName = person.coverImageFileName,
                personId = person.id,
                iconSize = 22,
                modifier = Modifier.size(50.dp),
            )
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(person.name, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                    Spacer(Modifier.width(6.dp))
                    Text(
                        stringRes(R.string.demo_badge),
                        fontSize = 9.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier
                            .clip(RoundedCornerShape(8.dp))
                            .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.14f))
                            .padding(horizontal = 6.dp, vertical = 2.dp),
                    )
                }
                if (person.birthYear.isNotEmpty()) {
                    Text(person.birthYear, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Text(
                    stringRes(R.string.demo_note),
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                )
            }
        }
    }
}
