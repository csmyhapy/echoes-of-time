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
                    if persons.isEmpty {
                        DemoData.insert(into: context, language: appState.language)
                    } else {
                        showLimitAlert = true
                    }
                }
            }

            Section("settings.section.data") {
                Text("settings.data.note")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("settings.title")
        .alert("one.archive.limit.title", isPresented: $showLimitAlert) {
            Button("common.save", role: .cancel) {}
        } message: {
            Text("one.archive.limit.message")
        }
    }
}
