//
//  SettingsView.swift
//  EchoesOfTime
//
//  设置：语言（自动/中文/英文）、模式（编辑/长辈）、大字、数据说明
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @AppStorage("requireFaceID") private var requireFaceID = false
    @AppStorage("familyName") private var familyName = "Family"
    @AppStorage("bgmEnabled") private var bgmEnabled = true
    @Query private var persons: [Person]
    @State private var showLimitAlert = false
    @State private var showUnlockAlert = false
    @State private var versionTapCount = 0

    var body: some View {
        @Bindable var state = appState

        Form {
            Section("settings.section.language") {
                Picker("settings.language", selection: $state.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.segmented)

                Text("settings.language.note")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("settings.section.mode") {
                Picker("settings.mode", selection: $state.mode) {
                    ForEach(AppMode.allCases) { mode in
                        Text(LocalizedStringKey(mode.titleKey)).tag(mode)
                    }
                }
                .pickerStyle(.inline)

                Text("settings.mode.note")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("settings.section.privacy") {
                Toggle("settings.requireFaceID", isOn: $requireFaceID)
                TextField("settings.familyName", text: $familyName)
            }

            Section("settings.section.display") {
                Toggle("settings.largeText", isOn: $state.largeText)
                Toggle("settings.bgm", isOn: $bgmEnabled)
            }

            Section("settings.section.developer") {
                Button("settings.demo.add") {
                    if persons.contains(where: { $0.isDemo }) {
                        showLimitAlert = true
                    } else {
                        DemoData.insert(into: context, language: appState.language)
                    }
                }
            }

            Section("settings.section.data") {
                Text("settings.data.note")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if appState.isDeveloper {
                Section {
                    Toggle("settings.developer.on", isOn: $state.isDeveloper)
                } header: {
                    Text("settings.section.developer.mode")
                } footer: {
                    Text("settings.developer.note")
                        .font(.footnote)
                }
            }

            Section {
                HStack {
                    Text("settings.version")
                    Spacer()
                    Text(Self.versionText)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { unlockIfNeeded() }
            } footer: {
                if !appState.isDeveloper {
                    Text("settings.developer.hint")
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("settings.title")
        .alert("demo.exists.title", isPresented: $showLimitAlert) {
            Button("common.save", role: .cancel) {}
        } message: {
            Text("demo.exists.message")
        }
        .alert("settings.developer.unlocked", isPresented: $showUnlockAlert) {
            Button("common.save", role: .cancel) {}
        }
    }

    // MARK: - 版本号 / 开发者模式解锁

    private static var versionText: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    /// 连点版本号 5 次解锁开发者模式（普通用户不会误触）
    private func unlockIfNeeded() {
        guard !appState.isDeveloper else { return }
        versionTapCount += 1
        if versionTapCount >= 5 {
            versionTapCount = 0
            appState.isDeveloper = true
            showUnlockAlert = true
        }
    }
}
