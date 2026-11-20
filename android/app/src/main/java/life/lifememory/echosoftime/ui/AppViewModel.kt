package life.lifememory.echosoftime.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import life.lifememory.echosoftime.data.AppLanguage
import life.lifememory.echosoftime.data.EchoRepository
import life.lifememory.echosoftime.data.DemoData

/** 角色模式：编辑（子女建档者）/ 长辈浏览 */
enum class AppMode { EDITOR, READER }

data class AppUiState(
    val language: AppLanguage = AppLanguage.EN,
    val mode: AppMode = AppMode.EDITOR,
    val largeText: Boolean = true,
    val isDeveloper: Boolean = false,
)

class AppViewModel(app: Application) : AndroidViewModel(app) {

    private val prefs = app.getSharedPreferences("app", android.content.Context.MODE_PRIVATE)

    private val _state = MutableStateFlow(
        AppUiState(
            language = AppLanguage.fromCode(prefs.getString("appLanguage", null))
                ?: AppLanguage.deviceDefault(
                    java.util.Locale.getDefault().let { listOf(it.toLanguageTag()) },
                ),
            mode = prefs.getString("appMode", null)
                ?.let { runCatching { AppMode.valueOf(it) }.getOrNull() } ?: AppMode.EDITOR,
            largeText = prefs.getBoolean("largeText", true),
            isDeveloper = prefs.getBoolean("developerMode", false),
        ),
    )
    val state: StateFlow<AppUiState> = _state.asStateFlow()

    fun setLanguage(lang: AppLanguage) {
        prefs.edit().putString("appLanguage", lang.code).apply()
        _state.value = _state.value.copy(language = lang)
    }

    fun setMode(mode: AppMode) {
        prefs.edit().putString("appMode", mode.name).apply()
        _state.value = _state.value.copy(mode = mode)
    }

    fun setLargeText(value: Boolean) {
        prefs.edit().putBoolean("largeText", value).apply()
        _state.value = _state.value.copy(largeText = value)
    }

    fun setDeveloper(value: Boolean) {
        prefs.edit().putBoolean("developerMode", value).apply()
        _state.value = _state.value.copy(isDeveloper = value)
    }

    /** 首次启动播种当前语言的示例档案；只有示例且语言不匹配时替换为当前语言示例 */
    fun seedDemoIfNeeded(repo: EchoRepository) {
        viewModelScope.launch {
            val all = repo.allPeople()
            if (all.isEmpty() && !prefs.getBoolean("demoSeeded", false)) {
                DemoData.insert(repo, getApplication(), _state.value.language)
                prefs.edit().putBoolean("demoSeeded", true).apply()
                return@launch
            }

            // 只有示例、且语言不匹配：换成当前语言的示例（正式档案不受影响）
            val demos = all.filter { it.isDemo }
            if (all.size == 1 && demos.size == 1) {
                val only = demos.first()
                val demoLang = DemoData.demoLanguageOf(only)
                if (demoLang != null && demoLang != _state.value.language) {
                    repo.deletePerson(only.id)
                    DemoData.insert(repo, getApplication(), _state.value.language)
                }
            }
        }
    }
}
