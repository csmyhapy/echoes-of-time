//
//  ArchiveParagraphView.swift
//  EchoesOfTime
//
//  正文段落渲染：段间不留空行，段落间距比行间距大 30%；
//  折叠状态下按行数截断（预览用）。
//

import SwiftUI

struct ArchiveParagraphView: View {
    let paragraphs: [String]
    let expanded: Bool
    var fontSize: CGFloat = 16
    var lineSpacing: CGFloat = 6
    var collapsedLines: Int = 4

    /// 段距 ≈ 行距 × 1.3
    private var paragraphSpacing: CGFloat {
        (fontSize * 0.18 + lineSpacing) * 1.3
    }

    var body: some View {
        if expanded {
            VStack(alignment: .leading, spacing: paragraphSpacing) {
                ForEach(paragraphs.indices, id: \.self) { i in
                    Text(paragraphs[i])
                        .font(.system(size: fontSize))
                        .lineSpacing(lineSpacing)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            Text(paragraphs.joined(separator: "\n"))
                .font(.system(size: fontSize))
                .lineSpacing(lineSpacing)
                .lineLimit(collapsedLines)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
