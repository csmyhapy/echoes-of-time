//
//  PDFExporter.swift
//  EchoesOfTime
//
//  把一份人物档案渲染成 PDF 回忆册：
//  封面 → 简介/人生故事 → 每个章节（章节页 + 每张照片一页）
//

import UIKit

enum PDFExporter {

    static func makePDF(for person: Person) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)   // A4
        let margin: CGFloat = 40
        let contentWidth = pageRect.width - margin * 2
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeFileName(person.name)).pdf")

        do {
            try renderer.writePDF(to: url) { context in
                var pageNumber = 0

                func beginPage() {
                    pageNumber += 1
                    context.beginPage()
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 9),
                        .foregroundColor: UIColor.gray
                    ]
                    let footer = NSAttributedString(
                        string: "Echoes of Time  ·  \(person.name)  ·  \(pageNumber)",
                        attributes: attrs
                    )
                    footer.draw(at: CGPoint(x: margin, y: pageRect.height - 26))
                }

                // 1. 封面
                beginPage()
                drawCover(person, pageRect: pageRect, margin: margin, context: context)

                // 2. 简介与人生故事
                if !person.summary.isEmpty || !ArchiveText.paragraphs(person.story).isEmpty {
                    beginPage()
                    var y = margin
                    y = drawText("A Life Remembered",
                                 font: .boldSystemFont(ofSize: 24),
                                 color: .black, x: margin, y: y,
                                 width: contentWidth, lineSpacing: 0) + 16
                    if !person.summary.isEmpty {
                        y = drawText(person.summary,
                                     font: .italicSystemFont(ofSize: 15),
                                     color: .darkGray, x: margin, y: y,
                                     width: contentWidth, lineSpacing: 4) + 16
                    }
                    if !ArchiveText.paragraphs(person.story).isEmpty {
                        _ = drawText(ArchiveText.paragraphs(person.story),
                                     font: .systemFont(ofSize: 13),
                                     color: .black, x: margin, y: y,
                                     width: contentWidth, lineSpacing: 6)
                    }
                }

                // 3. 章节与照片
                let nodes = person.nodes.sorted { $0.sortOrder < $1.sortOrder }
                for node in nodes {
                    beginPage()
                    var y = margin
                    y = drawText(node.name,
                                 font: .boldSystemFont(ofSize: 22),
                                 color: .brown, x: margin, y: y,
                                 width: contentWidth, lineSpacing: 0) + 4
                    if !node.yearRange.isEmpty {
                        y = drawText(node.yearRange,
                                     font: .systemFont(ofSize: 12),
                                     color: .gray, x: margin, y: y,
                                     width: contentWidth, lineSpacing: 0) + 10
                    }
                    if !node.summary.isEmpty {
                        y = drawText(node.summary,
                                     font: .italicSystemFont(ofSize: 13),
                                     color: .darkGray, x: margin, y: y,
                                     width: contentWidth, lineSpacing: 4) + 10
                    }
                    if !ArchiveText.paragraphs(node.story).isEmpty {
                        _ = drawText(ArchiveText.paragraphs(node.story),
                                     font: .systemFont(ofSize: 12),
                                     color: .black, x: margin, y: y,
                                     width: contentWidth, lineSpacing: 5)
                    }

                    for photo in node.photos.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                        beginPage()
                        drawPhotoPage(photo, person: person, pageRect: pageRect,
                                      margin: margin, contentWidth: contentWidth)
                    }
                }
            }
        } catch {
            return nil
        }

        return url
    }

    // MARK: - 绘制

    private static func drawCover(_ person: Person, pageRect: CGRect, margin: CGFloat, context: UIGraphicsPDFRendererContext) {
        let cg = context.cgContext

        // 顶部标题
        drawText("Echoes of Time",
                 font: .systemFont(ofSize: 12),
                 color: .gray, x: margin, y: margin,
                 width: pageRect.width - margin * 2, lineSpacing: 0)

        // 封面图
        if let img = MediaStore.loadImage(fileName: person.coverImageFileName, personID: person.id) {
            let maxW = pageRect.width - margin * 2
            let maxH: CGFloat = 380
            let scale = min(maxW / img.size.width, maxH / img.size.height)
            let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
            let rect = CGRect(x: (pageRect.width - size.width) / 2,
                              y: margin + 60, width: size.width, height: size.height)
            cg.saveGState()
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 10)
            path.addClip()
            img.draw(in: rect)
            cg.restoreGState()
        }

        // 姓名
        let nameY = margin + 60 + 400
        let nameStyle = NSMutableParagraphStyle()
        nameStyle.alignment = .center
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 30),
            .foregroundColor: UIColor.black,
            .paragraphStyle: nameStyle
        ]
        let nameStr = NSAttributedString(string: person.name, attributes: nameAttrs)
        nameStr.draw(with: CGRect(x: margin, y: nameY, width: pageRect.width - margin * 2, height: 40),
                     options: [.usesLineFragmentOrigin], context: nil)

        if !person.birthYear.isEmpty {
            let yearAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15),
                .foregroundColor: UIColor.darkGray,
                .paragraphStyle: nameStyle
            ]
            let yearStr = NSAttributedString(string: person.birthYear, attributes: yearAttrs)
            yearStr.draw(with: CGRect(x: margin, y: nameY + 42, width: pageRect.width - margin * 2, height: 24),
                         options: [.usesLineFragmentOrigin], context: nil)
        }
    }

    private static func drawPhotoPage(_ photo: Photo, person: Person, pageRect: CGRect,
                                      margin: CGFloat, contentWidth: CGFloat) {
        var y = margin

        if let img = MediaStore.loadImage(fileName: photo.imageFileName, personID: person.id) {
            let maxH: CGFloat = 480
            let scale = min(contentWidth / img.size.width, maxH / img.size.height)
            let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
            let rect = CGRect(x: (pageRect.width - size.width) / 2, y: y,
                              width: size.width, height: size.height)
            UIGraphicsGetCurrentContext()?.saveGState()
            UIBezierPath(roundedRect: rect, cornerRadius: 10).addClip()
            img.draw(in: rect)
            UIGraphicsGetCurrentContext()?.restoreGState()
            y = rect.maxY + 14
        } else {
            y += 10
        }

        if !photo.caption.isEmpty {
            y = drawText(photo.caption,
                         font: .systemFont(ofSize: 16, weight: .semibold),
                         color: .black, x: margin, y: y,
                         width: contentWidth, lineSpacing: 2) + 6
        }
        if !ArchiveText.clean(photo.story).isEmpty {
            _ = drawText(ArchiveText.clean(photo.story),
                         font: .systemFont(ofSize: 12),
                         color: .darkGray, x: margin, y: y,
                         width: contentWidth, lineSpacing: 5)
        }
    }

    @discardableResult
    private static func drawText(_ text: String, font: UIFont, color: UIColor,
                                 x: CGFloat, y: CGFloat, width: CGFloat,
                                 lineSpacing: CGFloat) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style
        ]
        let attributed = NSAttributedString(string: text, attributes: attrs)
        let height = attributed.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).height
        attributed.draw(with: CGRect(x: x, y: y, width: width, height: height),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil)
        return height
    }

    /// 去掉文件名非法字符
    static func safeFileName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "archive" : trimmed
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return base.components(separatedBy: invalid).joined(separator: "_")
    }
}
