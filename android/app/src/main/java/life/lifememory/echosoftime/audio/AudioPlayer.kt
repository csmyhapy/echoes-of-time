package life.lifememory.echosoftime.audio

import android.content.Context
import android.media.MediaPlayer
import android.net.Uri

/**
 * 本地音频播放：播放 / 暂停 / 停止 App 沙盒内的旁白音频（对应 iOS AudioPlayer）。
 */
class AudioPlayer(private val context: Context) {

    private var player: MediaPlayer? = null
    var currentUri: Uri? = null
        private set
    var duration: Double = 0.0
        private set

    val isPlayingNow: Boolean get() = player?.isPlaying == true
    val currentTime: Double get() = player?.currentPosition?.div(1000.0) ?: 0.0
    val progress: Double
        get() = if (duration > 0) (currentTime / duration).coerceIn(0.0, 1.0) else 0.0

    /** 同一首则切换播放/暂停；不同则从头播放 */
    fun toggle(uri: Uri) {
        if (currentUri == uri && player != null) {
            val p = player ?: return
            if (p.isPlaying) p.pause() else p.start()
            return
        }
        play(uri)
    }

    fun play(uri: Uri) {
        stop()
        try {
            val p = MediaPlayer()
            p.setDataSource(context, uri)
            p.prepare()
            p.start()
            player = p
            currentUri = uri
            duration = p.duration / 1000.0
        } catch (_: Exception) {
            player = null
            currentUri = null
            duration = 0.0
        }
    }

    /** 读取任意音频文件的时长（秒） */
    fun durationOf(uri: Uri): Double = try {
        val mp = MediaPlayer()
        mp.setDataSource(context, uri)
        mp.prepare()
        val d = mp.duration / 1000.0
        mp.release()
        d
    } catch (_: Exception) {
        0.0
    }

    fun stop() {
        player?.stop()
        player?.release()
        player = null
        currentUri = null
        duration = 0.0
    }

    companion object {
        /** 秒数格式化为 0:42 / 1:05 */
        fun timeText(seconds: Double): String {
            val total = Math.round(seconds).toInt()
            return "%d:%02d".format(total / 60, total % 60)
        }
    }
}
