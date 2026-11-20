//
//  PhotoLibraryView.swift
//  EchoesOfTime
//
//  照片库：一个档案下的全部照片统一管理
//  - 可按章节筛选，也可以只看「未分配到章节」的照片
//  - 一张照片可以同时属于多个章节（对齐网站 Select Nodes…）
//  - 支持多选后批量分配 / 移出 / 删除
//

import SwiftUI
import SwiftData

struct PhotoLibraryView: View {
    let person: Person
    var isReader: Bool = false

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var filterNodeID: UUID?
    @State private var unassignedOnly = false
    @State private var selecting = false
    @State private var selected = Set<UUID>()
    @State private var showNodePicker = false
    @State private var showLightbox = false
    @State private var lightboxStart = 0
    @State private var showDeleteConfirm = false

    // MARK: - 数据

    private var personID: UUID { person.id }

    private var allPhotos: [Photo] {
        person.photos.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.createdAt < $1.createdAt
        }
    }

    private var unassignedPhotos: [Photo] {
        allPhotos.filter { $0.taggedNodeIDs.isEmpty }
    }

    private var nodes: [Node] {
        person.nodes.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.createdAt < $1.createdAt
        }
    }

    private var displayedPhotos: [Photo] {
        if unassignedOnly { return unassignedPhotos }
        if let filterNodeID, let node = nodes.first(where: { $0.id == filterNodeID }) {
            return allPhotos.filter { $0.belongs(to: node) }
        }
        return allPhotos
    }

    private var selectedPhotos: [Photo] {
        allPhotos.filter { selected.contains($0.id) }
    }

    /// 选中照片共同所属的章节（用于分配弹窗的预选）
    private var commonNodeIDs: Set<UUID> {
        guard let first = selectedPhotos.first else { return [] }
        return Set(selectedPhotos.reduce(into: Set(first.taggedNodeIDs)) { acc, photo in
            acc.formIntersection(Set(photo.taggedNodeIDs))
        })
    }

    // MARK: - 视图

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                filterBar

                if displayedPhotos.isEmpty {
                    Text("library.photos.empty")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)
                        .frame(maxWidth: .infinity)
                } else {
                    grid
                }
            }
            .padding(16)
            .readableCentered()
            .padding(.bottom, selecting ? 110 : 100)
        }
        .navigationTitle("library.photos.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isReader && !allPhotos.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(selecting ? "common.done" : "library.photos.select") {
                        selecting.toggle()
                        if !selecting { selected.removeAll() }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if selecting && !selected.isEmpty {
                selectionBar
            }
        }
        .sheet(isPresented: $showNodePicker) {
            NodePickerSheet(
                nodes: nodes,
                preselected: commonNodeIDs,
                photoCount: selectedPhotos.count
            ) { chosen in
                assign(chosen)
            }
        }
        .fullScreenCover(isPresented: $showLightbox) {
            PhotoLightboxView(
                photos: displayedPhotos,
                personID: personID,
                startIndex: lightboxStart,
                isReader: isReader,
                person: person
            )
        }
        #if DEBUG
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("debug-photo"), !displayedPhotos.isEmpty {
                lightboxStart = 0
                showLightbox = true
            }
        }
        #endif
        .confirmationDialog("library.photos.delete.confirm", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("common.delete", role: .destructive) { deleteSelected() }
            Button("common.cancel", role: .cancel) {}
        }
    }

    // MARK: - 筛选条

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(Text("library.photos.all"), count: allPhotos.count, active: filterNodeID == nil && !unassignedOnly) {
                    filterNodeID = nil
                    unassignedOnly = false
                }

                if !unassignedPhotos.isEmpty {
                    chip(Text("library.photos.unassigned"), count: unassignedPhotos.count, active: unassignedOnly) {
                        unassignedOnly = true
                        filterNodeID = nil
                    }
                }

                ForEach(nodes) { node in
                    chip(
                        Text(node.name),
                        count: node.resolvedPhotoCount,
                        active: !unassignedOnly && filterNodeID == node.id
                    ) {
                        filterNodeID = node.id
                        unassignedOnly = false
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func chip(_ title: Text, count: Int, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                title
                    .font(.system(size: 13, weight: active ? .semibold : .regular))
                Text("\(count)")
                    .font(.system(size: 12))
                    .foregroundStyle(active ? .white.opacity(0.85) : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(active ? Color.brown : Color.brown.opacity(0.08), in: Capsule())
            .foregroundStyle(active ? .white : .brown)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 网格

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)], spacing: 3) {
            ForEach(Array(displayedPhotos.enumerated()), id: \.element.id) { idx, photo in
                cell(photo, index: idx)
            }
        }
    }

    private func cell(_ photo: Photo, index: Int) -> some View {
        Button {
            if selecting {
                toggle(photo)
            } else {
                lightboxStart = index
                showLightbox = true
            }
        } label: {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let image = MediaStore.loadImage(fileName: photo.imageFileName, personID: personID) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay {
                    if selecting {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(selected.contains(photo.id) ? Color.brown : Color.clear, lineWidth: 3)
                            .background(
                                (selected.contains(photo.id) ? Color.brown.opacity(0.15) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            )
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if photo.taggedNodeIDs.count > 1 {
                        Text("\(photo.taggedNodeIDs.count)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.55), in: Capsule())
                            .padding(4)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if photo.taggedNodeIDs.isEmpty {
                        Text("library.photos.tag.unassigned")
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.85), in: Capsule())
                            .padding(4)
                    }
                }
                .contextMenu {
                    if !isReader {
                        Button {
                            selected = [photo.id]
                            showNodePicker = true
                        } label: {
                            Label("library.photos.assign", systemImage: "folder.badge.plus")
                        }
                        Button(role: .destructive) {
                            delete([photo])
                        } label: {
                            Label("common.delete", systemImage: "trash")
                        }
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 底部批量条

    private var selectionBar: some View {
        HStack(spacing: 10) {
            Button {
                showNodePicker = true
            } label: {
                Label("library.photos.assign", systemImage: "folder.badge.plus")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(.brown)

            Button {
                unassign()
            } label: {
                Label("library.photos.unassign", systemImage: "folder.badge.minus")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.bordered)
            .tint(.brown)

            Spacer()

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.bordered)
            .tint(.red)

            Text("\(selected.count)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.thinMaterial)
    }

    // MARK: - 操作

    private func toggle(_ photo: Photo) {
        if selected.contains(photo.id) {
            selected.remove(photo.id)
        } else {
            selected.insert(photo.id)
        }
    }

    private func assign(_ nodeIDs: Set<UUID>) {
        let chosen = nodes.filter { nodeIDs.contains($0.id) }
        for photo in selectedPhotos {
            photo.setTaggedNodes(chosen)
        }
        try? context.save()
        selected.removeAll()
        selecting = false
    }

    private func unassign() {
        for photo in selectedPhotos {
            photo.setTaggedNodes([])
        }
        try? context.save()
        selected.removeAll()
        selecting = false
    }

    private func delete(_ photos: [Photo]) {
        for photo in photos {
            MediaStore.deleteFile(fileName: photo.imageFileName, personID: personID)
            if let audio = photo.audioFileName, !audio.isEmpty {
                MediaStore.deleteFile(fileName: audio, personID: personID)
            }
            context.delete(photo)
        }
        try? context.save()
        selected.removeAll()
        selecting = false
    }

    private func deleteSelected() {
        delete(selectedPhotos)
    }
}
