//
//  PrivacyPolicyView.swift
//  EchoesOfTime
//
//  App 内隐私政策页（中英双语，随界面语言切换）
//

import SwiftUI

struct PrivacyPolicyView: View {

    @Environment(AppState.self) private var appState

    private var isZh: Bool { appState.language == .zhHans }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isZh ? "隐私政策" : "Privacy Policy")
                        .font(.system(size: 26, weight: .bold))
                    Text(isZh ? "最后更新：2026 年 11 月" : "Last updated: November 2026")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Text(summary)
                    .font(.system(size: 15))
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.brown.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                ForEach(sections, id: \.heading) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.heading)
                            .font(.system(size: 16, weight: .semibold))
                        Text(section.body)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Divider()

                Text(isZh
                     ? "如对本政策有疑问，请联系：support@lifememory.life"
                     : "Questions about this policy? Contact us at support@lifememory.life")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .readableCentered()
        }
        .navigationTitle(isZh ? "隐私政策" : "Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 文案

    private var summary: String {
        isZh
        ? "岁月回声把你的内容完全保存在这台设备上。你录入的照片、录音、文字和留言不会被上传、收集或分析；购买由 Apple 通过 App Store 单独处理。"
        : "Echoes of Time keeps your content entirely on this device. The photos, recordings, text and messages you add are never uploaded, collected or analysed. Purchases are handled separately by Apple through the App Store."
    }

    private var sections: [(heading: String, body: String)] {
        isZh ? zhSections : enSections
    }

    private let enSections: [(heading: String, body: String)] = [
        ("What we collect",
         "Nothing. There is no account, no sign-in, no server and no analytics SDK. The app does not contain any third-party tracking, advertising or crash-reporting frameworks. It never sees your payment details, which are handled by Apple."),

        ("Where your content is stored",
         "All archives, images, audio recordings and messages are written to the app's private storage area on this device. The app's data folder is not shared with other apps unless you explicitly export something."),

        ("Device backups",
         "If you have iCloud Backup or a computer backup enabled for this device, iOS may include the app's data in that backup. Those backups are handled by Apple under Apple's terms — we never receive a copy."),

        ("Permissions we ask for",
         "Photos: to pick images from your library. Camera: only when you choose to take a photo in the app. Microphone: only while you record a voice note. Face ID / Touch ID: only to unlock the app when you enable the privacy lock. All of this happens on the device; nothing is sent anywhere."),

        ("Sharing and export",
         "Exporting a PDF or an archive package is always started by you. When you use the share sheet, the exported file leaves the app and is handled by the destination you choose (Files, Mail, AirDrop, etc)."),

        ("In-app purchases",
         "Purchases (Starter, the upgrade pack, or the lifetime Full Version) are processed by Apple through the App Store. The app never receives your card number or payment details. Purchase receipts are held by Apple; the app only checks your current entitlements on-device and uses \"Restore Purchases\" to verify them with Apple. We do not store transaction records and do not handle refunds — refunds are requested through Apple."),

        ("No advertising, no profiling",
         "We do not build profiles, do not track you across apps or websites, and do not sell or share data with anyone."),

        ("Children",
         "The app is intended for adults keeping family memories. It is not directed at children under 13 and collects no personal information from anyone."),

        ("Deleting your data",
         "Deleting an archive inside the app removes its photos and audio immediately. Deleting the app removes all of its data from the device. There is no copy on our side, because we never had one."),

        ("Changes",
         "If this policy changes, the updated version will appear in the app and the date above will be revised.")
    ]

    private let zhSections: [(heading: String, body: String)] = [
        ("我们收集什么",
         "什么都不收集。App 没有账号、没有登录、没有服务器，也没有任何统计 SDK。App 内不含第三方追踪、广告或崩溃上报框架；支付信息由 Apple 处理，App 不接触。"),

        ("内容存在哪里",
         "所有档案、图片、录音和留言，都写入这台设备上 App 自己的私有存储空间。除非你主动导出，否则这些文件不会与其他 App 共享。"),

        ("设备备份",
         "如果你为这台设备开启了 iCloud 备份或电脑备份，iOS 可能会把 App 的数据一并包含在备份中。这类备份由 Apple 按其条款处理，我们不会收到副本。"),

        ("我们申请的权限",
         "相册：用于从图库中选择照片。相机：仅在你选择在 App 内拍照时使用。麦克风：仅在你录制语音旁白时使用。面容 ID / 触控 ID：仅在你开启隐私锁时用于解锁。以上处理全部在设备本地完成，不会发往任何地方。"),

        ("分享与导出",
         "导出 PDF 或档案包始终由你主动发起。使用系统分享面板时，导出文件会离开 App，交由你选择的目标（文件、邮件、隔空投送等）处理。"),

        ("内购与支付",
         "购买（入门版、升级包或完整版买断）由 Apple 通过 App Store 完成，App 不会获取你的卡号或支付信息。购买收据由 Apple 托管，App 只在本机查询当前权益，并通过“恢复购买”向 Apple 校验。我们不存储交易记录，也不处理退款，退款请通过 Apple 申请。"),

        ("无广告、无画像",
         "我们不做用户画像，不跨 App 或网站追踪你，也不向任何人出售或共享数据。"),

        ("儿童",
         "本 App 面向为家人保存记忆的成年人，不面向 13 岁以下儿童，也不向任何人收集个人信息。"),

        ("删除你的数据",
         "在 App 内删除档案会立即删除对应的照片与音频；删除 App 会从设备上清除它的全部数据。我们这边没有副本，因为我们从未持有。"),

        ("政策变更",
         "本政策如有变更，更新后的版本会显示在 App 内，并修订上方的日期。")
    ]
}
