//
//  NodeDetailView.swift
//  EchoesOfTime
//
//  章节详情（照片页）：章节封面 / 年代 / 简介 + 照片网格 → 灯箱
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct NodeDetailView: View {
    let node: Node
    var isReader: Bool = false

    @Environment(\.modelContext) private var context

    @State private var selectedPhoto: Photo?
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showPicker = false
    @State private var showVoiceRecorder = false

    private var personID: UUID? { node.person?.id }
    private var photos: [Photo] {
        guard let person = node.person else {
            return node.photos.sorted { $0.sortOrder < $1.sortOrder }
        }
        // 一个照片可同时属于多个章节（对齐网站 tags 多标签）
        return person.photos
            .filter { $0.belongs(to: node) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                cover

                if !node.yearRange.isEmpty {
                    Text(node.yearRange)
                        .font(.system(size: isReader ? 22 : 15))
                        .foregroundStyle(.brown)
                }

                if !node.summary.isEmpty {
                    Text(node.summary)
                        .font(.system(size: isReader ? 24 : 16))
                        .lineSpacing(6)
                }

                if !node.story.isEmpty {
                    Text(node.story)
                        .font(.system(size: isReader ? 24 : 16))
                        .lineSpacing(6)
                }

                voiceSection

                if let person = node.person {
                    MessageSection(person: person, node: node, isReader: isReader)
                }

                photoSection
            }
            .padding(20)
        }
        .navigationTitle(node.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isReader {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showPicker = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showVoiceRecorder) {
            RecorderSheet(personID: personID ?? UUID(), titleKey: "recorder.node.title") { name, duration in
                saveVoice(fileName: name, duration: duration)
            }
        }
        .photosPicker(isPresented: $showPicker, selection: $pickerItems,
                      maxSelectionCount: 20, matching: .images)
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await addPhotos(items) }
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            if let pid = personID {
                PhotoLightboxView(
                    photos: photos,
                    personID: pid,
                    startIndex: photos.firstIndex(where: { $0.id == photo.id }) ?? 0,
                    isReader: isReader,
                    person: node.person
                )
            }
        }
    }

    // MARK: - 封面

    private var cover: some View {
        Group {
            if let pid = personID,
               let img = MediaStore.loadImage(fileName: node.coverImageFileName, personID: pid) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color.brown.opacity(0.35), Color.brown.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .frame(height: isReader ? 220 : 170)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 章节旁白

    private var nodeVoiceNote: VoiceNote? {
        node.person?.voiceNotes.first { $0.scope == .node && $0.targetID == node.id }
    }

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("node.voice.title")
                    .font(.system(size: isReader ? 26 : 20, weight: .semibold))
                Spacer()
                if !isReader, personID != nil {
                    Button { showVoiceRecorder = true } label: {
                        Label("voice.record", systemImage: "mic.circle.fill")
                            .font(.system(size: isReader ? 22 : 15))
                    }
                    .buttonStyle(.borderless)
                }
            }

            if let note = nodeVoiceNote, let pid = personID {
                VoiceNotePlayButton(fileName: note.audioFileName, personID: pid)
            } else {
                Text("voice.empty")
                    .font(.system(size: isReader ? 20 : 14))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }

    private func saveVoice(fileName: String, duration: Int) {
        guard let person = node.person else { return }
        if let existing = nodeVoiceNote {
            MediaStore.deleteFile(fileName: existing.audioFileName, personID: person.id)
            existing.audioFileName = fileName
            existing.duration = duration
        } else {
            let note = VoiceNote(scope: .node, targetID: node.id,
                                 audioFileName: fileName, duration: duration)
            note.person = person
            context.insert(note)
        }
        try? context.save()
    }

    // MARK: - 照片网格

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("node.section.photos")
                    .font(.system(size: isReader ? 26 : 20, weight: .semibold))
                Spacer()
                Text("\(photos.count)")
                    .font(.system(size: isReader ? 20 : 15))
                    .foregroundStyle(.secondary)
            }

            if photos.isEmpty {
                Text("node.empty.photos")
                    .font(.system(size: isReader ? 22 : 15))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: isReader ? 150 : 110), spacing: 10)],
                    spacing: 12
                ) {
                    ForEach(photos) { photo in
                        Button {
                            selectedPhoto = photo
                        } label: {
                            thumbnail(photo)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if !isReader {
                                Button("photo.moveLeft") { move(photo, by: -1) }
                                Button("photo.moveRight") { move(photo, by: 1) }
                                Button("common.delete", role: .destructive) { delete(photo) }
                            }
                        }
                    }
                }
            }
        }
    }

    private func thumbnail(_ photo: Photo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let pid = personID,
                   let img = MediaStore.loadImage(fileName: photo.imageFileName, personID: pid) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Rectangle().fill(Color.brown.opacity(0.12))
                        Image(systemName: "photo")
                            .foregroundStyle(.brown)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: isReader ? 160 : 120)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if !photo.caption.isEmpty {
                Text(photo.caption)
                    .font(.system(size: isReader ? 20 : 13))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            if photo.audioFileName != nil {
                Label("photo.has.audio", systemImage: "waveform")
                    .font(.system(size: isReader ? 17 : 11))
                    .foregroundStyle(.brown.opacity(0.8))
            }
        }
    }

    // MARK: - 照片操作

    private func addPhotos(_ items: [PhotosPickerItem]) async {
        guard let pid = personID else { return }
        var order = (photos.map(\.sortOrder).max() ?? -1) + 1
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let img = UIImage(data: data),
                  let name = MediaStore.saveImage(img, personID: pid) else { continue }
            let photo = Photo(imageFileName: name)
            photo.sortOrder = order
            order += 1
            photo.node = node
            photo.person = node.person
            photo.setTaggedNodes([node])
            context.insert(photo)
        }
        try? context.save()
        pickerItems = []
    }

    private func delete(_ photo: Photo) {
        if let pid = personID {
            MediaStore.deleteFile(fileName: photo.imageFileName, personID: pid)
            if let a = photo.audioFileName {
                MediaStore.deleteFile(fileName: a, personID: pid)
            }
        }
        context.delete(photo)
        try? context.save()
    }

    private func move(_ photo: Photo, by delta: Int) {
        let sorted = photos
        guard let idx = sorted.firstIndex(where: { $0.id == photo.id }) else { return }
        let target = idx + delta
        guard sorted.indices.contains(target) else { return }
        let other = sorted[target]
        let tmp = photo.sortOrder
        photo.sortOrder = other.sortOrder
        other.sortOrder = tmp
        try? context.save()
    }
}
