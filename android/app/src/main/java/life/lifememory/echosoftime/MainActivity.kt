package life.lifememory.echosoftime

import android.os.Bundle
import androidx.activity.compose.LocalActivityResultRegistryOwner
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.ActivityResultRegistryOwner
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.compose.runtime.CompositionLocalProvider
import life.lifememory.echosoftime.audio.BgmManager
import life.lifememory.echosoftime.security.PrivacyLock
import life.lifememory.echosoftime.ui.AppViewModel
import life.lifememory.echosoftime.ui.nav.AppRoot
import life.lifememory.echosoftime.ui.theme.EchoesOfTimeTheme

class MainActivity : FragmentActivity() {

    private lateinit var lock: PrivacyLock

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val app = application as EchoApp
        lock = PrivacyLock(this)

        // FragmentActivity 未实现 ActivityResultRegistryOwner，手动提供注册表，
        // 否则 rememberLauncherForActivityResult 在各页面崩溃
        val registryOwner = object : ActivityResultRegistryOwner {
            override val activityResultRegistry = this@MainActivity.activityResultRegistry
        }

        setContent {
            EchoesOfTimeTheme {
                CompositionLocalProvider(LocalActivityResultRegistryOwner provides registryOwner) {
                    val vm: AppViewModel = viewModel()

                    androidx.compose.runtime.LaunchedEffect(Unit) {
                        vm.seedDemoIfNeeded(app.repo)
                    }
                    androidx.compose.runtime.DisposableEffect(Unit) {
                        onDispose { BgmManager.stop() }
                    }

                    AppRoot(
                        vm = vm,
                        purchase = app.purchase,
                        repo = app.repo,
                        lock = lock,
                        onUnlock = {
                            lock.authenticate(
                                this@MainActivity,
                                getString(R.string.lock_title),
                                getString(R.string.lock_reason),
                                getString(R.string.lock_cancel),
                            )
                        },
                    )
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        lock.lockIfNeeded()
    }
}
