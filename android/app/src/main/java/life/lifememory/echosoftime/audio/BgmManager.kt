package life.lifememory.echosoftime.audio

import android.content.Context
import android.media.MediaPlayer
import android.net.Uri
import androidx.core.content.edit
import life.lifememory.echosoftime.data.MediaStore

/**
 * 背景音乐：进入人物页循环播放，离开页面停止（对应 iOS BGMManager）。
 * 音乐优先取本地媒体目录（用户自定义），否则回落到 assets 内的示例 BGM。
 */
object BgmManager {

    private var player: MediaPlayer? = null
    private var currentKey: String? = null

    /** 0.18 的 60%，约为原始 0.30 的 36%，只作氛围不打扰 */
    private const val DEFAULT_VOLUME = 0.108f

    fun prefs(context: Context) =
        context.getSharedPreferences("app", Context.MODE_PRIVATE)

    fun isEnabled(context: Context): Boolean = prefs(context).getBoolean("bgmEnabled", true)

    fun setEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit { putBoolean("bgmEnabled", enabled) }
        if (!enabled) stop()
    }

    fun play(context: Context, fileName: String?, personId: String) {
        if (!isEnabled(context)) {
            stop(); return
        }
        if (fileName.isNullOrEmpty()) {
            stop(); return
        }

        val key = "$personId/$fileName"
        if (currentKey == key && player?.isPlaying == true) return
        stop()

        try {
            val p = MediaPlayer()
            val media = MediaStore.url(context, fileName, personId)
            if (media.exists()) {
                p.setDataSource(context, Uri.fromFile(media))
            } else {
                val ext = fileName.substringAfterLast('.', "m4a")
                val base = fileName.substringBeforeLast('.')
                val afd = context.assets.openFd("demo/bgm/$base.$ext")
                p.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
            }
            p.isLooping = true
            p.setVolume(DEFAULT_VOLUME, DEFAULT_VOLUME)
            p.prepare()
            p.start()
            player = p
            currentKey = key
        } catch (_: Exception) {
            player = null
            currentKey = null
        }
    }

    fun stop() {
        player?.stop()
        player?.release()
        player = null
        currentKey = null
    }
}
