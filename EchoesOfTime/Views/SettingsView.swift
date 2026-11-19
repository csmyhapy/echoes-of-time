//
//  SettingsView.swift
//  EchoesOfTime
//
//  设置：语言（自动/中文/英文）、模式（编辑/长辈）、大字、数据说明
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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
    @State private var showImporter = false
    @State private var importReport: String?
    @State private var showImportReport = false
    @State private var isImporting = false

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

                    Button {
                        showImporter = true
                    } label: {
                        HStack {
                            Label("settings.import.archive", systemImage: "square.and.arrow.down")
                            Spacer()
                            if isImporting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isImporting)

                    Text("settings.import.note")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("settings.section.developer.mode")
                } footer: {
                    Text("settings.developer.note")
                        .font(.footnote)
                }
            }

            Section {
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    Label("privacy.title", systemImage: "hand.raised")
                }

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
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.zip],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .alert("settings.import.result", isPresented: $showImportReport) {
            Button("common.save", role: .cancel) {}
        } message: {
            Text(importReport ?? "")
        }
    }

    // MARK: - 导入档案包（开发者 / 迁移用）

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            isImporting = true
            var lines: [String] = []
            for url in urls {
                do {
                    let outcome = try ArchiveImporter.importArchive(at: url, context: context)
                    var line = "\(outcome.personName) · \(outcome.nodeCount) chapters · \(outcome.photoCount) photos"
                    if outcome.skippedPhotos > 0 {
                        line += " · \(outcome.skippedPhotos) missing"
                    }
                    lines.append(line)
                } catch {
                    lines.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
            isImporting = false
            importReport = lines.joined(separator: "\n")
            showImportReport = true

        case .failure(let error):
            isImporting = false
            importReport = error.localizedDescription
            showImportReport = true
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
