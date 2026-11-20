//
//  PDFExporter.swift
//  EchoesOfTime
//
//  把一份人物档案渲染成 PDF 回忆册：
//  封面 → 简介/人生故事 → 每个章节（章节页 + 每张照片一页）
//

import UIKit

enum PDFExporter {

    /// PDF 导出总开关：效果打磨完成前置 false（隐藏所有 PDF 入口），做好后改 true 恢复。
    static let featureEnabled = false

    @MainActor
    static func makePDF(for person: Person) -> URL? {
        AlbumBookRenderer.render(person: person)
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
        .head{margin:0 0 22px;padding:20px 22px;border:1px solid var(--line);border-left:3px solid var(--brown);
             background:#fff;border-radius:0 14px 14px 0;}
        .head h2{font-size:15px;letter-spacing:.14em;color:var(--brown);margin:0 0 12px;font-weight:600;}
        .head p{font-size:14.5px;line-height:1.9;color:#5E5347;margin:0;text-align:justify;text-indent:2em;}
        .head p + p{margin-top:0.57em;}   /* 段间距 ≈ 行距 × 1.3，不空行 */
        .photo{width:100%;height:auto;display:block;border-radius:14px;box-shadow:0 8px 26px rgba(80,55,30,.13);}
        h1{font-size:26px;line-height:1.3;margin:22px 0 6px;color:var(--brown);font-weight:700;}
        .owner{font-size:14px;color:#8A7C6B;margin:0 0 18px;}
        .story p{font-size:16.5px;line-height:1.85;margin:0 0 14px;text-align:justify;text-indent:2em;}
        .story p:first-child{margin-top:0;}
        .audio{margin:22px 0 6px;padding:14px 16px;border:1px solid var(--line);border-radius:12px;background:#fff;}
        .audio .label{display:block;font-size:12px;letter-spacing:.12em;color:var(--brown);opacity:.8;margin-bottom:8px;}
        .audio audio{width:100%;}
        .note{margin-top:34px;padding:18px 20px;border-left:3px solid var(--brown);
             background:#fff;border-radius:0 12px 12px 0;font-size:14.5px;line-height:1.85;color:#5E5347;}
        .note strong{display:block;color:var(--brown);font-size:13px;letter-spacing:.08em;margin-bottom:10px;}
        .note p{margin:0 0 10px;}
        .note p:last-child{margin-bottom:0;}
        footer{margin-top:34px;text-align:center;color:#A89B8A;}
        footer span{display:block;}
        .brand{font-size:12px;letter-spacing:.1em;}
        .slogan{font-size:13px;color:var(--brown);opacity:.85;margin-top:6px;}
        .by{font-size:11px;margin-top:6px;opacity:.8;}
        @media print{body{background:#fff}.note{break-inside:avoid}}
        </style>
        </head>
        <body>
        <div class="wrap">
          <div class="head">
            <h2>\(esc(String(localized: "share.head.title")))</h2>
            <p>\(esc(String(format: String(localized: "share.head.p1"), person.name)))</p>
            <p>\(esc(String(localized: "share.head.p2")))</p>
          </div>
          <img class="photo" alt="\(esc(displayName))" src="data:image/jpeg;base64,\(jpeg.base64EncodedString())">
          <h1>\(esc(displayName))</h1>
          <p class="owner">\(esc(person.name))\(person.birthYear.isEmpty ? "" : " · \(esc(person.birthYear))")</p>
          \(storyBlock)
          \(audioBlock)

          <footer>
            <span class="brand">\(esc(String(localized: "share.footer")))</span>
            <span class="slogan">\(esc(String(localized: "share.brand.slogan")))</span>
            <span class="by">\(esc(String(localized: "share.brand.by")))</span>
          </footer>
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


    private static func bodyAttrDraw(_ text: String, _ font: UIFont, _ color: UIColor,
                                     _ para: NSMutableParagraphStyle, _ x: CGFloat, _ y: CGFloat,
                                     _ w: CGFloat, _ h: CGFloat) {
        let attr = NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: para
        ])
        attr.draw(with: CGRect(x: x, y: y, width: w, height: h),
                  options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
    }

    /// 纯文字卡：微信的系统分享只接收图片、会丢弃文字，
    /// 所以把这段说明单独排成一张竖版卡，和照片卡一起发出去，两条都能进对话。
    static func makeNoteCard(person: Person) -> UIImage? {
        let width: CGFloat = 1080
        let pad: CGFloat = 104
        let contentWidth = width - pad * 2

        let titleFont = UIFont.systemFont(ofSize: 40, weight: .semibold)
        let bodyFont = UIFont.systemFont(ofSize: 35)
        let brandFont = UIFont.systemFont(ofSize: 25)
        let sloganFont = UIFont.systemFont(ofSize: 22)

        let titleText = String(localized: "share.head.title")
        let bodyText = [
            String(format: String(localized: "share.head.p1"), person.name),
            String(localized: "share.head.p2")
        ].joined(separator: "\n\n")
        let brandText = String(localized: "share.footer")
        let sloganText = String(localized: "share.brand.slogan")

        func measured(_ text: String, _ font: UIFont, spacing: CGFloat) -> CGFloat {
            let para = NSMutableParagraphStyle()
            para.lineSpacing = spacing
            let attr = NSAttributedString(string: text, attributes: [.font: font, .paragraphStyle: para])
            return attr.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                                     options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height
        }

        let titleH = measured(titleText, titleFont, spacing: 0)
        let bodyH = measured(bodyText, bodyFont, spacing: 18)
        let brandH = measured(brandText, brandFont, spacing: 0)
        let sloganH = measured(sloganText, sloganFont, spacing: 4)

        // 内容块整体高度（标题—细线—正文—品牌两行）
        let contentH = titleH + 34 + 44 + bodyH + 62 + brandH + 8 + sloganH
        // 竖版 4:5，微信里缩略大、字更大；内容少时上下留白，内容多时按需加长
        let totalH = max(contentH + 200, width * 1.25)
        let startY = (totalH - contentH) / 2

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: totalH), format: format)
        return renderer.image { ctx in
            UIColor(red: 0.984, green: 0.969, blue: 0.941, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: totalH))

            let brown = UIColor(red: 0.42, green: 0.29, blue: 0.16, alpha: 1)
            let ink = UIColor(red: 0.23, green: 0.20, blue: 0.16, alpha: 1)
            let muted = UIColor(red: 0.54, green: 0.48, blue: 0.41, alpha: 1)
            let hairline = UIColor(red: 0.89, green: 0.85, blue: 0.78, alpha: 1)

            var y: CGFloat = startY

            let titleAttr = NSAttributedString(string: titleText, attributes: [
                .font: titleFont, .foregroundColor: brown, .kern: 3
            ])
            titleAttr.draw(at: CGPoint(x: pad, y: y))
            y += titleH + 34 - 16

            let rule = UIBezierPath()
            rule.move(to: CGPoint(x: pad, y: y))
            rule.addLine(to: CGPoint(x: width - pad, y: y))
            hairline.setStroke()
            rule.lineWidth = 1.5
            rule.stroke()
            y += 44

            let bodyPara = NSMutableParagraphStyle()
            bodyPara.lineSpacing = 18
            bodyAttrDraw(bodyText, bodyFont, ink, bodyPara, pad, y, contentWidth, bodyH)
            y += bodyH + 62

            let brandAttr = NSAttributedString(string: brandText, attributes: [
                .font: brandFont, .foregroundColor: brown, .kern: 1.2
            ])
            brandAttr.draw(at: CGPoint(x: pad, y: y))
            y += brandH + 8

            let sloganPara = NSMutableParagraphStyle()
            sloganPara.lineSpacing = 4
            let sloganAttr = NSAttributedString(string: sloganText, attributes: [
                .font: sloganFont, .foregroundColor: muted, .paragraphStyle: sloganPara
            ])
            sloganAttr.draw(with: CGRect(x: pad, y: y, width: contentWidth, height: sloganH),
                            options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        }
    }

    static func makeCard(photo: Photo, person: Person, personID: UUID) -> UIImage? {
        guard let img = MediaStore.loadImage(fileName: photo.imageFileName, personID: personID),
              let jpeg = img.jpegData(compressionQuality: 0.9) else { return nil }

        let width: CGFloat = 1080
        let pad: CGFloat = 72
        let contentWidth = width - pad * 2

        let src = UIImage(data: jpeg) ?? img
        let ratio = src.size.height / max(1, src.size.width)
        var photoH = contentWidth * ratio
        photoH = min(photoH, 620)   // 说明用大字占位后，照片让出一部分高度

        let caption = photo.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = caption.isEmpty ? String(localized: "share.untitled.photo") : caption

        let titleFont = UIFont.systemFont(ofSize: 46, weight: .semibold)
        let ownerFont = UIFont.systemFont(ofSize: 26)
        let storyFont = UIFont.systemFont(ofSize: 29)
        let headTitleFont = UIFont.systemFont(ofSize: 36, weight: .semibold)
        let headFont = UIFont.systemFont(ofSize: 30)     // 大字，读起来不费力
        let sloganFont = UIFont.systemFont(ofSize: 23)

        let storyText = ArchiveText.paragraphs(photo.story)
        let storyTrim = storyText.count > 220 ? String(storyText.prefix(220)) + "…" : storyText
        let headText = [
            String(format: String(localized: "share.head.p1"), person.name),
            String(localized: "share.head.p2")
        ].joined(separator: "\n")          // 段间不空行，靠段间距区分
        let sloganText = String(localized: "share.brand.slogan")

        func measured(_ text: String, _ font: UIFont, _ width: CGFloat, spacing: CGFloat,
                      paraSpacing: CGFloat = 0, indent: CGFloat = 0) -> CGFloat {
            guard !text.isEmpty else { return 0 }
            let para = NSMutableParagraphStyle()
            para.lineSpacing = spacing
            para.paragraphSpacing = paraSpacing
            para.firstLineHeadIndent = indent
            let attr = NSAttributedString(string: text, attributes: [.font: font, .paragraphStyle: para])
            return attr.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                     options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height
        }

        let titleH = measured(displayName, titleFont, contentWidth, spacing: 6)
        let ownerText = "\(person.name)\(person.birthYear.isEmpty ? "" : " · \(person.birthYear)")"
        let ownerH = measured(ownerText, ownerFont, contentWidth, spacing: 0)
        let storyH = measured(storyTrim, storyFont, contentWidth, spacing: 10)
        let headTitleH = measured(String(localized: "share.head.title"), headTitleFont, contentWidth, spacing: 0)
        // 行距 10（≈1.33em），段间距取其 1.3 倍；首行缩进 2 字符
        let headH = measured(headText, headFont, contentWidth, spacing: 10,
                             paraSpacing: 14, indent: headFont.pointSize * 2)
        let sloganH = measured(sloganText, sloganFont, contentWidth, spacing: 4)

        let topPad: CGFloat = 66
        let headTitleGap: CGFloat = 18
        let afterHead: CGFloat = 40
        let belowPhoto: CGFloat = 40
        let belowTitle: CGFloat = 10
        let belowOwner: CGFloat = 24
        let brandGap: CGFloat = 44
        let brandH: CGFloat = 40
        let bottomPad: CGFloat = 80

        let totalH = topPad + headTitleH + headTitleGap + headH + afterHead
            + photoH + belowPhoto + titleH + belowTitle + ownerH
            + (storyH > 0 ? belowOwner + storyH : 0)
            + brandGap + brandH + sloganH + bottomPad

        let size = CGSize(width: width, height: totalH)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let card = renderer.image { ctx in
            UIColor(red: 0.984, green: 0.969, blue: 0.941, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let brown = UIColor(red: 0.42, green: 0.29, blue: 0.16, alpha: 1)
            let ink = UIColor(red: 0.23, green: 0.20, blue: 0.16, alpha: 1)
            let muted = UIColor(red: 0.54, green: 0.48, blue: 0.41, alpha: 1)
            let hairline = UIColor(red: 0.89, green: 0.85, blue: 0.78, alpha: 1)

            var y: CGFloat = topPad

            // ---------- 头部说明（大字）----------
            let headTitleAttr = NSAttributedString(string: String(localized: "share.head.title"), attributes: [
                .font: headTitleFont, .foregroundColor: brown, .kern: 2.4
            ])
            headTitleAttr.draw(at: CGPoint(x: pad, y: y))
            y += headTitleH + headTitleGap - 8

            let rule1 = UIBezierPath()
            rule1.move(to: CGPoint(x: pad, y: y))
            rule1.addLine(to: CGPoint(x: width - pad, y: y))
            hairline.setStroke()
            rule1.lineWidth = 1
            rule1.stroke()
            y += 26

            let headPara = NSMutableParagraphStyle()
            headPara.lineSpacing = 10
            headPara.paragraphSpacing = 14                                  // 段间距 ≈ 行间距 × 1.3
            headPara.firstLineHeadIndent = headFont.pointSize * 2           // 段首空两格
            let headAttr = NSAttributedString(string: headText, attributes: [
                .font: headFont, .foregroundColor: ink, .paragraphStyle: headPara
            ])
            headAttr.draw(with: CGRect(x: pad, y: y, width: contentWidth, height: headH),
                          options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            y += headH + afterHead

            // ---------- 照片 ----------
            let photoRect = CGRect(x: pad, y: y, width: contentWidth, height: photoH)
            ctx.cgContext.saveGState()
            UIBezierPath(roundedRect: photoRect, cornerRadius: 16).addClip()
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

            // ---------- 照片名称 ----------
            let titlePara = NSMutableParagraphStyle()
            titlePara.lineSpacing = 6
            let titleAttr = NSAttributedString(string: displayName, attributes: [
                .font: titleFont, .foregroundColor: brown, .paragraphStyle: titlePara])
            titleAttr.draw(with: CGRect(x: pad, y: y, width: contentWidth, height: titleH),
                           options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            y += titleH + belowTitle

            // ---------- 归属 ----------
            let ownerAttr = NSAttributedString(string: ownerText, attributes: [
                .font: ownerFont, .foregroundColor: muted])
            ownerAttr.draw(at: CGPoint(x: pad, y: y))
            y += ownerH

            // ---------- 故事 ----------
            if storyH > 0 {
                y += belowOwner
                let storyPara = NSMutableParagraphStyle()
                storyPara.lineSpacing = 10
                let storyAttr = NSAttributedString(string: storyTrim, attributes: [
                    .font: storyFont, .foregroundColor: ink, .paragraphStyle: storyPara])
                storyAttr.draw(with: CGRect(x: pad, y: y, width: contentWidth, height: storyH),
                               options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                y += storyH
            }

            // ---------- 品牌 ----------
            y += brandGap
            let rule2 = UIBezierPath()
            rule2.move(to: CGPoint(x: pad, y: y - 18))
            rule2.addLine(to: CGPoint(x: width - pad, y: y - 18))
            hairline.setStroke()
            rule2.lineWidth = 1
            rule2.stroke()

            let brandAttr = NSAttributedString(string: String(localized: "share.footer"), attributes: [
                .font: UIFont.systemFont(ofSize: 28, weight: .medium),
                .foregroundColor: brown,
                .kern: 1.2
            ])
            brandAttr.draw(at: CGPoint(x: pad, y: y))
            y += brandH

            let sloganPara = NSMutableParagraphStyle()
            sloganPara.lineSpacing = 4
            let sloganAttr = NSAttributedString(string: sloganText, attributes: [
                .font: sloganFont, .foregroundColor: muted, .paragraphStyle: sloganPara])
            sloganAttr.draw(with: CGRect(x: pad, y: y, width: contentWidth, height: sloganH),
                            options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
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


            func beginFreshPage() {
                ctx.beginPage()
                y = margin
            }

            beginFreshPage()

            // 头部说明：这是为你留下的一张照片
            let headTitle = NSAttributedString(string: String(localized: "share.head.title"), attributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: brown,
                .kern: 1.6
            ])
            headTitle.draw(at: CGPoint(x: margin, y: y))
            y += 20

            let headStyle = NSMutableParagraphStyle()
            headStyle.lineSpacing = 5.5                 // 10pt 字，行距 ≈ 1.55 倍
            headStyle.paragraphSpacing = 6              // 段间距 ≈ 行间距 × 1.3
            headStyle.firstLineHeadIndent = 20          // 段首空两格（10pt × 2）
            headStyle.alignment = .justified
            let headBody = [
                String(format: String(localized: "share.head.p1"), person.name),
                String(localized: "share.head.p2")
            ].joined(separator: "\n")
            let headAttr = NSAttributedString(string: headBody, attributes: [
                .font: UIFont.systemFont(ofSize: 10), .foregroundColor: muted, .paragraphStyle: headStyle
            ])
            let headH = headAttr.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                                              options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height
            headAttr.draw(with: CGRect(x: margin, y: y, width: contentWidth, height: headH),
                          options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            y += headH + 16

            let headRule = UIBezierPath()
            headRule.move(to: CGPoint(x: margin, y: y))
            headRule.addLine(to: CGPoint(x: pageSize.width - margin, y: y))
            UIColor(red: 0.89, green: 0.85, blue: 0.78, alpha: 1).setStroke()
            headRule.lineWidth = 0.8
            headRule.stroke()
            y += 20

            // 照片（等比填满，超出裁剪）
            let imgRatio = img.size.height / max(1, img.size.width)
            var photoH = contentWidth * imgRatio
            photoH = min(photoH, 360)
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
                    beginFreshPage()
                }
                attr.draw(with: CGRect(x: margin, y: y, width: contentWidth, height: h),
                          options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                y += h + 8
            }

            // 品牌区：跟随内容，但不越过页脚安全区
            let brandY = min(y + 64, pageSize.height - 118)

            let brandNameAttr = NSAttributedString(string: String(localized: "share.footer"), attributes: [
                .font: UIFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: brown, .kern: 0.8
            ])
            let szBrand = brandNameAttr.size()
            brandNameAttr.draw(at: CGPoint(x: (pageSize.width - szBrand.width) / 2, y: brandY))

            let sloganAttr = NSAttributedString(string: String(localized: "share.brand.slogan"), attributes: [
                .font: UIFont.systemFont(ofSize: 9), .foregroundColor: brown.withAlphaComponent(0.85)
            ])
            let szSlogan = sloganAttr.size()
            sloganAttr.draw(at: CGPoint(x: (pageSize.width - szSlogan.width) / 2, y: brandY + 18))

            let byAttr = NSAttributedString(string: String(localized: "share.brand.by"), attributes: [
                .font: UIFont.systemFont(ofSize: 8.5), .foregroundColor: muted
            ])
            let szBy = byAttr.size()
            byAttr.draw(at: CGPoint(x: (pageSize.width - szBy.width) / 2, y: brandY + 36))
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

import SwiftUI

// MARK: - 画册式 PDF 渲染（路线 A：SwiftUI 版面 + ImageRenderer 逐页拼 PDF）

/// 页面尺寸：A4 竖版（pt）
private enum AlbumLayout {
    static let w: CGFloat = 595
    static let h: CGFloat = 842
    static let margin: CGFloat = 56
    static let brown = UIColor(red: 0.42, green: 0.29, blue: 0.16, alpha: 1)
    static let paper = UIColor(red: 0.986, green: 0.978, blue: 0.96, alpha: 1)
}

private enum AlbumBookRenderer {

    /// 章节排序：webOrder（网站顺序，缺失则全0）→ 年代起始年 → sortOrder → 创建时间
    private static func nodeLess(_ a: Node, _ b: Node) -> Bool {
        let wa = a.webOrder == 0 ? Int.max : a.webOrder
        let wb = b.webOrder == 0 ? Int.max : b.webOrder
        if wa != wb { return wa < wb }
        let ya = startYear(a.yearRange), yb = startYear(b.yearRange)
        if ya != yb { return ya < yb }
        if a.sortOrder != b.sortOrder { return a.sortOrder < b.sortOrder }
        return a.createdAt < b.createdAt
    }

    /// 从年代串（"1973-1980" / "2008年至今"）取开头四位年份，取不到给 9999
    private static func startYear(_ s: String) -> Int {
        let digits = s.filter { $0.isNumber }
        let four = String(digits.prefix(4))
        return Int(four) ?? 9999
    }

    @MainActor
    static func render(person: Person) -> URL? {
        let nodes = person.nodes.filter { $0.isVisible }
            .sorted { nodeLess($0, $1) }

        // 通用页单元
        enum Page {
            case cover, toc
            case lifeStory([String], String)
            case divider(Node)
            case chapterStory(Node, [String], String)
            case photo(Node, Photo)
            case closing
        }

        let contentWidth = AlbumLayout.w - AlbumLayout.margin * 2
        let bodyFont = UIFont.systemFont(ofSize: 15)
        let bodyLine: CGFloat = 8
        let storyMaxHeight: CGFloat = 620

        var pages: [Page] = [.cover, .toc]

        // 人生总述（流动分页，落款只放最后一页）
        let lifeBody = ArchiveText.parse(person.story)
        let lifeChunks = Self.paginate(lifeBody.paragraphs, width: contentWidth, font: bodyFont, lineSpacing: bodyLine, maxHeight: storyMaxHeight)
        for (idx, chunk) in lifeChunks.enumerated() {
            let sig = idx == lifeChunks.count - 1 ? lifeBody.signature : ""
            pages.append(.lifeStory(chunk, sig))
        }

        for node in nodes {
            pages.append(.divider(node))
            let chBody = ArchiveText.parse(node.story)
            let chChunks = Self.paginate(chBody.paragraphs, width: contentWidth, font: bodyFont, lineSpacing: bodyLine, maxHeight: storyMaxHeight)
            for (idx, chunk) in chChunks.enumerated() {
                let sig = idx == chChunks.count - 1 ? chBody.signature : ""
                pages.append(.chapterStory(node, chunk, sig))
            }
            let photos = person.photos.filter { $0.belongs(to: node) }
                .sorted { $0.sortOrder < $1.sortOrder }
            for photo in photos {
                pages.append(.photo(node, photo))
            }
        }
        pages.append(.closing)

        // 两遍法：统计每个章节分隔页的全局页码（从 1 计）
        var dividerPage: [UUID: Int] = [:]
        for (idx, p) in pages.enumerated() {
            if case .divider(let n) = p { dividerPage[n.id] = idx + 1 }
        }

        var images: [UIImage] = []
        for (i, p) in pages.enumerated() {
            let pageNo = i + 1
            switch p {
            case .cover:
                images.append(shot(PageFrame(page: nil) { CoverView(person: person) }))
            case .toc:
                images.append(shot(PageFrame(page: nil) { TableOfContentsView(nodes: nodes, dividerPage: dividerPage) }))
            case .lifeStory(let paras, let sig):
                images.append(shot(PageFrame(page: pageNo) { StoryPageView(eyebrow: "LIFE STORY", title: "人生故事", paragraphs: paras, signature: sig) }))
            case .divider(let node):
                images.append(shot(PageFrame(page: pageNo) { DividerView(node: node) }))
            case .chapterStory(let node, let paras, let sig):
                images.append(shot(PageFrame(page: pageNo) { StoryPageView(eyebrow: node.yearRange, title: node.name, paragraphs: paras, signature: sig) }))
            case .photo(let node, let photo):
                images.append(shot(PageFrame(page: pageNo) { PhotoBlockView(node: node, photo: photo, person: person) }))
            case .closing:
                images.append(shot(PageFrame(page: nil) { ClosingView(person: person) }))
            }
        }

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: AlbumLayout.w, height: AlbumLayout.h))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(PDFExporter.safeFileName(person.name)).pdf")
        do {
            let data = renderer.pdfData { ctx in
                for img in images {
                    ctx.beginPage()
                    // JPEG 压缩每页位图，控制整体体积
                    let compressed = img.jpegData(compressionQuality: 0.8)
                        .flatMap { UIImage(data: $0) } ?? img
                    compressed.draw(in: CGRect(x: 0, y: 0, width: AlbumLayout.w, height: AlbumLayout.h))
                }
            }
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    /// 测量一段文字在给定宽度下的排版高度
    private static func blockHeight(_ text: String, font: UIFont, width: CGFloat, lineSpacing: CGFloat) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: style]
        return NSAttributedString(string: text, attributes: attrs).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil
        ).height
    }

    /// 把段落流按页高切块：整块段落不拆，排满一页再开新页
    private static func paginate(_ paragraphs: [String], width: CGFloat, font: UIFont,
                                 lineSpacing: CGFloat, maxHeight: CGFloat) -> [[String]] {
        var pages: [[String]] = []
        var current: [String] = []
        var used: CGFloat = 0
        for p in paragraphs {
            let h = blockHeight(p, font: font, width: width, lineSpacing: lineSpacing)
            if !current.isEmpty, used + h + 14 > maxHeight {
                pages.append(current)
                current = [p]
                used = h
            } else {
                current.append(p)
                used += h + 14
            }
        }
        if !current.isEmpty { pages.append(current) }
        return pages
    }

    @MainActor
    private static func shot<V: View>(_ view: V) -> UIImage {
        let renderer = ImageRenderer(
            content: view.frame(width: AlbumLayout.w, height: AlbumLayout.h)
                .background(Color(uiColor: AlbumLayout.paper))
        )
        renderer.scale = 1.5
        return renderer.uiImage ?? UIImage()
    }
}

// MARK: 版面视图

/// 封面：居中方图 + 姓名 + 生卒年 + 定位语
private struct CoverView: View {
    let person: Person
    var body: some View {
        VStack(spacing: 26) {
            Spacer().frame(height: 110)
            if let img = MediaStore.loadImage(fileName: person.resolvedCoverFileName, personID: person.id) {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 300, height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 6)
            }
            Text(person.name)
                .font(.system(size: 38, weight: .bold))
            if !person.birthYear.isEmpty {
                Text(person.birthYear)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            if !person.summary.isEmpty {
                Text(person.summary)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 56)
                    .lineSpacing(6)
            }
            Spacer()
            Text("Echoes of Time · 回忆画册")
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .padding(.bottom, 40)
        }
        .frame(width: AlbumLayout.w, height: AlbumLayout.h)
    }
}

/// 目录：章节名 + 年份 + 页码
private struct TableOfContentsView: View {
    let nodes: [Node]
    let dividerPage: [UUID: Int]
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("目录")
                .font(.system(size: 30, weight: .bold))
                .padding(.bottom, 8)
            ForEach(nodes, id: \.id) { n in
                HStack(alignment: .firstTextBaseline) {
                    Text(n.name).font(.system(size: 17))
                    if !n.yearRange.isEmpty {
                        Text(n.yearRange)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("\(dividerPage[n.id] ?? 0)")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                Divider()
            }
            Spacer()
        }
        .padding(AlbumLayout.margin)
        .frame(width: AlbumLayout.w, height: AlbumLayout.h)
    }
}

/// 章节分隔页：居中大标题 + 年份 + 引言
private struct DividerView: View {
    let node: Node
    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Text(node.name)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(Color(uiColor: AlbumLayout.brown))
            if !node.yearRange.isEmpty {
                Text(node.yearRange)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            if !node.summary.isEmpty {
                Text(node.summary)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 56)
                    .padding(.top, 8)
            }
            Spacer()
        }
        .frame(width: AlbumLayout.w, height: AlbumLayout.h)
    }
}

/// 照片块：图居中（宽 50%~100% 自适应）+ 标题 + 旁白，整块同页不隔页
private struct PhotoBlockView: View {
    let node: Node
    let photo: Photo
    let person: Person
    var body: some View {
        VStack(spacing: 16) {
            if let img = MediaStore.loadImage(fileName: photo.imageFileName, personID: person.id) {
                let ratio = img.size.width / max(img.size.height, 1)
                // 横图近满宽，竖图收窄，限制在 50%~95%
                let widthRatio: CGFloat = ratio >= 1.0 ? 0.95 : (ratio >= 0.8 ? 0.74 : 0.58)
                Image(uiImage: img)
                    .resizable().scaledToFit()
                    .frame(width: AlbumLayout.w * widthRatio)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 4)
            }
            if !photo.caption.isEmpty {
                Text(photo.caption)
                    .font(.system(size: 18, weight: .semibold))
            }
            let story = ArchiveText.clean(photo.story)
            if !story.isEmpty {
                Text(story)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AlbumLayout.margin)
            }
            Spacer()
        }
        .padding(.horizontal, AlbumLayout.margin)
        .padding(.top, 64)
        .frame(width: AlbumLayout.w, height: AlbumLayout.h)
    }
}

private struct ClosingView: View {
    let person: Person
    var body: some View {
        VStack {
            Spacer()
            Text("— 完 —")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(width: AlbumLayout.w, height: AlbumLayout.h)
    }
}

/// 长文故事页：眉标 + 标题 + 流动段落（已按页切块）+ 页尾落款
private struct StoryPageView: View {
    let eyebrow: String
    let title: String
    let paragraphs: [String]
    var signature: String = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !eyebrow.isEmpty {
                Text(eyebrow)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(uiColor: AlbumLayout.brown))
            }
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.black)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(paragraphs, id: \.self) { p in
                    Text(p)
                        .font(.system(size: 15))
                        .lineSpacing(8)
                        .foregroundColor(.black.opacity(0.85))
                }
            }
            if !signature.isEmpty {
                Spacer().frame(height: 20)
                Text(signature)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            Spacer()
        }
        .padding(AlbumLayout.margin)
        .padding(.top, 72)
        .frame(width: AlbumLayout.w, height: AlbumLayout.h)
    }
}

/// 页脚容器：可选居中页码（封面/目录/尾页不传页码）
private struct PageFrame<Content: View>: View {
    let page: Int?
    @ViewBuilder let content: Content
    var body: some View {
        ZStack(alignment: .bottom) {
            content
            if let page {
                Text("\(page)")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .padding(.bottom, 22)
            }
        }
        .frame(width: AlbumLayout.w, height: AlbumLayout.h)
    }
}


