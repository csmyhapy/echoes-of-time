//
//  NodePickerSheet.swift
//  EchoesOfTime
//
//  章节多选弹窗：给照片选择归属章节（一张照片可以同时属于多个章节）
//

import SwiftUI

struct NodePickerSheet: View {
    let nodes: [Node]
    let preselected: Set<UUID>
    let photoCount: Int
    let onConfirm: (Set<UUID>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var chosen: Set<UUID>

    init(nodes: [Node], preselected: Set<UUID>, photoCount: Int, onConfirm: @escaping (Set<UUID>) -> Void) {
        self.nodes = nodes
        self.preselected = preselected
        self.photoCount = photoCount
        self.onConfirm = onConfirm
        _chosen = State(initialValue: preselected)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(nodes) { node in
                        Button {
                            if chosen.contains(node.id) {
                                chosen.remove(node.id)
                            } else {
                                chosen.insert(node.id)
                            }
                        } label: {
                            HStack {
                                Text(node.name)
                                    .foregroundStyle(.primary)
                                if !node.yearRange.isEmpty {
                                    Text(node.yearRange)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if chosen.contains(node.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.brown)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("library.photos.assign.footer")
                }
            }
            .navigationTitle("library.photos.assign.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") {
                        onConfirm(chosen)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
