//
//  PhotoSheets.swift
//  EchoesOfTime
//
//  照片编辑 / 从照片库加入章节 / 章节内照片排序
//

import SwiftUI
import SwiftData

// MARK: - 照片编辑

struct PhotoEditSheet: View {
    let photo: Photo
    let person: Person

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var caption: String
    @State private var story: String
    @State private var chosenNodes: Set<UUID>
    @State private var showNodePicker = false

    init(photo: Photo, person: Person) {
        self.photo = photo
        self.person = person
        _caption = State(initialValue: photo.caption)
        _story = State(initialValue: photo.story)
        _chosenNodes = State(initialValue: Set(photo.taggedNodeIDs))
    }

    private var nodes: [Node] {
        person.nodes.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.createdAt < $1.createdAt
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("photo.edit.caption") {
                    TextField("photo.edit.caption.placeholder", text: $caption, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("photo.edit.story") {
                    TextField("photo.edit.story.placeholder", text: $story, axis: .vertical)
                        .lineLimit(4...12)
                }

                Section("photo.edit.chapters") {
                    Button {
                        showNodePicker = true
                    } label: {
                        HStack {
                            Text(chapterSummary)
                                .foregroundStyle(chosenNodes.isEmpty ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .navigationTitle("photo.edit.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { save() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showNodePicker) {
                NodePickerSheet(
                    nodes: nodes,
                    preselected: chosenNodes,
                    photoCount: 1
                ) { chosen in
                    chosenNodes = chosen
                }
            }
        }
    }

    private var chapterSummary: String {
        let names = nodes.filter { chosenNodes.contains($0.id) }.map(\.name)
        if names.isEmpty { return String(localized: "photo.edit.no.chapter") }
        return names.joined(separator: "、")
    }

    private func save() {
        photo.caption = ArchiveText.inline(caption)
        photo.story = ArchiveText.clean(story)
        photo.setTaggedNodes(nodes.filter { chosenNodes.contains($0.id) })
        try? context.save()
        dismiss()
    }
}

// MARK: - 从照片库加入本章节

struct AddFromLibrarySheet: View {
    let person: Person
    let node: Node

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var chosen: Set<UUID>
    @State private var onlyUnassigned = false

    init(person: Person, node: Node) {
        self.person = person
        self.node = node
        _chosen = State(initialValue: Set(person.photos.filter { $0.belongs(to: node) }.map(\.id)))
    }

    private var allPhotos: [Photo] {
        person.photos.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.createdAt < $1.createdAt
        }
    }

    private var shownPhotos: [Photo] {
        onlyUnassigned ? allPhotos.filter { $0.taggedNodeIDs.isEmpty } : allPhotos
    }

    private var personID: UUID { person.id }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $onlyUnassigned) {
                        Text("photo.library.only.unassigned")
                            .font(.system(size: 14))
                    }
                    .tint(.brown)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4),
                        spacing: 4
                    ) {
                        ForEach(shownPhotos) { photo in
                            Button {
                                if chosen.contains(photo.id) {
                                    chosen.remove(photo.id)
                                } else {
                                    chosen.insert(photo.id)
                                }
                            } label: {
                                Color.clear
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay {
                                        if let img = MediaStore.loadImage(fileName: photo.imageFileName, personID: personID) {
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFill()
                                        } else {
                                            Color.brown.opacity(0.12)
                                        }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .overlay {
                                        if chosen.contains(photo.id) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.brown, lineWidth: 3)
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.brown.opacity(0.2))
                                        }
                                    }
                                    .overlay(alignment: .topTrailing) {
                                        if chosen.contains(photo.id) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 16))
                                                .foregroundStyle(.white, .brown)
                                                .padding(3)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("photo.library.add.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        for photo in allPhotos {
            var ids = Set(photo.taggedNodeIDs)
            if chosen.contains(photo.id) {
                ids.insert(node.id)
            } else {
                ids.remove(node.id)
            }
            photo.setTaggedNodes(person.nodes.filter { ids.contains($0.id) })
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - 章节内照片排序

struct PhotoOrderSheet: View {
    let node: Node
    let photos: [Photo]
    let personID: UUID

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var ordered: [Photo]

    init(node: Node, photos: [Photo], personID: UUID) {
        self.node = node
        self.photos = photos
        self.personID = personID
        _ordered = State(initialValue: photos)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(ordered) { photo in
                    HStack(spacing: 12) {
                        if let img = MediaStore.loadImage(
                            fileName: photo.imageFileName,
                            personID: personID
                        ) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        Text(photo.caption.isEmpty ? String(localized: "photo.untitled") : ArchiveText.inline(photo.caption))
                            .font(.system(size: 14))
                            .lineLimit(2)
                    }
                }
                .onMove { from, to in
                    ordered.move(fromOffsets: from, toOffset: to)
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("photo.order.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") {
                        for (i, photo) in ordered.enumerated() {
                            photo.sortOrder = i
                        }
                        try? context.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
