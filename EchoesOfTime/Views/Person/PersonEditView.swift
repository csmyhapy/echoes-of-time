//
//  PersonEditView.swift
//  EchoesOfTime
//
//  新建 / 编辑人物档案（姓名、生卒年、简介、人生故事、封面）
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import UniformTypeIdentifiers

struct PersonEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// nil 表示新建
    let person: Person?

    @State private var name = ""
    @State private var birthYear = ""
    @State private var summary = ""
    @State private var story = ""
    @State private var coverImage: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var newID = UUID()
    @State private var loaded = false
    @State private var bgmFileName: String?
    @State private var bgmTitle = ""
    @State private var showBgmImporter = false

    private var isNew: Bool { person == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("edit.person.section.basics") {
                    TextField("edit.person.name", text: $name)
                    TextField("edit.person.birthYear", text: $birthYear)
                }

                Section("edit.person.section.summary") {
                    TextField("edit.person.summary", text: $summary, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("edit.person.section.story") {
                    TextField("edit.person.story", text: $story, axis: .vertical)
                        .lineLimit(6...14)
                }

                Section("edit.person.section.cover") {
                    coverPicker
                }

                Section("edit.person.section.bgm") {
                    HStack(spacing: 8) {
                        Image(systemName: "music.note")
                            .foregroundStyle(.brown)
                        Text(bgmTitle.isEmpty ? "edit.bgm.none" : bgmTitle)
                            .foregroundStyle(bgmTitle.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                        Spacer()
                        if !bgmTitle.isEmpty {
                            Button("common.delete", role: .destructive) { removeBgm() }
                                .font(.system(size: 14))
                        }
                    }
                    Button {
                        showBgmImporter = true
                    } label: {
                        Label("edit.bgm.choose", systemImage: "folder.badge.plus")
                    }
                }
            }
            .navigationTitle(isNew ? "edit.person.new.title" : "edit.person.edit.title")
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
            .fileImporter(
                isPresented: $showBgmImporter,
                allowedContentTypes: [.audio, .mp3, .mpeg4Audio, .wav],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    importBgm(url)
                }
            }
        }
    }

    // MARK: - 封面

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

    // MARK: - 背景音乐

    private func importBgm(_ url: URL) {
        let pid = person?.id ?? newID
        guard let name = MediaStore.saveAudioFile(from: url, personID: pid) else { return }
        if let old = bgmFileName {
            MediaStore.deleteFile(fileName: old, personID: pid)
        }
        bgmFileName = name
        bgmTitle = url.deletingPathExtension().lastPathComponent
    }

    private func removeBgm() {
        let pid = person?.id ?? newID
        if let old = bgmFileName {
            MediaStore.deleteFile(fileName: old, personID: pid)
        }
        bgmFileName = nil
        bgmTitle = ""
    }

    // MARK: - 载入与保存

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let person else { return }
        name = person.name
        birthYear = person.birthYear
        summary = person.summary
        story = person.story
        if let f = person.coverImageFileName {
            coverImage = MediaStore.loadImage(fileName: f, personID: person.id)
        }
        bgmFileName = person.bgmFileName
        bgmTitle = person.bgmTitle ?? ""
    }

    private func save() {
        let target: Person
        if let person {
            target = person
        } else {
            target = Person(id: newID, name: "")
            context.insert(target)
        }

        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.birthYear = birthYear.trimmingCharacters(in: .whitespacesAndNewlines)
        target.summary = summary
        target.story = story

        target.bgmFileName = bgmFileName
        target.bgmTitle = bgmTitle.isEmpty ? nil : bgmTitle

        if let img = coverImage {
            if let old = target.coverImageFileName {
                MediaStore.deleteFile(fileName: old, personID: target.id)
            }
            target.coverImageFileName = MediaStore.saveImage(img, personID: target.id)
        }

        try? context.save()
        dismiss()
    }
}
