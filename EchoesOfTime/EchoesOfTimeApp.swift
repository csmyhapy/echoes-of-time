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
        .onAppear { lock.lockIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { lock.lockIfNeeded() }
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
