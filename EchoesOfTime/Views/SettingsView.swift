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
            }

            Section("settings.section.developer") {
                Button("settings.demo.add") {
                    DemoData.insert(into: context)
                }
            }

            Section("settings.section.data") {
                Text("settings.data.note")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("settings.title")
    }
}
