package life.lifememory.echosoftime.ui.nav

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import life.lifememory.echosoftime.billing.PurchaseManager
import life.lifememory.echosoftime.data.AppLanguage
import life.lifememory.echosoftime.data.EchoRepository
import life.lifememory.echosoftime.security.PrivacyLock
import life.lifememory.echosoftime.ui.AppMode
import life.lifememory.echosoftime.ui.AppViewModel
import life.lifememory.echosoftime.ui.screens.LibraryScreen
import life.lifememory.echosoftime.ui.screens.PaywallScreen
import life.lifememory.echosoftime.ui.screens.PersonDetailScreen
import life.lifememory.echosoftime.ui.screens.PhotoLibraryScreen
import life.lifememory.echosoftime.ui.screens.SettingsScreen
import life.lifememory.echosoftime.ui.screens.NodeDetailScreen
import life.lifememory.echosoftime.ui.lock.LockScreen
import java.util.Locale

@Composable
fun AppRoot(
    vm: AppViewModel,
    purchase: PurchaseManager,
    repo: EchoRepository,
    lock: PrivacyLock,
    onUnlock: () -> Unit,
) {
    val state by vm.state.collectAsState()
    val nav = rememberNavController()

    // 按所选语言包装 Context，使 stringResource 立即跟随切换
    val baseContext = LocalContext.current
    val localizedContext = remember(baseContext, state.language) {
        val locale = when (state.language) {
            AppLanguage.ZH_HANS -> Locale("zh")
            else -> Locale.forLanguageTag(state.language.code)
        }
        val cfg = android.content.res.Configuration(baseContext.resources.configuration)
        cfg.setLocale(locale)
        baseContext.createConfigurationContext(cfg)
    }

    CompositionLocalProvider(LocalContext provides localizedContext) {
    androidx.compose.foundation.layout.Box(
        Modifier
            .fillMaxSize()
            .systemBarsPadding(),
    ) {
    NavHost(navController = nav, startDestination = "library") {
        composable("library") {
            LibraryScreen(
                isReader = state.mode == AppMode.READER,
                repo = repo,
                purchase = purchase,
                vm = vm,
                onOpenPerson = { nav.navigate("person/$it") },
                onOpenSettings = { nav.navigate("settings") },
                onShowPaywall = { nav.navigate("paywall") },
            )
        }
        composable("person/{id}") { entry ->
            val id = entry.arguments?.getString("id") ?: return@composable
            PersonDetailScreen(
                personId = id,
                isReader = state.mode == AppMode.READER,
                repo = repo,
                purchase = purchase,
                onOpenNode = { nav.navigate("node/$it") },
                onOpenPhotos = { nav.navigate("photos/$id") },
                onShowPaywall = { nav.navigate("paywall") },
                onBack = { nav.popBackStack() },
            )
        }
        composable("node/{id}") { entry ->
            val id = entry.arguments?.getString("id") ?: return@composable
            NodeDetailScreen(
                nodeId = id,
                isReader = state.mode == AppMode.READER,
                repo = repo,
                purchase = purchase,
                onShowPaywall = { nav.navigate("paywall") },
                onBack = { nav.popBackStack() },
            )
        }
        composable("photos/{personId}") { entry ->
            val id = entry.arguments?.getString("personId") ?: return@composable
            PhotoLibraryScreen(
                personId = id,
                isReader = state.mode == AppMode.READER,
                repo = repo,
                purchase = purchase,
                onShowPaywall = { nav.navigate("paywall") },
                onBack = { nav.popBackStack() },
            )
        }
        composable("settings") {
            SettingsScreen(vm = vm, repo = repo, purchase = purchase, lock = lock, onShowPaywall = { nav.navigate("paywall") }, onBack = { nav.popBackStack() })
        }
        composable("paywall") {
            PaywallScreen(purchase = purchase, onBack = { nav.popBackStack() })
        }
    }
    }
    }

    val locked by lock.isLocked.collectAsState()
    if (locked) {
        LockScreen(
            lock = lock,
            onUnlock = onUnlock,
            errorMessage = lock.errorMessage.collectAsState().value,
        )
    }
}
