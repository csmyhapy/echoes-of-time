package life.lifememory.echosoftime.security

import android.content.Context
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * 设备锁（指纹/面容/锁屏密码）隐私锁（对应 iOS PrivacyLock）。
 * 开启后 App 冷启动或从后台返回时要求验证；设备没有设置密码的直接放行，避免把用户锁在门外。
 */
class PrivacyLock(private val context: Context) {

    private val prefs = context.getSharedPreferences("app", Context.MODE_PRIVATE)

    private val _isLocked = MutableStateFlow(false)
    val isLocked: StateFlow<Boolean> = _isLocked
    val errorMessage = MutableStateFlow<String?>(null)
    private var lastUnlockAt: Long = 0

    val enabled: Boolean get() = prefs.getBoolean("requireFaceID", false)

    fun setEnabled(value: Boolean) = prefs.edit().putBoolean("requireFaceID", value).apply()

    fun lockIfNeeded() {
        if (!enabled) {
            _isLocked.value = false
            return
        }
        // 30 秒内刚解锁过就不重复弹窗（避免回前台频繁验证）
        if (System.currentTimeMillis() - lastUnlockAt < 30_000) return
        _isLocked.value = true
    }

    fun authenticate(activity: FragmentActivity, title: String, reason: String, cancel: String) {
        val manager = BiometricManager.from(context)
        val canAuth = manager.canAuthenticate(
            BiometricManager.Authenticators.BIOMETRIC_STRONG or
                BiometricManager.Authenticators.DEVICE_CREDENTIAL,
        )
        if (canAuth != BiometricManager.BIOMETRIC_SUCCESS) {
            // 设备没有设置面容/密码：不锁，直接进入
            errorMessage.value = null
            _isLocked.value = false
            lastUnlockAt = System.currentTimeMillis()
            return
        }

        val callback = object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                _isLocked.value = false
                errorMessage.value = null
                lastUnlockAt = System.currentTimeMillis()
            }

            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                _isLocked.value = true
                errorMessage.value = errString.toString()
            }

            override fun onAuthenticationFailed() {
                // 单次指纹不匹配，保持锁定等待重试
            }
        }

        val prompt = BiometricPrompt(activity, ContextCompat.getMainExecutor(context), callback)
        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .setDescription(reason)
            .setNegativeButtonText(cancel)
            .setAllowedAuthenticators(
                BiometricManager.Authenticators.BIOMETRIC_STRONG or
                    BiometricManager.Authenticators.DEVICE_CREDENTIAL,
            )
            .build()
        prompt.authenticate(info)
    }
}
