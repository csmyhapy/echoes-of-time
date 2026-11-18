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

        // 空库：自动放入当前语言的示例档案（仅首次启动）
        if persons.isEmpty, !UserDefaults.standard.bool(forKey: "demoSeeded") {
            DemoData.insert(into: context, language: appState.language)
            UserDefaults.standard.set(true, forKey: "demoSeeded")
            return
        }

        // 唯一档案仍是另一种语言的示例：替换为当前语言版本
        if persons.count == 1,
           let only = persons.first,
           let demoLanguage = DemoData.demoLanguage(of: only),
           demoLanguage != appState.language {
            MediaStore.deleteFolder(for: only.id)
            context.delete(only)
            try? context.save()
            DemoData.insert(into: context, language: appState.language)
        }
    }
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
