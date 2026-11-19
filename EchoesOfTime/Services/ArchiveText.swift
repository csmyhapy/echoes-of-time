//
//  ArchiveText.swift
//  EchoesOfTime
//
//  导入文本的清洗与中文段落排版
//  - 数据库导出里的字面 "\r\n" 转成真实换行
//  - 去掉不可见控制字符、合并多余空行
//  - 中文段落首行缩进两个全角空格
//  - 识别末尾「---」分隔线之后的落款，交给视图右对齐
//

import Foundation

enum ArchiveText {

    /// 正文解析结果：正文（已排版） + 分隔线 + 落款
    struct Body {
        /// 已排版的段落（每段已带首行缩进）
        var paragraphs: [String]
        var separator: String
        var signature: String

        var hasSignature: Bool { !signature.isEmpty }

        /// 折叠预览用：段落直接换行相连，不留空行
        var text: String { paragraphs.joined(separator: "\n") }
    }

    // MARK: - 基础清洗

    /// 规范化：字面转义 → 真换行、去控制字符、行尾 trim、合并空行（保留分隔行）
    static func normalized(_ raw: String) -> String {
        guard !raw.isEmpty else { return "" }

        var text = raw
        text = text.replacingOccurrences(of: "\\r\\n", with: "\n")
        text = text.replacingOccurrences(of: "\\n", with: "\n")
        text = text.replacingOccurrences(of: "\\r", with: "\n")
        text = text.replacingOccurrences(of: "\\t", with: " ")
        text = text.replacingOccurrences(of: "\r\n", with: "\n")
        text = text.replacingOccurrences(of: "\r", with: "\n")

        text = String(String.UnicodeScalarView(text.unicodeScalars.filter { scalar in
            if scalar.value == 10 { return true }
            if scalar.value < 32 { return false }
            if scalar.value == 127 { return false }
            if scalar.properties.generalCategory == .format { return false }
            return true
        }))

        var lines: [String] = []
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if let last = lines.last, !last.isEmpty { lines.append("") }
            } else {
                lines.append(trimmed)
            }
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 短文本清洗（标题、简介、留言、照片说明）：顺带丢掉纯符号行
    static func clean(_ raw: String) -> String {
        let lines = normalized(raw).components(separatedBy: "\n")
        return lines.filter { !isSeparatorLine($0) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func inline(_ raw: String) -> String {
        clean(raw)
    }

    /// 是否含中日韩文字（决定要不要按中文排版做缩进）
    static func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value) ||
            (0x3400...0x4DBF).contains(scalar.value) ||
            (0x3000...0x303F).contains(scalar.value)
        }
    }

    /// 纯符号分隔线（--- / === / *** 等）。在正文里它是落款的分界线，要保留
    static func isSeparatorLine(_ line: String) -> Bool {
        guard line.count >= 3 else { return false }
        let separators: Set<Character> = ["-", "—", "–", "=", "*", "_", "~", "·", "|"]
        return line.allSatisfy { separators.contains($0) }
    }

    // MARK: - 段落排版

    /// 正文排版：按段切分，中文段落首行缩进两个全角空格，段间空一行
    static func paragraphs(_ raw: String) -> String {
        indent(normalized(raw))
    }

    /// 解析正文 + 落款
    /// 规则：文本里最后一个分隔行（---）之后若只有 1–3 行、总字数不超过 48，视为落款
    static func parse(_ raw: String) -> Body {
        let normalizedText = normalized(raw)
        guard !normalizedText.isEmpty else { return Body(paragraphs: [], separator: "", signature: "") }

        let lines = normalizedText.components(separatedBy: "\n")
        if let sepIndex = lines.lastIndex(where: { isSeparatorLine($0) }) {
            let tail = Array(lines[(sepIndex + 1)...])
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            let signature = tail.joined(separator: "\n")
            let head = Array(lines[..<sepIndex])
            if !tail.isEmpty, tail.count <= 3, signature.count <= 48 {
                return Body(
                    paragraphs: splitParagraphs(head.joined(separator: "\n")),
                    separator: lines[sepIndex],
                    signature: signature
                )
            }
        }

        return Body(paragraphs: splitParagraphs(normalizedText), separator: "", signature: "")
    }

    /// 去掉落款、只留正文（用于预览、摘要）
    static func bodyOnly(_ raw: String) -> String {
        parse(raw).text
    }

    /// 单段文本缩进（简介、说明用）
    static func indented(_ raw: String) -> String {
        splitParagraphs(clean(raw)).first ?? ""
    }

    /// 切成段落，中文段落加两个全角空格
    static func splitParagraphs(_ cleaned: String) -> [String] {
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let useIndent = containsCJK(trimmed)
        let prefix = useIndent ? "　　" : ""
        return trimmed.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !isSeparatorLine($0) }
            .map { prefix + $0 }
    }

    private static func indent(_ cleaned: String) -> String {
        splitParagraphs(cleaned).joined(separator: "\n")
    }
}
