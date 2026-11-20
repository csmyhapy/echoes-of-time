package life.lifememory.echosoftime.data

/**
 * 导入文本的清洗与中文段落排版（与 iOS ArchiveText.swift 行为一致）：
 * - 数据库导出里的字面 "\r\n" 转成真实换行
 * - 去掉不可见控制字符、合并多余空行
 * - 中文段落首行缩进两个全角空格
 * - 识别末尾「---」分隔线之后的落款，交给视图右对齐
 */
object ArchiveText {

    data class Body(
        val paragraphs: List<String>,
        val separator: String,
        val signature: String,
    ) {
        val hasSignature: Boolean get() = signature.isNotEmpty()
        val text: String get() = paragraphs.joinToString("\n")
    }

    /** 规范化：字面转义 → 真换行、去控制字符、行尾 trim、合并空行（保留分隔行） */
    fun normalized(raw: String): String {
        if (raw.isEmpty()) return ""
        var text = raw
        text = text.replace("\\r\\n", "\n")
        text = text.replace("\\n", "\n")
        text = text.replace("\\r", "\n")
        text = text.replace("\\t", " ")
        text = text.replace("\r\n", "\n").replace("\r", "\n")

        text = text.filter { c ->
            val v = c.code
            when {
                v == 10 -> true
                v < 32 -> false
                v == 127 -> false
                else -> true
            }
        }

        val lines = mutableListOf<String>()
        for (line in text.split("\n")) {
            val trimmed = line.trim()
            if (trimmed.isEmpty()) {
                val last = lines.lastOrNull()
                if (last != null && last.isNotEmpty()) lines.add("")
            } else {
                lines.add(trimmed)
            }
        }
        return lines.joinToString("\n").trim()
    }

    /** 短文本清洗（标题、简介、留言、照片说明）：顺带丢掉纯符号行 */
    fun clean(raw: String): String =
        normalized(raw).split("\n")
            .filter { !isSeparatorLine(it) }
            .joinToString("\n")
            .trim()

    fun inline(raw: String): String = clean(raw)

    /** 是否含中日韩文字（决定要不要按中文排版做缩进） */
    fun containsCJK(text: String): Boolean = text.any { c ->
        val v = c.code
        (0x4E00..0x9FFF).contains(v) ||
            (0x3400..0x4DBF).contains(v) ||
            (0x3000..0x303F).contains(v) ||
            (0x3040..0x309F).contains(v) ||
            (0x30A0..0x30FF).contains(v) ||
            (0x31A0..0x31BF).contains(v) ||
            (0xFF65..0xFF9F).contains(v)
    }

    /** 纯符号分隔线（--- / === / *** 等）。在正文里它是落款的分界线，要保留 */
    fun isSeparatorLine(line: String): Boolean {
        if (line.length < 3) return false
        val separators = setOf('-', '—', '–', '=', '*', '_', '~', '·', '|')
        return line.all { it in separators }
    }

    /** 正文排版：按段切分，中文段落首行缩进两个全角空格，段间空一行 */
    fun paragraphs(raw: String): String = indent(normalized(raw))

    /** 解析正文 + 落款：最后一个分隔行（---）之后若只有 1–3 行、总字数不超过 48，视为落款 */
    fun parse(raw: String): Body {
        val normalizedText = normalized(raw)
        if (normalizedText.isEmpty()) return Body(emptyList(), "", "")

        val lines = normalizedText.split("\n")
        val sepIndex = lines.indexOfLast { isSeparatorLine(it) }
        if (sepIndex >= 0) {
            val tail = lines.subList(sepIndex + 1, lines.size)
                .map { it.trim() }.filter { it.isNotEmpty() }
            val signature = tail.joinToString("\n")
            val head = lines.subList(0, sepIndex)
            if (tail.isNotEmpty() && tail.size <= 3 && signature.length <= 48) {
                return Body(
                    paragraphs = splitParagraphs(head.joinToString("\n")),
                    separator = lines[sepIndex],
                    signature = signature,
                )
            }
        }
        return Body(paragraphs = splitParagraphs(normalizedText), separator = "", signature = "")
    }

    /** 去掉落款、只留正文（用于预览、摘要） */
    fun bodyOnly(raw: String): String = parse(raw).text

    /** 单段文本缩进（简介、说明用） */
    fun indented(raw: String): String = splitParagraphs(clean(raw)).firstOrNull() ?: ""

    /** 切成段落，中文段落加两个全角空格 */
    fun splitParagraphs(cleaned: String): List<String> {
        val trimmed = cleaned.trim()
        if (trimmed.isEmpty()) return emptyList()
        val useIndent = containsCJK(trimmed)
        val prefix = if (useIndent) "　　" else ""
        return cleaned.split("\n")
            .map { it.trim() }
            .filter { it.isNotEmpty() && !isSeparatorLine(it) }
            .map { prefix + it }
    }

    private fun indent(cleaned: String): String = splitParagraphs(cleaned).joinToString("\n")
}
