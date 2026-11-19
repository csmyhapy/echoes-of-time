//
//  ArchiveText.swift
//  EchoesOfTime
//
//  导入文本的清洗与中文段落排版
//  - 数据库导出里的字面 "\r\n" 会变成真实换行
//  - 去掉不可见控制字符、合并多余空行
//  - 中文段落首行缩进两个全角空格
//

import Foundation

enum ArchiveText {

    /// 清理文本：字面转义序列 → 真实字符，去控制字符，压掉多余空行
    static func clean(_ raw: String) -> String {
        guard !raw.isEmpty else { return "" }

        var text = raw
        // 字面反斜杠序列（SQL dump / JSON 双重转义常见）
        text = text.replacingOccurrences(of: "\\r\\n", with: "\n")
        text = text.replacingOccurrences(of: "\\n", with: "\n")
        text = text.replacingOccurrences(of: "\\r", with: "\n")
        text = text.replacingOccurrences(of: "\\t", with: " ")
        // 真实换行统一为 \n
        text = text.replacingOccurrences(of: "\r\n", with: "\n")
        text = text.replacingOccurrences(of: "\r", with: "\n")

        // 去掉控制字符（保留换行）
        text = String(String.UnicodeScalarView(text.unicodeScalars.filter { scalar in
            if scalar.value == 10 { return true }
            if scalar.value < 32 { return false }
            if scalar.value == 127 { return false }
            if scalar.properties.generalCategory == .format { return false }
            return true
        }))

        // 行尾空白 + 连续空行压缩
        var lines: [String] = []
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if isSeparatorLine(trimmed) {
                if let last = lines.last, !last.isEmpty { lines.append("") }
            } else if trimmed.isEmpty {
                if let last = lines.last, !last.isEmpty { lines.append("") }
            } else {
                lines.append(trimmed)
            }
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 纯符号分隔线（--- / === / *** 等），排版时丢掉
    private static func isSeparatorLine(_ line: String) -> Bool {
        guard line.count >= 3 else { return false }
        let separators: Set<Character> = ["-", "—", "–", "=", "*", "_", "~", "·", "|"]
        return line.allSatisfy { separators.contains($0) }
    }

    /// 是否含中日韩文字（决定要不要按中文排版做缩进）
    static func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value) ||
            (0x3400...0x4DBF).contains(scalar.value) ||
            (0x3000...0x303F).contains(scalar.value)
        }
    }

    /// 正文排版：按段落切分，中文段落首行缩进两个全角空格，段间空一行
    static func paragraphs(_ raw: String) -> String {
        let cleaned = clean(raw)
        guard !cleaned.isEmpty else { return "" }
        let indent = containsCJK(cleaned)
        let parts = cleaned.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return "" }
        let prefix = indent ? "　　" : ""
        return parts.map { prefix + $0 }.joined(separator: "\n\n")
    }

    /// 单行/短文本：只清洗，不缩进、不空行
    static func inline(_ raw: String) -> String {
        clean(raw)
    }
}
