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

// MARK: - 分享导出（亲友分享网页 / 纪念长图 / 回信解析）

/// 亲友回信
struct ShareReply {
    let name: String
    let content: String
    let date: Date
}

enum ShareExporter {

    /// 回信文本前缀（与网页里生成的保持一致）
    static let replyPrefix = "ECHOES-REPLY-1:"

    // MARK: 分享网页（单个 .html，图片与旁白全部内嵌）

    static func makePage(photo: Photo, person: Person, personID: UUID) -> URL? {
        guard let img = MediaStore.loadImage(fileName: photo.imageFileName, personID: personID),
              let jpeg = img.jpegData(compressionQuality: 0.85) else { return nil }

        let caption = photo.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = caption.isEmpty ? String(localized: "share.untitled.photo") : caption

        // 旁白（超过 5MB 不内嵌，避免文件过大）
        var audioBlock = ""
        if let aName = photo.audioFileName,
           let data = try? Data(contentsOf: MediaStore.url(fileName: aName, personID: personID)),
           data.count <= 5 * 1024 * 1024 {
            audioBlock = """
            <div class="audio">
              <span class="label">\(esc(String(localized: "photo.narration.title")))</span>
              <audio controls preload="metadata" src="data:audio/mp4;base64,\(data.base64EncodedString())"></audio>
            </div>
            """
        }

        // 故事：逐段渲染，保留缩进
        var storyBlock = ""
        let paragraphs = ArchiveText.splitParagraphs(ArchiveText.normalized(photo.story))
        if !paragraphs.isEmpty {
            let body = paragraphs.map { "<p>\(esc($0))</p>" }.joined(separator: "\n")
            storyBlock = "<div class=\"story\">\(body)</div>"
        }

        let html = """
        <!doctype html>
        <html lang="zh-Hans">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
        <title>\(esc(displayName)) · \(esc(person.name))</title>
        <style>
        :root{--paper:#FBF7F0;--ink:#3B3229;--brown:#7A5230;--line:#E3D8C6;}
        *{box-sizing:border-box;}
        body{margin:0;background:var(--paper);color:var(--ink);
             font-family:-apple-system,BlinkMacSystemFont,"PingFang SC","Songti SC",serif;
             -webkit-text-size-adjust:100%;}
        .wrap{max-width:720px;margin:0 auto;padding:28px 20px 48px;}
        .kicker{font-size:13px;letter-spacing:.18em;color:var(--brown);opacity:.75;margin:0 0 14px;}
        .photo{width:100%;height:auto;display:block;border-radius:14px;box-shadow:0 8px 26px rgba(80,55,30,.13);}
        h1{font-size:26px;line-height:1.3;margin:22px 0 6px;color:var(--brown);font-weight:700;}
        .owner{font-size:14px;color:#8A7C6B;margin:0 0 18px;}
        .story p{font-size:16.5px;line-height:1.85;margin:0 0 14px;text-align:justify;text-indent:2em;}
        .story p:first-child{margin-top:0;}
        .audio{margin:22px 0 6px;padding:14px 16px;border:1px solid var(--line);border-radius:12px;background:#fff;}
        .audio .label{display:block;font-size:12px;letter-spacing:.12em;color:var(--brown);opacity:.8;margin-bottom:8px;}
        .audio audio{width:100%;}
        .note{margin-top:32px;padding:18px 20px;border-left:3px solid var(--brown);
             background:#fff;border-radius:0 12px 12px 0;font-size:15px;line-height:1.9;color:#5E5347;}
        .note strong{color:var(--brown);}
        footer{margin-top:34px;text-align:center;font-size:12px;color:#A89B8A;letter-spacing:.1em;}
        @media print{body{background:#fff}.note{break-inside:avoid}}
        </style>
        </head>
        <body>
        <div class="wrap">
          <p class="kicker">\(esc(String(localized: "share.kicker")))</p>
          <img class="photo" alt="\(esc(displayName))" src="data:image/jpeg;base64,\(jpeg.base64EncodedString())">
          <h1>\(esc(displayName))</h1>
          <p class="owner">\(esc(person.name))\(person.birthYear.isEmpty ? "" : " · \(esc(person.birthYear))")</p>
          \(storyBlock)
          \(audioBlock)

          <div class="note">
            \(esc(String(localized: "share.readonly.hint")))
          </div>

          <footer>\(esc(String(localized: "share.footer")))</footer>
        </div>
        </body>
        </html>
        """

        let dir = FileManager.default.temporaryDirectory
        let fileName = "\(PDFExporter.safeFileName(person.name))-\(PDFExporter.safeFileName(displayName))-ceshuo.html"
        let url = dir.appendingPathComponent(fileName)
        do {
            try html.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    // MARK: 纪念长图

    static func makeCard(photo: Photo, person: Person, personID: UUID) -> UIImage? {
        guard let img = MediaStore.loadImage(fileName: photo.imageFileName, personID: personID),
              let jpeg = img.jpegData(compressionQuality: 0.9) else { return nil }

        let width: CGFloat = 1080
        let pad: CGFloat = 72
        let contentWidth = width - pad * 2

        // 照片按比例缩放，最高 860
        let src = UIImage(data: jpeg) ?? img
        let ratio = src.size.height / max(1, src.size.width)
        var photoH = contentWidth * ratio
        photoH = min(photoH, 860)

        let caption = photo.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = caption.isEmpty ? String(localized: "share.untitled.photo") : caption

        let titleFont = UIFont.systemFont(ofSize: 46, weight: .semibold)
        let storyFont = UIFont.systemFont(ofSize: 29)
        let ownerFont = UIFont.systemFont(ofSize: 26)
        let footFont = UIFont.systemFont(ofSize: 22, weight: .medium)

        let storyText = ArchiveText.paragraphs(photo.story)
        let storyTrim = storyText.count > 260 ? String(storyText.prefix(260)) + "…" : storyText

        func measured(_ text: String, _ font: UIFont, _ width: CGFloat, spacing: CGFloat) -> CGFloat {
            guard !text.isEmpty else { return 0 }
            let para = NSMutableParagraphStyle()
            para.lineSpacing = spacing
            let attr = NSAttributedString(string: text, attributes: [.font: font, .paragraphStyle: para])
            return attr.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                     options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height
        }

        let titleH = measured(displayName, titleFont, contentWidth, spacing: 0)
        let ownerText = "\(person.name)\(person.birthYear.isEmpty ? "" : " · \(person.birthYear)")"
        let ownerH = measured(ownerText, ownerFont, contentWidth, spacing: 0)
        let storyH = measured(storyTrim, storyFont, contentWidth, spacing: 10)

        let topGap: CGFloat = 56
        let belowPhoto: CGFloat = 40
        let belowTitle: CGFloat = 10
        let belowOwner: CGFloat = 26
        let beforeFoot: CGFloat = 46
        let footH: CGFloat = 34
        let bottomPad: CGFloat = 56

        let totalH = pad + topGap * 0.6 + photoH + belowPhoto + titleH + belowTitle + ownerH
            + (storyH > 0 ? belowOwner + storyH : 0) + beforeFoot + footH + bottomPad

        let size = CGSize(width: width, height: totalH)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1          // 按 1080px 出图，微信传输体积友好
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let card = renderer.image { ctx in
            UIColor(red: 0.984, green: 0.969, blue: 0.941, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            var y: CGFloat = pad + topGap * 0.6

            // 照片（圆角）
            let photoRect = CGRect(x: pad, y: y, width: contentWidth, height: photoH)
            let path = UIBezierPath(roundedRect: photoRect, cornerRadius: 16)
            ctx.cgContext.saveGState()
            path.addClip()
            let imgRatio = src.size.width / max(1, src.size.height)
            var drawRect = photoRect
            if imgRatio > contentWidth / photoH {
                let w = photoH * imgRatio
                drawRect = CGRect(x: photoRect.midX - w / 2, y: y, width: w, height: photoH)
            } else {
                let h = contentWidth / imgRatio
                drawRect = CGRect(x: pad, y: y, width: contentWidth, height: h)
            }
            src.draw(in: drawRect)
            ctx.cgContext.restoreGState()
            y = photoRect.maxY + belowPhoto

            let brown = UIColor(red: 0.42, green: 0.29, blue: 0.16, alpha: 1)
            let ink = UIColor(red: 0.23, green: 0.20, blue: 0.16, alpha: 1)
            let muted = UIColor(red: 0.54, green: 0.48, blue: 0.41, alpha: 1)

            // 照片名称
            let titlePara = NSMutableParagraphStyle()
            titlePara.lineSpacing = 6
            let titleAttr = NSAttributedString(string: displayName, attributes: [
                .font: titleFont, .foregroundColor: brown, .paragraphStyle: titlePara])
            let titleRect = CGRect(x: pad, y: y, width: contentWidth,
                                   height: titleAttr.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                                                                  options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height)
            titleAttr.draw(with: titleRect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            y = titleRect.maxY + belowTitle

            // 归属
            let ownerAttr = NSAttributedString(string: ownerText, attributes: [
                .font: ownerFont, .foregroundColor: muted])
            let ownerRect = CGRect(x: pad, y: y, width: contentWidth,
                                   height: ownerAttr.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                                                                  options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height)
            ownerAttr.draw(with: ownerRect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            y = ownerRect.maxY

            // 故事摘录
            if !storyTrim.isEmpty {
                y += belowOwner
                let storyPara = NSMutableParagraphStyle()
                storyPara.lineSpacing = 10
                storyPara.firstLineHeadIndent = 0
                let storyAttr = NSAttributedString(string: storyTrim, attributes: [
                    .font: storyFont, .foregroundColor: ink, .paragraphStyle: storyPara])
                let storyRect = CGRect(x: pad, y: y, width: contentWidth,
                                       height: storyAttr.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                                                                      options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height)
                storyAttr.draw(with: storyRect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                y = storyRect.maxY
            }

            // 页脚
            y = size.height - bottomPad - footH
            let line = UIBezierPath()
            line.move(to: CGPoint(x: pad, y: y - 18))
            line.addLine(to: CGPoint(x: width - pad, y: y - 18))
            UIColor(red: 0.89, green: 0.85, blue: 0.78, alpha: 1).setStroke()
            line.lineWidth = 1
            line.stroke()

            let footText = String(localized: "share.footer")
            let footAttr = NSAttributedString(string: footText, attributes: [
                .font: footFont, .foregroundColor: muted])
            let footSize = footAttr.size()
            footAttr.draw(at: CGPoint(x: (width - footSize.width) / 2, y: y))
        }
        return card
    }

    /// 把长图写成临时 jpg（比 png 小一个数量级），便于走系统分享
    static func writeCard(_ image: UIImage, person: Person, caption: String) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.92) else { return nil }
        let name = PDFExporter.safeFileName(caption.isEmpty ? person.name : caption)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(PDFExporter.safeFileName(person.name))-\(name)-jinian.jpg")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }


    // MARK: 单张照片 PDF（A4，微信可直接预览）

    static func makePhotoPDF(photo: Photo, person: Person, personID: UUID) -> URL? {
        guard let img = MediaStore.loadImage(fileName: photo.imageFileName, personID: personID) else { return nil }

        let pageSize = CGSize(width: 595, height: 842)
        let margin: CGFloat = 46
        let contentWidth = pageSize.width - margin * 2
        let footSpace: CGFloat = 40

        let caption = photo.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = caption.isEmpty ? String(localized: "share.untitled.photo") : caption

        let brown = UIColor(red: 0.42, green: 0.29, blue: 0.16, alpha: 1)
        let ink = UIColor(red: 0.23, green: 0.20, blue: 0.16, alpha: 1)
        let muted = UIColor(red: 0.54, green: 0.48, blue: 0.41, alpha: 1)

        let paragraphs = ArchiveText.splitParagraphs(ArchiveText.normalized(photo.story))
        let storyFont = UIFont.systemFont(ofSize: 11.5)
        let lineSpacing: CGFloat = 4.5

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let data = renderer.pdfData { ctx in
            var y: CGFloat = margin

            func drawFooter() {
                let attr = NSAttributedString(string: String(localized: "share.footer"),
                                              attributes: [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: muted])
                let sz = attr.size()
                attr.draw(at: CGPoint(x: (pageSize.width - sz.width) / 2, y: pageSize.height - 48))
            }

            func beginFreshPage() {
                ctx.beginPage()
                y = margin
            }

            beginFreshPage()

            // 顶部小字
            let kicker = NSAttributedString(string: String(localized: "share.kicker").uppercased(),
                                            attributes: [.font: UIFont.systemFont(ofSize: 8.5),
                                                         .foregroundColor: muted,
                                                         .kern: 1.6])
            kicker.draw(at: CGPoint(x: margin, y: y))
            y += 18

            // 照片（等比填满，超出裁剪）
            let imgRatio = img.size.height / max(1, img.size.width)
            var photoH = contentWidth * imgRatio
            photoH = min(photoH, 470)
            let photoRect = CGRect(x: margin, y: y, width: contentWidth, height: photoH)

            ctx.cgContext.saveGState()
            UIBezierPath(roundedRect: photoRect, cornerRadius: 8).addClip()
            let fillRatio = img.size.width / max(1, img.size.height)
            var drawRect = photoRect
            if fillRatio > contentWidth / photoH {
                let w = photoH * fillRatio
                drawRect = CGRect(x: photoRect.midX - w / 2, y: photoRect.minY, width: w, height: photoH)
            } else {
                let h = contentWidth / fillRatio
                drawRect = CGRect(x: margin, y: photoRect.minY, width: contentWidth, height: h)
            }
            img.draw(in: drawRect)
            ctx.cgContext.restoreGState()
            y = photoRect.maxY + 24

            // 照片名称
            let titlePara = NSMutableParagraphStyle()
            titlePara.lineSpacing = 3
            let titleAttr = NSAttributedString(string: displayName, attributes: [
                .font: UIFont.systemFont(ofSize: 19, weight: .semibold),
                .foregroundColor: brown,
                .paragraphStyle: titlePara
            ])
            let titleH = titleAttr.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                                                options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height
            titleAttr.draw(with: CGRect(x: margin, y: y, width: contentWidth, height: titleH),
                           options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            y += titleH + 5

            // 归属
            let ownerText = "\(person.name)\(person.birthYear.isEmpty ? "" : "  ·  \(person.birthYear)")"
            let ownerAttr = NSAttributedString(string: ownerText, attributes: [
                .font: UIFont.systemFont(ofSize: 10.5), .foregroundColor: muted
            ])
            let ownerH = ownerAttr.size().height
            ownerAttr.draw(at: CGPoint(x: margin, y: y))
            y += ownerH + 20

            // 故事（自动分页）
            for para in paragraphs {
                let style = NSMutableParagraphStyle()
                style.lineSpacing = lineSpacing
                style.alignment = .justified
                style.firstLineHeadIndent = 0
                let attr = NSAttributedString(string: para, attributes: [
                    .font: storyFont, .foregroundColor: ink, .paragraphStyle: style
                ])
                let h = attr.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                                          options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height
                if y + h > pageSize.height - footSpace {
                    drawFooter()
                    beginFreshPage()
                }
                attr.draw(with: CGRect(x: margin, y: y, width: contentWidth, height: h),
                          options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                y += h + 8
            }

            // 结尾引导
            if y + 60 < pageSize.height - footSpace {
                y += 14
                let noteStyle = NSMutableParagraphStyle()
                noteStyle.lineSpacing = 4
                let note = NSAttributedString(string: String(localized: "share.readonly.hint"), attributes: [
                    .font: UIFont.systemFont(ofSize: 10.5), .foregroundColor: muted, .paragraphStyle: noteStyle
                ])
                let nH = note.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                                           options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height
                note.draw(with: CGRect(x: margin, y: y, width: contentWidth, height: nH),
                          options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            }

            drawFooter()
        }

        let name = PDFExporter.safeFileName(displayName)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(PDFExporter.safeFileName(person.name))-\(name).pdf")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    // MARK: 回信解析

    /// 解析亲友回传的文本，返回昵称与留言
    static func parseReply(_ raw: String) -> ShareReply? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // 允许整段复制时带上说明文字
        guard let range = text.range(of: replyPrefix) else {
            // 没有回信码：当作微信里直接发来的一段话
            return parsePlainText(text)
        }
        text = String(text[range.upperBound...])
        text = text.components(separatedBy: .whitespacesAndNewlines).joined()

        guard let data = Data(base64Encoded: text, options: .ignoreUnknownCharacters),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        let name = (obj["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let content = (obj["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else { return nil }

        var date = Date()
        if let ds = obj["date"] as? String {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            if let d = f.date(from: ds) { date = d }
        }

        return ShareReply(name: name?.isEmpty == false ? name! : String(localized: "share.leave.anonymous"),
                          content: content,
                          date: date)
    }

    /// 普通文本：首行形如「张三：想说的话」时拆出昵称，否则整段当作内容
    private static func parsePlainText(_ raw: String) -> ShareReply? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 2000 else { return nil }

        let lines = text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        if let firstLine = lines.first {
            let head = String(firstLine)
            if let sep = head.firstIndex(where: { $0 == "：" || $0 == ":" }) {
                let name = String(head[head.startIndex..<sep]).trimmingCharacters(in: .whitespaces)
                let restOnLine = String(head[head.index(after: sep)...]).trimmingCharacters(in: .whitespaces)
                let tail = lines.count > 1 ? String(lines[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""
                if !name.isEmpty, name.count <= 12,
                   !name.contains("。"), !name.contains("，") {
                    let body = [restOnLine, tail].filter { !$0.isEmpty }.joined(separator: "\n")
                    if !body.isEmpty {
                        return ShareReply(name: name, content: body, date: Date())
                    }
                }
            }
        }
        return ShareReply(name: String(localized: "share.leave.anonymous"),
                          content: text,
                          date: Date())
    }

    // MARK: 文本转义

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// JS 字符串字面量转义
    private static func js(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
