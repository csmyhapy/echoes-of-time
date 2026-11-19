//
//  ActivityView.swift
//  EchoesOfTime
//
//  系统分享面板：把导出的 PDF / ZIP 交给「文件 App、iCloud Drive、AirDrop、邮件」等。
//

import SwiftUI
import UIKit

struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    init(url: URL) {
        items = [url]
    }

    /// 一次带上「文字 + 图片」：收信人打开对话会先看到说明，再看图。
    init(items: [Any]) {
        self.items = items
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
