package life.lifememory.echosoftime.audio

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaRecorder
import androidx.core.content.ContextCompat
import life.lifememory.echosoftime.data.MediaStore
import java.util.UUID

/**
 * 本地录音：MediaRecorder 输出 m4a(AAC)，用于照片/章节/人物旁白（对应 iOS AudioRecorder）。
 * 文件写入 Media/<personID>/voice_xxxx.m4a。
 */
class AudioRecorder(private val context: Context) {

    private var recorder: MediaRecorder? = null

    var isRecording = false
        private set
    private var startMs: Long = 0
    var errorMessage: String? = null
        private set

    var lastFileName: String? = null
        private set
    var lastDuration: Double = 0.0
        private set

    /** 已录时长（秒），供界面计时显示 */
    val elapsed: Double
        get() = if (isRecording) (System.currentTimeMillis() - startMs) / 1000.0 else lastDuration

    fun hasPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    fun start(personId: String): Boolean {
        if (isRecording) return true
        if (!hasPermission()) {
            errorMessage = "recorder.permission.denied"
            return false
        }
        return try {
            val fileName = "voice_${UUID.randomUUID()}.m4a"
            val dest = MediaStore.url(context, fileName, personId)
            val r = MediaRecorder(context)
            r.setAudioSource(MediaRecorder.AudioSource.MIC)
            r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            r.setAudioSamplingRate(44100)
            r.setAudioChannels(1)
            r.setAudioEncodingBitRate(96000)
            r.setOutputFile(dest.absolutePath)
            r.prepare()
            r.start()

            recorder = r
            lastFileName = fileName
            lastDuration = 0.0
            startMs = System.currentTimeMillis()
            isRecording = true
            errorMessage = null
            true
        } catch (e: Exception) {
            errorMessage = e.localizedMessage
            false
        }
    }

    fun stop() {
        lastDuration = (System.currentTimeMillis() - startMs) / 1000.0
        try {
            recorder?.stop()
        } catch (_: Exception) {
            // 录音过短时 stop 会抛错，按失败处理
        }
        recorder?.release()
        recorder = null
        isRecording = false
    }

    /** 取消并删除已录文件 */
    fun cancel(personId: String) {
        if (isRecording) stop()
        lastFileName?.let { MediaStore.deleteFile(context, it, personId) }
        lastFileName = null
        lastDuration = 0.0
        startMs = 0
    }
}
