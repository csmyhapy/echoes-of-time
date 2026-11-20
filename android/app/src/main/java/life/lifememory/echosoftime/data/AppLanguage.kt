package life.lifememory.echosoftime.data

/** 界面语言（与 iOS AppLanguage 一致），首发英文，内置 10 语资源 */
enum class AppLanguage(val code: String, val displayName: String) {
    EN("en", "English"),
    ES("es", "Español"),
    FR("fr", "Français"),
    DE("de", "Deutsch"),
    PT_BR("pt-BR", "Português (Brasil)"),
    IT("it", "Italiano"),
    NL("nl", "Nederlands"),
    JA("ja", "日本語"),
    KO("ko", "한국어"),
    ZH_HANS("zh-Hans", "中文");

    companion object {
        val all = entries.toList()

        fun fromCode(code: String?): AppLanguage? =
            entries.firstOrNull { it.code == code }

        /** 根据设备语言自动选择；未匹配到已支持语言时回退英文 */
        fun deviceDefault(preferred: List<String>): AppLanguage {
            for (raw in preferred) {
                val lower = raw.lowercase()
                val match = entries.firstOrNull {
                    lower == it.code.lowercase() || lower.startsWith(it.code.lowercase() + "-")
                }
                if (match != null) return match
                if (lower.startsWith("zh")) return ZH_HANS
            }
            return EN
        }
    }
}
