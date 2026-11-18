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
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
