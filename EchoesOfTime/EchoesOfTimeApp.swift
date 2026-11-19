//
//  EchoesOfTimeApp.swift
//  EchoesOfTime
//
//  App 入口：本地 SwiftData 容器 + 全局状态
//

import SwiftUI
import SwiftData

@main
struct EchoesOfTimeApp: App {

    @State private var appState = AppState()
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Person.self, Node.self, Photo.self, VoiceNote.self, Message.self
            )
        } catch {
            fatalError("Failed to create local model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(\.locale, Locale(identifier: appState.language.rawValue))
        }
        .modelContainer(container)
    }
}

// MARK: - 根视图

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @State private var lock = PrivacyLock()

    var body: some View {
        ZStack {
            if appState.isReaderMode {
                ReaderRootView()
            } else {
                EditorRootView()
            }

            if lock.isLocked {
                LockScreenView(lock: lock)
            }
        }
        .onAppear {
            lock.lockIfNeeded()
            seedDemoIfNeeded()
            #if DEBUG
            importDebugArchivesIfNeeded()
            applyDebugCoverAndBgm()
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { lock.lockIfNeeded() }
        }
        .onChange(of: appState.language) { _, _ in
            seedDemoIfNeeded()
        }
    }

    /// 首页直接展示示例档案；若唯一档案是另一语言的示例，则换成当前语言的那一份。
    @MainActor
    private func seedDemoIfNeeded() {
        let persons = (try? context.fetch(FetchDescriptor<Person>())) ?? []

        // 兼容旧数据：按名字识别内置示例，补上 isDemo 标记
        var patched = false
        for person in persons where !person.isDemo {
            if DemoData.demoLanguage(of: person) != nil {
                person.isDemo = true
                patched = true
            }
        }
        if patched { try? context.save() }

        // 空库：首次启动放入当前语言的示例档案
        if persons.isEmpty, !UserDefaults.standard.bool(forKey: "demoSeeded") {
            DemoData.insert(into: context, language: appState.language)
            UserDefaults.standard.set(true, forKey: "demoSeeded")
            return
        }

        // 库里只有示例、且语言不匹配：换成当前语言的示例（正式档案不受影响）
        let demos = persons.filter { $0.isDemo }
        if persons.count == 1, demos.count == 1,
           let only = demos.first,
           let demoLanguage = DemoData.demoLanguage(of: only),
           demoLanguage != appState.language {
            MediaStore.deleteFolder(for: only.id)
            context.delete(only)
            try? context.save()
            DemoData.insert(into: context, language: appState.language)
        }
    }

    #if DEBUG
    /// 调试用：把沙盒 Documents 里的 .zip 档案包自动导入，用于核对真实数据的排版
    @MainActor
    private func importDebugArchivesIfNeeded() {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let files = try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil) else { return }
        let zips = files.filter { $0.pathExtension == "zip" }
        guard !zips.isEmpty else { return }

        // 带 reset-import 启动时，先清掉所有正式档案（保留示例），再重新导入
        if ProcessInfo.processInfo.arguments.contains("reset-import") {
            let all = (try? context.fetch(FetchDescriptor<Person>())) ?? []
            for person in all where !person.isDemo {
                MediaStore.deleteFolder(for: person.id)
                context.delete(person)
            }
            try? context.save()
        }

        for url in zips {
            _ = try? ArchiveImporter.importArchive(at: url, context: context)
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// 调试用：验证「设为章节封面」与「BGM 曲名」两条链路
    @MainActor
    func applyDebugCoverAndBgm() {
        let args = ProcessInfo.processInfo.arguments

        if args.contains("debug-set-cover") {
            let persons = (try? context.fetch(FetchDescriptor<Person>())) ?? []
            if let person = persons.first(where: { !$0.isDemo }),
               let node = person.nodes.sorted(by: { $0.sortOrder < $1.sortOrder }).first {
                let photos = person.photos
                    .filter { $0.belongs(to: node) }
                    .sorted { $0.sortOrder < $1.sortOrder }
                if photos.count >= 4 {
                    node.coverImageFileName = photos[3].imageFileName
                    try? context.save()
                }
            }
        }

        if args.contains("debug-test-reply") {
            let payload = #"{"v":1,"person":"戴老师的前半生","photo":"AI生成的小时候照片","name":"李阿姨","text":"看到这张照片就想起你妈妈年轻的时候，真好。","date":"2026-11-18"}"#
            let b64 = Data(payload.utf8).base64EncodedString()
            let raw = ShareExporter.replyPrefix + b64
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            var out = "no parse"
            if let r = ShareExporter.parseReply(raw) {
                out = "name=\(r.name) | content=\(r.content) | date=\(r.date)"
            }
            // 再测一次「微信转发时带说明文字」的情况
            var out2 = "no parse"
            if let r = ShareExporter.parseReply("转发给你的回信：\n" + raw + "\n谢谢！") {
                out2 = "name=\(r.name) | content=\(r.content)"
            }
            var out3 = "no parse"
            if let r = ShareExporter.parseReply("张阿姨：看到这张照片就想起你妈妈年轻的时候，真好。\n那年她还在纺织厂。") {
                out3 = "name=\(r.name) | content=\(r.content)"
            }
            var out4 = "no parse"
            if let r = ShareExporter.parseReply("看到这张照片，我眼泪都下来了。") {
                out4 = "name=\(r.name) | content=\(r.content)"
            }
            try? ([out, "---", out2, "---", out3, "---", out4].joined(separator: "\n")).write(to: docs.appendingPathComponent("debug-reply.txt"),
                                                  atomically: true, encoding: .utf8)
        }

        if args.contains("debug-share") {
            let persons = (try? context.fetch(FetchDescriptor<Person>())) ?? []
            if let person = persons.first(where: { !$0.isDemo }),
               let photo = person.photos.sorted(by: { $0.sortOrder < $1.sortOrder }).first {
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                if let page = ShareExporter.makePage(photo: photo, person: person, personID: person.id) {
                    try? FileManager.default.removeItem(at: docs.appendingPathComponent("debug-share.html"))
                    try? FileManager.default.copyItem(at: page, to: docs.appendingPathComponent("debug-share.html"))
                }
                if let card = ShareExporter.makeCard(photo: photo, person: person, personID: person.id),
                   let cardURL = ShareExporter.writeCard(card, person: person, caption: photo.caption) {
                    try? FileManager.default.removeItem(at: docs.appendingPathComponent("debug-card.jpg"))
                    try? FileManager.default.copyItem(at: cardURL, to: docs.appendingPathComponent("debug-card.jpg"))
                }
                if let pdf = ShareExporter.makePhotoPDF(photo: photo, person: person, personID: person.id) {
                    try? FileManager.default.removeItem(at: docs.appendingPathComponent("debug-page.pdf"))
                    try? FileManager.default.copyItem(at: pdf, to: docs.appendingPathComponent("debug-page.pdf"))
                }
            }
        }

        if args.contains("debug-set-bgm") {
            let persons = (try? context.fetch(FetchDescriptor<Person>())) ?? []
            if let person = persons.first(where: { !$0.isDemo }) {
                if person.bgmFileName == nil,
                   let demo = Bundle.main.url(forResource: "bgm_demo", withExtension: "m4a"),
                   let name = MediaStore.saveAudioFile(from: demo, personID: person.id) {
                    person.bgmFileName = name
                }
                person.bgmTitle = "岁月回声（原站默认曲）"
                try? context.save()
            }
        }
    }
    #endif
}

// MARK: - 编辑模式（子女使用）

struct EditorRootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                LibraryView()
            }
            .tabItem {
                Label("tab.library", systemImage: "books.vertical")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("tab.settings", systemImage: "gearshape")
            }
        }
    }
}

// MARK: - 长辈浏览模式（超大字号、只读）

struct ReaderRootView: View {
    var body: some View {
        NavigationStack {
            LibraryView(isReader: true)
        }
    }
}
