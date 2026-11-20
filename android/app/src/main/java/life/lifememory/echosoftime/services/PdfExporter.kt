package life.lifememory.echosoftime.services

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.pdf.PdfDocument
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import life.lifememory.echosoftime.data.ArchiveText
import life.lifememory.echosoftime.data.PersonBundle
import life.lifememory.echosoftime.data.PhotoEntity
import life.lifememory.echosoftime.data.belongsTo
import java.io.File
import java.io.FileOutputStream
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * 整册回忆画册 PDF（对应 iOS PDFExporter.AlbumBookRenderer）。
 * A4 竖版 595×842 pt：封面 → 目录 → 人生故事 → 章节分隔页 → 章节故事 → 照片页 → 尾页。
 */
object PdfExporter {

    private const val PAGE_W = 595f
    private const val PAGE_H = 842f
    private const val MARGIN = 56f
    private const val CONTENT_W = PAGE_W - MARGIN * 2

    private val brown = Color.rgb(107, 74, 41)
    private val ink = Color.rgb(59, 50, 41)
    private val muted = Color.rgb(138, 124, 107)
    private val paper = Color.rgb(252, 250, 245)

    fun safeFileName(name: String): String {
        val base = name.trim().ifEmpty { "archive" }
        return base.replace(Regex("[/\\\\?%*|\"<>:]"), "_")
    }

    /** 渲染整册，输出 cacheDir 下的 PDF 文件；失败返回 null */
    fun makeAlbumPdf(context: Context, b: PersonBundle): File? {
        val nodes = b.nodes.filter { it.isVisible }.sortedWith(nodeComparator())
        val doc = PdfDocument()
        var pageNo = 0

        // 两遍：先统计章节分隔页页码
        data class Page(val kind: Int, val node: life.lifememory.echosoftime.data.NodeEntity? = null,
                        val paras: List<String> = emptyList(), val sig: String = "",
                        val photo: PhotoEntity? = null, val pair: List<PhotoEntity> = emptyList())

        val pages = ArrayList<Page>()
        pages += Page(0) // cover
        pages += Page(1) // toc

        val lifeBody = ArchiveText.parse(b.person.story)
        val lifeChunks = paginate(lifeBody.paragraphs)
        lifeChunks.forEachIndexed { i, chunk ->
            pages += Page(2, paras = chunk, sig = if (i == lifeChunks.lastIndex) lifeBody.signature else "")
        }

        for (node in nodes) {
            pages += Page(3, node = node)
            val chBody = ArchiveText.parse(node.story)
            val chunks = paginate(chBody.paragraphs)
            chunks.forEachIndexed { i, chunk ->
                pages += Page(4, node = node, paras = chunk, sig = if (i == chunks.lastIndex) chBody.signature else "")
            }
            val photos = b.photos.filter { it.belongsTo(node) }.sortedBy { it.sortOrder }
            var i = 0
            while (i < photos.size) {
                if (photos[i].pairWithNext && i + 1 < photos.size) {
                    pages += Page(6, node = node, pair = listOf(photos[i], photos[i + 1]))
                    i += 2
                } else {
                    pages += Page(5, node = node, photo = photos[i])
                    i += 1
                }
            }
        }
        pages += Page(7) // closing

        val dividerPage = HashMap<String, Int>()
        pages.forEachIndexed { i, p -> if (p.kind == 3) dividerPage[p.node!!.id] = i + 1 }

        pages.forEach { p ->
            pageNo++
            val page = doc.startPage(PdfDocument.PageInfo.Builder(PAGE_W.toInt(), PAGE_H.toInt(), pageNo).create())
            val canvas = page.canvas
            canvas.drawColor(paper)
            when (p.kind) {
                0 -> drawCover(canvas, context, b)
                1 -> drawToc(canvas, nodes, dividerPage)
                2 -> drawStoryPage(canvas, "LIFE STORY", "人生故事", p.paras, p.sig, pageNo)
                3 -> drawDivider(canvas, p.node!!)
                4 -> drawStoryPage(canvas, p.node!!.yearRange, p.node!!.name, p.paras, p.sig, pageNo)
                5 -> drawPhotoPage(canvas, context, p.photo!!, b.person.id)
                6 -> drawPhotoGrid(canvas, context, p.pair, b.person.id)
                7 -> drawClosing(canvas)
            }
            doc.finishPage(page)
        }

        val out = File(context.cacheDir, "${safeFileName(b.person.name)}.pdf")
        return try {
            FileOutputStream(out).use { doc.writeTo(it) }
            doc.close()
            out
        } catch (_: Exception) {
            doc.close(); null
        }
    }

    private fun nodeComparator(): Comparator<life.lifememory.echosoftime.data.NodeEntity> =
        Comparator { a, c ->
            if (a.sortOrder != c.sortOrder) return@Comparator a.sortOrder - c.sortOrder
            a.createdAt.compareTo(c.createdAt)
        }

    private fun paginate(paragraphs: List<String>): List<List<String>> {
        val result = ArrayList<List<String>>()
        var current = ArrayList<String>()
        var used = 0f
        val maxH = 620f
        for (p in paragraphs) {
            val h = measure(p, 15f, CONTENT_W)
            if (current.isNotEmpty() && used + h + 14 > maxH) {
                result += current
                current = ArrayList()
                used = 0f
            }
            current += p
            used += h + 14
        }
        if (current.isNotEmpty()) result += current
        return result.ifEmpty { listOf(emptyList()) }
    }

    private fun measure(text: String, size: Float, width: Float): Float {
        val tp = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = size; color = ink }
        val sl = StaticLayout.Builder.obtain(text, 0, text.length, tp, width.toInt())
            .setLineSpacing(8f, 1f).setAlignment(Layout.Alignment.ALIGN_NORMAL).build()
        return sl.height.toFloat()
    }

    private fun drawPara(canvas: Canvas, text: String, x: Float, y: Float, width: Float,
                         size: Float, color: Int, spacing: Float, align: Layout.Alignment = Layout.Alignment.ALIGN_NORMAL): Float {
        val tp = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = size; this.color = color }
        val sl = StaticLayout.Builder.obtain(text, 0, text.length, tp, width.toInt())
            .setLineSpacing(spacing, 1f).setAlignment(align).build()
        canvas.save()
        canvas.translate(x, y)
        sl.draw(canvas)
        canvas.restore()
        return sl.height.toFloat()
    }

    private fun pageNumber(canvas: Canvas, n: Int) {
        val tp = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 10f; color = Color.GRAY }
        canvas.drawText("$n", PAGE_W / 2 - 8, PAGE_H - 22f, tp)
    }

    private fun drawCover(canvas: Canvas, context: Context, b: PersonBundle) {
        val cover = life.lifememory.echosoftime.data.MediaStore.loadImage(context, b.resolvedCoverFileName, b.person.id)
        var y = 110f
        if (cover != null) {
            val rect = RectF(PAGE_W / 2 - 150, y, PAGE_W / 2 + 150, y + 300)
            val scaled = fitInside(cover, 300, 300)
            canvas.save()
            clipRound(canvas, rect, 16f)
            canvas.drawBitmap(scaled, null, rect, null)
            canvas.restore()
            y += 326
        }
        y += 26
        val namePaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 38f; isFakeBoldText = true; color = ink }
        canvas.drawCenteredText(b.person.name, PAGE_W / 2, y, namePaint)
        y += 44
        if (b.person.birthYear.isNotEmpty()) {
            val p = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 16f; color = muted }
            canvas.drawCenteredText(b.person.birthYear, PAGE_W / 2, y, p)
            y += 28
        }
        if (b.person.summary.isNotEmpty()) {
            y += 8
            y += drawPara(canvas, b.person.summary, MARGIN + 56, y, CONTENT_W - 112, 14f, muted, 6f, Layout.Alignment.ALIGN_CENTER) + 8
        }
        val foot = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 11f; color = Color.GRAY }
        canvas.drawCenteredText("Echoes of Time · 回忆画册", PAGE_W / 2, PAGE_H - 40f, foot)
    }

    private fun drawToc(canvas: Canvas, nodes: List<life.lifememory.echosoftime.data.NodeEntity>, pages: Map<String, Int>) {
        val title = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 30f; isFakeBoldText = true; color = ink }
        canvas.drawText("目录", MARGIN, 96f, title)
        var y = 140f
        val nameP = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 17f; color = ink }
        val yearP = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 13f; color = muted }
        val numP = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 15f; color = muted }
        val lineP = Paint().apply { color = Color.rgb(227, 216, 198); strokeWidth = 1f }
        for (n in nodes) {
            canvas.drawText(n.name, MARGIN, y, nameP)
            var x = MARGIN + nameP.measureText(n.name) + 12
            if (n.yearRange.isNotEmpty()) {
                canvas.drawText(n.yearRange, x, y, yearP)
            }
            val num = "${pages[n.id] ?: 0}"
            canvas.drawText(num, PAGE_W - MARGIN - numP.measureText(num), y, numP)
            y += 18
            canvas.drawLine(MARGIN, y + 6, PAGE_W - MARGIN, y + 6, lineP)
            y += 26
        }
    }

    private fun drawDivider(canvas: Canvas, node: life.lifememory.echosoftime.data.NodeEntity) {
        val nameP = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 34f; isFakeBoldText = true; color = brown }
        var y = PAGE_H / 2 - 40f
        canvas.drawCenteredText(node.name, PAGE_W / 2, y, nameP)
        y += 34
        if (node.yearRange.isNotEmpty()) {
            val yp = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 15f; color = muted }
            canvas.drawCenteredText(node.yearRange, PAGE_W / 2, y, yp)
            y += 26
        }
        if (node.summary.isNotEmpty()) {
            y += 8
            drawPara(canvas, node.summary, MARGIN + 56, y, CONTENT_W - 112, 14f, muted, 6f, Layout.Alignment.ALIGN_CENTER)
        }
    }

    private fun drawStoryPage(canvas: Canvas, eyebrow: String, title: String, paras: List<String>, sig: String, pageNo: Int) {
        var y = 96f
        if (eyebrow.isNotEmpty()) {
            val ep = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 12f; color = brown; isFakeBoldText = true }
            canvas.drawText(eyebrow, MARGIN, y, ep)
            y += 26
        }
        val tp = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 28f; isFakeBoldText = true; color = Color.BLACK }
        canvas.drawText(title, MARGIN, y, tp)
        y += 34
        val bp = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 15f; color = Color.argb(230, 0, 0, 0) }
        for (p in paras) {
            val sl = StaticLayout.Builder.obtain(p, 0, p.length, bp, CONTENT_W.toInt())
                .setLineSpacing(8f, 1f).build()
            canvas.save(); canvas.translate(MARGIN, y); sl.draw(canvas); canvas.restore()
            y += sl.height + 14
        }
        if (sig.isNotEmpty()) {
            y += 20
            val sp = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 14f; color = muted }
            canvas.drawText(sig, PAGE_W - MARGIN - sp.measureText(sig), y, sp)
        }
        pageNumber(canvas, pageNo)
    }

    private fun drawPhotoPage(canvas: Canvas, context: Context, photo: PhotoEntity, personId: String) {
        val img = life.lifememory.echosoftime.data.MediaStore.loadImage(context, photo.imageFileName, personId)
        var y = 64f
        if (img != null) {
            val ratio = img.width.toFloat() / maxOf(img.height, 1)
            val wRatio = when {
                ratio >= 1f -> 0.95f
                ratio >= 0.8f -> 0.74f
                else -> 0.58f
            }
            val w = PAGE_W * wRatio
            val scaled = fitInside(img, w.toInt(), 520)
            val left = (PAGE_W - scaled.width) / 2
            val rect = RectF(left, y, left + scaled.width, y + scaled.height)
            canvas.save(); clipRound(canvas, rect, 12f); canvas.drawBitmap(scaled, null, rect, null); canvas.restore()
            y += scaled.height + 16
        }
        if (photo.caption.isNotEmpty()) {
            val cp = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 18f; isFakeBoldText = true; color = ink }
            y += drawPara(canvas, photo.caption, MARGIN, y, CONTENT_W, 18f, ink, 6f) + 8
        }
        val story = ArchiveText.clean(photo.story)
        if (story.isNotEmpty()) {
            drawPara(canvas, story, MARGIN, y, CONTENT_W, 13f, muted, 6f)
        }
    }

    private fun drawPhotoGrid(canvas: Canvas, context: Context, photos: List<PhotoEntity>, personId: String) {
        val colW = (CONTENT_W - 18f) / 2
        var x = MARGIN
        for (photo in photos) {
            val img = life.lifememory.echosoftime.data.MediaStore.loadImage(context, photo.imageFileName, personId)
            var y = 64f
            if (img != null) {
                val scaled = fitInside(img, colW.toInt(), 220)
                val rect = RectF(x, y, x + scaled.width, y + scaled.height)
                canvas.save(); clipRound(canvas, rect, 12f); canvas.drawBitmap(scaled, null, rect, null); canvas.restore()
                y += 230
            }
            if (photo.caption.isNotEmpty()) {
                y += 10
                y += drawPara(canvas, photo.caption, x, y, colW, 16f, ink, 4f) + 6
            }
            val story = ArchiveText.clean(photo.story)
            if (story.isNotEmpty()) drawPara(canvas, story, x, y, colW, 13f, muted, 6f)
            x += colW + 18f
        }
    }

    private fun drawClosing(canvas: Canvas) {
        val p = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 16f; color = muted }
        canvas.drawCenteredText("— 完 —", PAGE_W / 2, PAGE_H / 2, p)
    }

    private fun fitInside(src: Bitmap, maxW: Int, maxH: Int): Bitmap {
        val ratio = min(maxW.toFloat() / src.width, maxH.toFloat() / src.height)
        val w = (src.width * ratio).roundToInt().coerceAtLeast(1)
        val h = (src.height * ratio).roundToInt().coerceAtLeast(1)
        return if (w == src.width && h == src.height) src
        else Bitmap.createScaledBitmap(src, w, h, true)
    }

    private fun clipRound(canvas: Canvas, rect: RectF, r: Float) {
        val path = android.graphics.Path().apply { addRoundRect(rect, r, r, android.graphics.Path.Direction.CW) }
        canvas.clipPath(path)
    }

    private fun Canvas.drawCenteredText(text: String, cx: Float, y: Float, paint: TextPaint) {
        drawText(text, cx - paint.measureText(text) / 2, y, paint)
    }
}
