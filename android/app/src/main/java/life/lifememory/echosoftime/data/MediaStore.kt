package life.lifememory.echosoftime.data

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

/**
 * 本地媒体存储：图片、音频全部落在 filesDir/Media/<personID>/。
 * 数据库只保存文件名，避免二进制入库（与 iOS MediaStore 对齐）。
 */
object MediaStore {

    fun root(context: Context): File = File(context.filesDir, "Media").apply { mkdirs() }

    fun folder(context: Context, personID: String): File =
        File(root(context), personID).apply { mkdirs() }

    fun url(context: Context, fileName: String, personID: String): File =
        File(folder(context, personID), fileName)

    /** 保存图片（自动压缩：长边 <= 1600，JPEG 0.8），返回文件名 */
    fun saveImage(context: Context, bitmap: Bitmap, personID: String): String? {
        val longSide = maxOf(bitmap.width, bitmap.height)
        val target = if (longSide <= 1600) bitmap else {
            val scale = 1600f / longSide
            Bitmap.createScaledBitmap(
                bitmap,
                (bitmap.width * scale).toInt().coerceAtLeast(1),
                (bitmap.height * scale).toInt().coerceAtLeast(1),
                true,
            )
        }
        val name = UUID.randomUUID().toString() + ".jpg"
        val dest = url(context, name, personID)
        return try {
            FileOutputStream(dest).use { out ->
                target.compress(Bitmap.CompressFormat.JPEG, 80, out)
            }
            if (target != bitmap) target.recycle()
            name
        } catch (_: Exception) {
            null
        }
    }

    /** 从相册 URI 读入并压缩保存，返回文件名 */
    fun saveImageFromUri(context: Context, uri: Uri, personID: String): String? {
        return try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            context.contentResolver.openInputStream(uri)?.use { input ->
                BitmapFactory.decodeStream(input, null, bounds)
            }
            context.contentResolver.openInputStream(uri)?.use { input ->
                val sample = calculateSample(bounds.outWidth, bounds.outHeight)
                val opts = BitmapFactory.Options().apply { inSampleSize = sample }
                val bitmap = BitmapFactory.decodeStream(input, null, opts) ?: return null
                saveImage(context, bitmap, personID)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun calculateSample(width: Int, height: Int): Int {
        var sample = 1
        var w = width
        var h = height
        while (w / 2 >= 1600 || h / 2 >= 1600) {
            w /= 2; h /= 2; sample *= 2
        }
        return sample
    }

    /** 把外部音频文件拷进档案目录（背景音乐导入用），返回文件名 */
    fun saveAudioFile(context: Context, source: Uri, personID: String, ext: String = "m4a"): String? {
        val name = UUID.randomUUID().toString() + "." + ext
        val dest = url(context, name, personID)
        return try {
            context.contentResolver.openInputStream(source)?.use { input ->
                FileOutputStream(dest).use { output -> input.copyTo(output) }
            }
            name
        } catch (_: Exception) {
            null
        }
    }

    fun loadImage(context: Context, fileName: String?, personID: String): Bitmap? {
        if (fileName.isNullOrEmpty()) return null
        val f = url(context, fileName, personID)
        if (!f.exists()) return null
        return try {
            BitmapFactory.decodeFile(f.absolutePath)
        } catch (_: Exception) {
            null
        }
    }

    fun deleteFile(context: Context, fileName: String, personID: String) {
        url(context, fileName, personID).delete()
    }

    fun deleteFolder(context: Context, personID: String) {
        folder(context, personID).deleteRecursively()
    }
}
