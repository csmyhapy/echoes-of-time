//
//  NodeEditView.swift
//  EchoesOfTime
//
//  新建 / 编辑章节（标题、年代、简介、故事、封面）
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct NodeEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let person: Person
    /// nil 表示新建
    let node: Node?

    @State private var name = ""
    @State private var yearRange = ""
    @State private var summary = ""
    @State private var story = ""
    @State private var isVisible = true
    @State private var coverImage: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var newID = UUID()
    @State private var loaded = false

    private var isNew: Bool { node == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("edit.node.section.basics") {
                    Menu {
                        ForEach(ChapterSuggestions.keys, id: \.self) { key in
                            Button(suggestedTitle(key)) {
                                name = suggestedTitle(key)
                            }
                        }
                    } label: {
                        Label("edit.node.suggest", systemImage: "text.badge.plus")
                    }

                    TextField("edit.node.name", text: $name)
                    TextField("edit.node.yearRange", text: $yearRange)
                    Toggle("edit.node.visible", isOn: $isVisible)
                }

                Section("edit.node.section.summary") {
                    TextField("edit.node.summary", text: $summary, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("edit.node.section.story") {
                    TextField("edit.node.story", text: $story, axis: .vertical)
                        .lineLimit(6...14)
                }

                Section("edit.node.section.cover") {
                    coverPicker
                }
            }
            .navigationTitle(isNew ? "edit.node.new.title" : "edit.node.edit.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear(perform: load)
            .onChange(of: pickerItem) { _, item in loadCover(item) }
        }
    }

    private var coverPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("edit.cover.choose", systemImage: "photo.on.rectangle")
            }
        }
        .padding(.vertical, 4)
    }

    private func loadCover(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task { @MainActor in
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                coverImage = img
            }
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let node else { return }
        name = node.name
        yearRange = node.yearRange
        summary = node.summary
        story = node.story
        isVisible = node.isVisible
        if let f = node.coverImageFileName {
            coverImage = MediaStore.loadImage(fileName: f, personID: person.id)
        }
    }

    private func save() {
        let target: Node
        if let node {
            target = node
        } else {
            let nextOrder = (person.nodes.map(\.sortOrder).max() ?? -1) + 1
            target = Node(id: newID, name: "", sortOrder: nextOrder)
            target.person = person
            context.insert(target)
        }

        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.yearRange = yearRange.trimmingCharacters(in: .whitespacesAndNewlines)
        target.summary = summary
        target.story = story
        target.isVisible = isVisible

        if let img = coverImage {
            if let old = target.coverImageFileName {
                MediaStore.deleteFile(fileName: old, personID: person.id)
            }
            target.coverImageFileName = MediaStore.saveImage(img, personID: person.id)
        }

        try? context.save()
        dismiss()
    }

    /// 取本地化后的推荐章节名
    private func suggestedTitle(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }
}

// MARK: - 推荐章节名称（与网站 node_edit 下拉框一致）

enum ChapterSuggestions {
    static let keys: [String] = [
        "suggestion.childhood",
        "suggestion.adolescence",
        "suggestion.youngAdulthood",
        "suggestion.middleAdulthood",
        "suggestion.laterYears",
        "suggestion.marriage",
        "suggestion.career",
        "suggestion.family",
        "suggestion.hobbies",
        "suggestion.roots",
        "suggestion.turningPoints"
    ]
}
