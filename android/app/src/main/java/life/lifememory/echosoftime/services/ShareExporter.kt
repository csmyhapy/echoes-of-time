package life.lifememory.echosoftime.services

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import life.lifememory.echosoftime.R
import life.lifememory.echosoftime.data.ArchiveText
import life.lifememory.echosoftime.data.MediaStore
import life.lifememory.echosoftime.data.PersonEntity
import life.lifememory.echosoftime.data.PhotoEntity
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.util.Base64

/** 亲友回信解析结果 */
data class ShareReply(val name: String, val content: String, val dateMillis: Long)

/**
 * 分享导出：单张网页 HTML / 纪念卡片长图 / 回信解析（对应 iOS ShareExporter）。
 */
object ShareExporter {

    const val replyPrefix = "ECHOES-REPLY-1:"

    private val brown = Color.rgb(107, 74, 41)
    private val ink = Color.rgb(59, 50, 41)
    private val muted = Color.rgb(138, 124, 107)
    private val hairline = Color.rgb(227, 216, 198)

    // MARK: 分享网页（单个 .html，图片与旁白全部内嵌）

    fun makePageHtml(context: Context, photo: PhotoEntity, person: PersonEntity): File? {
        val img = MediaStore.loadImage(context, photo.imageFileName, person.id) ?: return null
        val jpeg = toJpeg(img, 85) ?: return null
        val caption = photo.caption.trim()
        val displayName = caption.ifEmpty { context.getString(R.string.share_untitled_photo) }

        var audioBlock = ""
        photo.audioFileName?.let { aName ->
            val f = MediaStore.url(context, aName, person.id)
            if (f.exists() && f.length() <= 5L * 1024 * 1024) {
                val b64 = Base64.getEncoder().encodeToString(f.readBytes())
                audioBlock = """
                <div class="audio">
                  <span class="label">${esc(context.getString(R.string.photo_narration_title))}</span>
                  <audio controls preload="metadata" src="data:audio/mp4;base64,$b64"></audio>
                </div>
                """
            }
        }

        val storyParas = ArchiveText.splitParagraphs(ArchiveText.normalized(photo.story))
        val storyBlock = if (storyParas.isEmpty()) "" else
            "<div class=\"story\">" + storyParas.joinToString("\n") { "<p>${esc(it)}</p>" } + "</div>"

        val headP1 = esc(context.getString(R.string.share_head_p1, person.name))
        val html = """
        <!doctype html>
        <html lang="zh-Hans">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
        <title>${esc(displayName)} · ${esc(person.name)}</title>
        <style>
        :root{--paper:#FBF7F0;--ink:#3B3229;--brown:#7A5230;--line:#E3D8C6;}
        *{box-sizing:border-box;}
        body{margin:0;background:var(--paper);color:var(--ink);
             font-family:-apple-system,BlinkMacSystemFont,"PingFang SC","Songti SC",serif;
             -webkit-text-size-adjust:100%;}
        .wrap{max-width:720px;margin:0 auto;padding:28px 20px 48px;}
        .head{margin:0 0 22px;padding:20px 22px;border:1px solid var(--line);border-left:3px solid var(--brown);
             background:#fff;border-radius:0 14px 14px 0;}
        .head h2{font-size:15px;letter-spacing:.14em;color:var(--brown);margin:0 0 12px;font-weight:600;}
        .head p{font-size:14.5px;line-height:1.9;color:#5E5347;margin:0;text-align:justify;text-indent:2em;}
        .head p + p{margin-top:0.57em;}
        .photo{width:100%;height:auto;display:block;border-radius:14px;box-shadow:0 8px 26px rgba(80,55,30,.13);}
        h1{font-size:26px;line-height:1.3;margin:22px 0 6px;color:var(--brown);font-weight:700;}
        .owner{font-size:14px;color:#8A7C6B;margin:0 0 18px;}
        .story p{font-size:16.5px;line-height:1.85;margin:0 0 14px;text-align:justify;text-indent:2em;}
        .story p:first-child{margin-top:0;}
        .audio{margin:22px 0 6px;padding:14px 16px;border:1px solid var(--line);border-radius:12px;background:#fff;}
        .audio .label{display:block;font-size:12px;letter-spacing:.12em;color:var(--brown);opacity:.8;margin-bottom:8px;}
        .audio audio{width:100%;}
        footer{margin-top:34px;text-align:center;color:#A89B8A;}
        footer span{display:block;}
        .brand{font-size:12px;letter-spacing:.1em;}
        .slogan{font-size:13px;color:var(--brown);opacity:.85;margin-top:6px;}
        .by{font-size:11px;margin-top:6px;opacity:.8;}
        </style>
        </head>
        <body>
        <div class="wrap">
          <div class="head">
            <h2>${esc(context.getString(R.string.share_head_title))}</h2>
            <p>$headP1</p>
            <p>${esc(context.getString(R.string.share_head_p2))}</p>
          </div>
          <img class="photo" alt="${esc(displayName)}" src="data:image/jpeg;base64,${Base64.getEncoder().encodeToString(jpeg)}">
          <h1>${esc(displayName)}</h1>
          <p class="owner">${esc(person.name)}${if (person.birthYear.isEmpty()) "" else " · " + esc(person.birthYear)}</p>
          $storyBlock
          $audioBlock
          <footer>
            <span class="brand">${esc(context.getString(R.string.share_footer))}</span>
            <span class="slogan">${esc(context.getString(R.string.share_brand_slogan))}</span>
            <span class="by">${esc(context.getString(R.string.share_brand_by))}</span>
          </footer>
        </div>
        </body>
        </html>
        """

        val file = File(context.cacheDir,
            "${PdfExporter.safeFileName(person.name)}-${PdfExporter.safeFileName(displayName)}-ceshuo.html")
        return try {
            file.writeText(html, Charsets.UTF_8); file
        } catch (_: Exception) { null }
    }

    // MARK: 纪念卡片（照片 + 说明同图）

    fun makeCard(context: Context, photo: PhotoEntity, person: PersonEntity): Bitmap? {
        val src = MediaStore.loadImage(context, photo.imageFileName, person.id) ?: return null
        val width = 1080
        val pad = 72
        val contentWidth = width - pad * 2

        val ratio = src.height.toFloat() / maxOf(src.width, 1)
        var photoH = contentWidth * ratio
        if (photoH > 620f) photoH = 620f

        val caption = photo.caption.trim()
        val displayName = caption.ifEmpty { context.getString(R.string.share_untitled_photo) }
        val storyText = ArchiveText.paragraphs(photo.story)
        val storyTrim = if (storyText.length > 220) storyText.take(220) + "…" else storyText
        val headText = "　　" + context.getString(R.string.share_head_p1, person.name) + "\n" +
            context.getString(R.string.share_head_p2)
        val ownerText = person.name + if (person.birthYear.isEmpty()) "" else " · " + person.birthYear

        val headTitleP = textPaint(36f, true, brown)
        val headP = textPaint(30f, false, ink)
        val titleP = textPaint(46f, true, brown)
        val ownerP = textPaint(26f, false, muted)
        val storyP = textPaint(29f, false, ink)
        val sloganP = textPaint(23f, false, muted)
        val brandP = textPaint(28f, true, brown)

        val headTitleH = measure(context.getString(R.string.share_head_title), headTitleP, contentWidth, 0f)
        val headH = measure(headText, headP, contentWidth, 10f)
        val titleH = measure(displayName, titleP, contentWidth, 6f)
        val ownerH = measure(ownerText, ownerP, contentWidth, 0f)
        val storyH = measure(storyTrim, storyP, contentWidth, 10f)
        val sloganH = measure(context.getString(R.string.share_brand_slogan), sloganP, contentWidth, 4f)

        val totalH = (66f + headTitleH + 18f + headH + 40f
            + photoH + 40f + titleH + 10f + ownerH
            + (if (storyH > 0) 24f + storyH else 0f)
            + 44f + 40f + sloganH + 80f).toInt()

        val bmp = Bitmap.createBitmap(width, totalH, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        canvas.drawColor(Color.rgb(251, 247, 240))

        var y = 66f
        drawText(canvas, context.getString(R.string.share_head_title), pad.toFloat(), y, contentWidth, headTitleP, 0f)
        y += headTitleH + 18f - 8f
        canvas.drawLine(pad.toFloat(), y, (width - pad).toFloat(), y, Paint().apply { color = hairline; strokeWidth = 1f })
        y += 26f
        drawText(canvas, headText, pad.toFloat(), y, contentWidth, headP, 10f)
        y += headH + 40f

        val scaled = fitInside(src, contentWidth, photoH.toInt())
        val dx = pad + (contentWidth - scaled.width) / 2f
        val dy = y + (photoH - scaled.height) / 2f
        val photoRect = RectF(pad.toFloat(), y, (width - pad).toFloat(), y + photoH)
        canvas.save()
        clipRound(canvas, RectF(dx, dy, dx + scaled.width, dy + scaled.height), 16f)
        canvas.drawBitmap(scaled, dx, dy, null)
        canvas.restore()
        y = photoRect.bottom + 40f

        drawText(canvas, displayName, pad.toFloat(), y, contentWidth, titleP, 6f)
        y += titleH + 10f
        drawText(canvas, ownerText, pad.toFloat(), y, contentWidth, ownerP, 0f)
        y += ownerH
        if (storyH > 0) {
            y += 24f
            drawText(canvas, storyTrim, pad.toFloat(), y, contentWidth, storyP, 10f)
            y += storyH
        }
        y += 44f
        canvas.drawLine(pad.toFloat(), y - 18f, (width - pad).toFloat(), y - 18f, Paint().apply { color = hairline; strokeWidth = 1f })
        drawText(canvas, context.getString(R.string.share_footer), pad.toFloat(), y, contentWidth, brandP, 0f)
        y += 40f
        drawText(canvas, context.getString(R.string.share_brand_slogan), pad.toFloat(), y, contentWidth, sloganP, 4f)
        return bmp
    }

    fun writeCard(context: Context, image: Bitmap, person: PersonEntity, caption: String): File? {
        val data = toJpeg(image, 92) ?: return null
        val name = PdfExporter.safeFileName(caption.ifEmpty { person.name })
        val file = File(context.cacheDir, "${PdfExporter.safeFileName(person.name)}-$name-jinian.jpg")
        return try { FileOutputStream(file).use { it.write(data) }; file } catch (_: Exception) { null }
    }

    // MARK: 回信解析

    fun parseReply(context: Context, raw: String): ShareReply? {
        var text = raw.trim()
        val anon = context.getString(R.string.share_leave_anonymous)
        val prefixIdx = text.indexOf(replyPrefix)
        if (prefixIdx >= 0) {
            text = text.substring(prefixIdx + replyPrefix.length)
                .filterNot { it.isWhitespace() }
            return try {
                val obj = JSONObject(String(Base64.getDecoder().decode(text)))
                val content = obj.optString("text").trim()
                if (content.isEmpty()) return null
                val name = obj.optString("name").trim().ifEmpty { anon }
                ShareReply(name, content, System.currentTimeMillis())
            } catch (_: Exception) { null }
        }
        return parsePlainText(text, anon)
    }

    private fun parsePlainText(text: String, anon: String): ShareReply? {
        if (text.isEmpty() || text.length > 2000) return null
        val nl = text.indexOf('\n')
        val firstLine = if (nl >= 0) text.substring(0, nl) else text
        val sepIdx = firstLine.indexOfAny(charArrayOf('：', ':'))
        if (sepIdx > 0) {
            val name = firstLine.substring(0, sepIdx).trim()
            val rest = firstLine.substring(sepIdx + 1).trim()
            val tail = if (nl >= 0) text.substring(nl + 1).trim() else ""
            if (name.isNotEmpty() && name.length <= 12 && '。' !in name && '，' !in name) {
                val body = listOf(rest, tail).filter { it.isNotEmpty() }.joinToString("\n")
                if (body.isNotEmpty()) return ShareReply(name, body, System.currentTimeMillis())
            }
        }
        return ShareReply(anon, text, System.currentTimeMillis())
    }

    // MARK: 工具

    private fun textPaint(size: Float, bold: Boolean, color: Int) = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = size; this.color = color; isFakeBoldText = bold
    }

    private fun measure(text: String, paint: TextPaint, width: Int, lineSpacing: Float): Float {
        if (text.isEmpty()) return 0f
        val sl = StaticLayout.Builder.obtain(text, 0, text.length, paint, width)
            .setLineSpacing(lineSpacing, 1f)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .build()
        return sl.height.toFloat()
    }

    private fun drawText(canvas: Canvas, text: String, x: Float, y: Float, width: Int,
                         paint: TextPaint, lineSpacing: Float) {
        val sl = StaticLayout.Builder.obtain(text, 0, text.length, paint, width)
            .setLineSpacing(lineSpacing, 1f)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .build()
        canvas.save(); canvas.translate(x, y); sl.draw(canvas); canvas.restore()
    }

    private fun fitInside(src: Bitmap, maxW: Int, maxH: Int): Bitmap {
        val ratio = minOf(maxW.toFloat() / src.width, maxH.toFloat() / src.height)
        val w = (src.width * ratio).toInt().coerceAtLeast(1)
        val h = (src.height * ratio).toInt().coerceAtLeast(1)
        return if (w == src.width && h == src.height) src
        else Bitmap.createScaledBitmap(src, w, h, true)
    }

    private fun clipRound(canvas: Canvas, rect: RectF, r: Float) {
        val path = android.graphics.Path().apply { addRoundRect(rect, r, r, android.graphics.Path.Direction.CW) }
        canvas.clipPath(path)
    }

    private fun toJpeg(bmp: Bitmap, quality: Int): ByteArray? = try {
        java.io.ByteArrayOutputStream().use { out ->
            bmp.compress(Bitmap.CompressFormat.JPEG, quality, out); out.toByteArray()
        }
    } catch (_: Exception) { null }

    private fun esc(s: String): String = s
        .replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")
}
