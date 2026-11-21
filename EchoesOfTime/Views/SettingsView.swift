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
    @State private var pm = PurchaseManager.shared
    @State private var showingPaywall = false

    var body: some View {
        @Bindable var state = appState

        Form {
            Section("settings.section.language") {
                NavigationLink {
                    LanguagePickerView()
                } label: {
                    HStack {
                        Text("settings.language")
                        Spacer()
                        Text(appState.language.displayName)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("settings.language.note")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("settings.section.mode") {
                NavigationLink {
                    ModePickerView()
                } label: {
                    HStack {
                        Text("settings.mode")
                        Spacer()
                        Text(LocalizedStringKey(appState.mode.titleKey))
                            .foregroundStyle(.secondary)
                    }
                }

                Text("settings.mode.note")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("settings.section.privacy") {
                Toggle("settings.requireFaceID", isOn: $requireFaceID)
                TextField("settings.familyName", text: $familyName)
            }

            Section("settings.section.premium") {
                HStack {
                    Label("settings.premium.status",
                          systemImage: pm.isPro ? "crown.fill" : "star")
                    Spacer()
                    Text(tierLabel)
                        .foregroundStyle(.secondary)
                }

                if !pm.isPro {
                    Button {
                        showingPaywall = true
                    } label: {
                        Label("settings.premium.upgrade", systemImage: "sparkles")
                    }
                }

                Button {
                    Task { await pm.restore() }
                } label: {
                    Label("settings.premium.restore", systemImage: "arrow.clockwise")
                }
            }

            Section("settings.section.display") {
                Toggle("settings.largeText", isOn: $state.largeText)
                Toggle("settings.bgm", isOn: $bgmEnabled)
            }

            // 备份/迁移：导入档案包，所有用户可用（不依赖开发者模式）
            Section("settings.section.data") {
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

                Text("settings.data.note")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            #if DEBUG
            Section("settings.section.developer") {
                Button("settings.demo.add") {
                    if persons.contains(where: { $0.isDemo }) {
                        showLimitAlert = true
                    } else {
                        DemoData.insert(into: context, language: appState.language)
                    }
                }
            }

            Section {
                Toggle("settings.developer.on", isOn: $state.isDeveloper)
                Text("settings.developer.note")
                    .font(.footnote)
            } header: {
                Text("settings.section.developer.mode")
            }
            #endif

            Section {
                NavigationLink {
                    FaqView()
                } label: {
                    Label("faq.entry", systemImage: "questionmark.circle")
                }

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
                #if DEBUG
                .contentShape(Rectangle())
                .onTapGesture { unlockIfNeeded() }
                #endif
            } footer: {
                #if DEBUG
                if !appState.isDeveloper {
                    Text("settings.developer.hint")
                        .font(.footnote)
                }
                #endif
            }
        }
        .navigationTitle("settings.title")
        .alert("demo.exists.title", isPresented: $showLimitAlert) {
            Button("common.save", role: .cancel) {}
        } message: {
            Text("demo.exists.message")
        }
        #if DEBUG
        .alert("settings.developer.unlocked", isPresented: $showUnlockAlert) {
            Button("common.save", role: .cancel) {}
        }
        #endif
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
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }

    /// 当前付费档位的本地化名称
    private var tierLabel: String {
        switch pm.tier {
        case .pro: return String(localized: "settings.premium.tier.pro")
        case .basic: return String(localized: "settings.premium.tier.basic")
        case .unpaid: return String(localized: "settings.premium.tier.unpaid")
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

    #if DEBUG
    /// 连点版本号 5 次解锁开发者模式（仅 Debug 包可用，Release 无此入口）
    private func unlockIfNeeded() {
        guard !appState.isDeveloper else { return }
        versionTapCount += 1
        if versionTapCount >= 5 {
            versionTapCount = 0
            appState.isDeveloper = true
            showUnlockAlert = true
        }
    }
    #endif
}

// MARK: - 二级：语言选择（苹果式单选列表）

struct LanguagePickerView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        Form {
            ForEach(AppLanguage.allCases) { lang in
                Button {
                    state.language = lang
                } label: {
                    HStack {
                        Text(lang.displayName)
                            .foregroundStyle(.primary)
                        Spacer()
                        if appState.language == lang {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .foregroundStyle(.brown)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("settings.section.language")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 二级：使用模式选择（苹果式单选列表）

struct ModePickerView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        Form {
            ForEach(AppMode.allCases) { mode in
                Button {
                    state.mode = mode
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey(mode.titleKey))
                                .foregroundStyle(.primary)
                            if mode == .reader {
                                Text("settings.mode.note")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if appState.mode == mode {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .foregroundStyle(.brown)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("settings.mode")
        .navigationBarTitleDisplayMode(.inline)
    }
}
