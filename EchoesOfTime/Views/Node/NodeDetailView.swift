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
    @Environment(AppState.self) private var appState

    @State private var selectedPhoto: Photo?
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showPicker = false
    @State private var showVoiceRecorder = false
    @State private var showAssignFromLibrary = false
    @State private var showOrder = false
    @State private var showNodeEdit = false
    @State private var photoToEdit: Photo?
    @State private var photoExpanded = false
    @State private var storyExpanded = false
    @State private var showingPaywall = false

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
                // 1 节点图片
                cover

                // 2 时间段
                if !node.yearRange.isEmpty {
                    Text(node.yearRange)
                        .font(.system(size: isReader ? 22 : 15))
                        .foregroundStyle(.brown)
                }

                // 3 节点故事
                if !node.story.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ArchiveParagraphView(
                            paragraphs: storyBody.paragraphs,
                            expanded: isReader || storyExpanded,
                            fontSize: isReader ? 24 : 16,
                            lineSpacing: 6
                        )

                        if !isReader && storyBody.paragraphs.count > 1 {
                            Button(storyExpanded ? "person.story.collapse" : "person.story.expand") {
                                withAnimation(.easeInOut(duration: 0.2)) { storyExpanded.toggle() }
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.brown)
                            .buttonStyle(.borderless)
                        }

                        if storyBody.hasSignature && (isReader || storyExpanded) {
                            VStack(alignment: .trailing, spacing: 4) {
                                if !storyBody.separator.isEmpty {
                                    Text(storyBody.separator)
                                        .font(.system(size: isReader ? 15 : 12))
                                        .foregroundStyle(.secondary)
                                }
                                Text(storyBody.signature)
                                    .font(.system(size: isReader ? 18 : 14))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.trailing)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.top, 2)
                        }
                    }
                }

                // 4 节点旁白
                voiceSection

                // 5 节点照片
                photoSection

                // 6 家人留言
                if let person = node.person {
                    MessageSection(person: person, node: node, isReader: isReader)
                }
            }
            .padding(20)
            .readableCentered()
        }
        .navigationTitle(node.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isReader {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            if let person = node.person,
                               PurchaseManager.shared.canAddPhoto(currentCount: person.photos.count) {
                                showPicker = true
                            } else {
                                showingPaywall = true
                            }
                        } label: {
                            Label("node.action.add.photos", systemImage: "photo.badge.plus")
                        }
                        if node.person != nil {
                            Button {
                                if let person = node.person,
                                   PurchaseManager.shared.canAddPhoto(currentCount: person.photos.count) {
                                    showAssignFromLibrary = true
                                } else {
                                    showingPaywall = true
                                }
                            } label: {
                                Label("node.action.from.library", systemImage: "square.grid.2x2")
                            }
                            if photos.count > 1 {
                                Button { showOrder = true } label: {
                                    Label("node.action.sort", systemImage: "arrow.up.arrow.down")
                                }
                            }
                        }
                        Button {
                            if let person = node.person,
                               PurchaseManager.shared.canAddVoice(currentCount: person.voiceNotes.count) {
                                showVoiceRecorder = true
                            } else {
                                showingPaywall = true
                            }
                        } label: {
                            Label("node.action.voice", systemImage: "mic")
                        }
                        Divider()
                        Button { showNodeEdit = true } label: {
                            Label("node.action.edit", systemImage: "pencil")
                        }
                    } label: {
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
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .sheet(item: $photoToEdit) { photo in
            if let person = node.person {
                PhotoEditSheet(photo: photo, person: person)
            }
        }
        .sheet(isPresented: $showNodeEdit) {
            if let person = node.person {
                NodeEditView(person: person, node: node)
            }
        }
        .sheet(isPresented: $showAssignFromLibrary) {
            if let person = node.person {
                AddFromLibrarySheet(person: person, node: node)
            }
        }
        .sheet(isPresented: $showOrder) {
            PhotoOrderSheet(node: node, photos: photos, personID: personID ?? UUID())
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
               let img = MediaStore.loadImage(fileName: node.resolvedCoverFileName, personID: pid) {
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
        .frame(height: isReader ? 190 : 130)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// 简介是否还值得显示：正文已经包含简介内容时隐藏，避免同一件事说两遍
    private var storyBody: ArchiveText.Body { ArchiveText.parse(node.story) }

    private var showsSummary: Bool {
        let summary = node.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty else { return false }
        let plain = summary.components(separatedBy: CharacterSet.punctuationCharacters).joined()
        let storyPlain = node.story.components(separatedBy: CharacterSet.punctuationCharacters).joined()
        let probe = String(plain.prefix(8))
        guard !probe.isEmpty, !storyPlain.isEmpty else { return true }
        return !storyPlain.contains(probe)
    }

    // MARK: - 章节旁白

    private var nodeVoiceNote: VoiceNote? {
        node.person?.voiceNotes.first { $0.scope == .node && $0.targetID == node.id }
    }

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let note = nodeVoiceNote, let pid = personID {
                HStack {
                    Text("node.voice.title")
                        .font(.system(size: isReader ? 26 : 20, weight: .semibold))
                    Spacer()
                    if !isReader {
                        Button { showVoiceRecorder = true } label: {
                            Label("voice.record", systemImage: "mic.circle.fill")
                                .font(.system(size: isReader ? 22 : 15))
                        }
                        .buttonStyle(.borderless)
                    }
                }
                VoiceNotePlayButton(fileName: note.audioFileName, personID: pid)
            } else {
                // 没有旁白时收成一行，不占整块版面
                HStack(spacing: 8) {
                    Image(systemName: "mic")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                    Text("voice.empty")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    if !isReader, personID != nil {
                        Button {
                            if let person = node.person,
                               PurchaseManager.shared.canAddVoice(currentCount: person.voiceNotes.count) {
                                showVoiceRecorder = true
                            } else {
                                showingPaywall = true
                            }
                        } label: {
                            Text("voice.record")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.brown)
                        }
                        .buttonStyle(.borderless)
                    }
                }
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
                    columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3),
                    spacing: 6
                ) {
                    ForEach(visiblePhotos) { photo in
                        photoCell(photo)
                    }
                }

                if photos.count > 6 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { photoExpanded.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Text(photoMoreText)
                            Image(systemName: photoExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .font(.system(size: isReader ? 18 : 14, weight: .medium))
                        .foregroundStyle(.brown)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    /// 照片默认只显示 6 张
    private var visiblePhotos: [Photo] {
        photoExpanded ? photos : Array(photos.prefix(6))
    }

    private var photoMoreText: String {
        let hidden = max(0, photos.count - 6)
        if appState.language == .zhHans {
            return photoExpanded ? "收起" : "展开全部 \(photos.count) 张（还有 \(hidden) 张）"
        }
        return photoExpanded ? "Show less" : "Show all \(photos.count) photos"
    }

    private func thumbnail(_ photo: Photo) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let pid = personID,
                   let img = MediaStore.loadImage(fileName: photo.imageFileName, personID: pid) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color.brown.opacity(0.12)
                        Image(systemName: "photo")
                            .foregroundStyle(.brown)
                    }
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topLeading) {
                if photo.imageFileName == node.coverImageFileName {
                    Text("node.cover.badge")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.brown.opacity(0.9), in: Capsule())
                        .padding(4)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if photo.audioFileName != nil {
                    Image(systemName: "waveform")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(.black.opacity(0.45), in: Circle())
                        .padding(5)
                }
            }
    }

    // MARK: - 照片单元格（长按拖拽排序）

    @ViewBuilder
    private func photoCell(_ photo: Photo) -> some View {
        Button {
            selectedPhoto = photo
        } label: {
            thumbnail(photo)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !isReader {
                Button {
                    node.coverImageFileName = photo.imageFileName
                    try? context.save()
                } label: {
                    Label("node.action.set.cover", systemImage: "rectangle.badge.checkmark")
                }
                Divider()
                Button("photo.moveLeft") { move(photo, by: -1) }
                Button("photo.moveRight") { move(photo, by: 1) }
                Button("common.edit.photo") { photoToEdit = photo }
                Button("common.delete", role: .destructive) { delete(photo) }
            }
        }
        .onDrag {
            guard !isReader else { return NSItemProvider() }
            return NSItemProvider(object: photo.id.uuidString as NSString)
        }
        .onDrop(of: [.text], isTargeted: nil) { providers in
            guard !isReader, let item = providers.first else { return false }
            item.loadObject(ofClass: NSString.self) { value, _ in
                DispatchQueue.main.async {
                    guard let s = value as? String,
                          let fromID = UUID(uuidString: s), fromID != photo.id else { return }
                    reorder(from: fromID, to: photo.id)
                }
            }
            return true
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

    /// 长按拖拽：把 fromID 照片插到 toID 照片位置，并重排连续序号
    private func reorder(from fromID: UUID, to toID: UUID) {
        var arr = photos
        guard let fromIdx = arr.firstIndex(where: { $0.id == fromID }),
              let toIdx = arr.firstIndex(where: { $0.id == toID }) else { return }
        let moved = arr.remove(at: fromIdx)
        arr.insert(moved, at: toIdx)
        for (i, p) in arr.enumerated() { p.sortOrder = i }
        try? context.save()
    }
}
