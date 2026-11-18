//
//  PersonDetailView.swift
//  EchoesOfTime
//
//  人物档案详情：时间线（章节 + 照片）
//

import SwiftUI
import SwiftData

struct PersonDetailView: View {
    @Environment(\.modelContext) private var context

    let person: Person
    var isReader: Bool = false

    @State private var showingEditPerson = false
    @State private var showingNewNode = false
    @State private var editingNode: Node?
    @State private var showVoiceRecorder = false
    @State private var exportItem: ExportItem?
    @State private var showExportError = false

    private var sortedNodes: [Node] {
        person.nodes.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                voiceSection

                MessageSection(person: person, isReader: isReader)

                if !person.story.isEmpty {
                    Text(person.story)
                        .font(.system(size: isReader ? 24 : 16))
                        .lineSpacing(6)
                }

                if sortedNodes.isEmpty {
                    Text("person.empty.nodes")
                        .font(.system(size: isReader ? 22 : 15))
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)
                } else {
                    HStack {
                        Text("person.section.timeline")
                            .font(.system(size: isReader ? 26 : 20, weight: .semibold))
                        Spacer()
                        if !isReader {
                            Button {
                                showingNewNode = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.brown)
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    ForEach(sortedNodes) { node in
                        NavigationLink {
                            NodeDetailView(node: node, isReader: isReader)
                        } label: {
                            NodeCard(node: node, personID: person.id, large: isReader)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if !isReader {
                                Button("common.edit") { editingNode = node }
                                Button("common.delete", role: .destructive) { delete(node) }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isReader {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            exportPDF()
                        } label: {
                            Label("export.pdf", systemImage: "doc.richtext")
                        }
                        Button {
                            exportArchive()
                        } label: {
                            Label("export.archive", systemImage: "archivebox")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.edit") { showingEditPerson = true }
                }
            }
        }
        .sheet(isPresented: $showingEditPerson) {
            PersonEditView(person: person)
        }
        .sheet(isPresented: $showingNewNode) {
            NodeEditView(person: person, node: nil)
        }
        .sheet(item: $editingNode) { node in
            NodeEditView(person: person, node: node)
        }
        .sheet(isPresented: $showVoiceRecorder) {
            RecorderSheet(personID: person.id, titleKey: "recorder.person.title") { name, duration in
                saveVoice(fileName: name, duration: duration)
            }
        }
        .sheet(item: $exportItem) { item in
            ActivityView(url: item.url)
        }
        .alert("export.failed", isPresented: $showExportError) {
            Button("common.save", role: .cancel) {}
        }
        .onAppear {
            BGMManager.shared.play(fileName: person.bgmFileName, personID: person.id)
        }
        .onDisappear {
            BGMManager.shared.stop()
        }
        .onChange(of: showVoiceRecorder) { _, isShowing in
            if isShowing {
                BGMManager.shared.stop()
            } else {
                BGMManager.shared.play(fileName: person.bgmFileName, personID: person.id)
            }
        }
    }

    // MARK: - 人物旁白

    private var personVoiceNote: VoiceNote? {
        person.voiceNotes.first { $0.scope == .person }
    }

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("person.voice.title")
                    .font(.system(size: isReader ? 26 : 18, weight: .semibold))
                Spacer()
                if !isReader {
                    Button { showVoiceRecorder = true } label: {
                        Label("voice.record", systemImage: "mic.circle.fill")
                            .font(.system(size: isReader ? 22 : 15))
                    }
                    .buttonStyle(.borderless)
                }
            }

            if let note = personVoiceNote {
                VoiceNotePlayButton(fileName: note.audioFileName, personID: person.id)
            } else {
                Text("voice.empty")
                    .font(.system(size: isReader ? 20 : 14))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func saveVoice(fileName: String, duration: Int) {
        if let existing = personVoiceNote {
            MediaStore.deleteFile(fileName: existing.audioFileName, personID: person.id)
            existing.audioFileName = fileName
            existing.duration = duration
        } else {
            let note = VoiceNote(scope: .person, audioFileName: fileName, duration: duration)
            note.person = person
            context.insert(note)
        }
        try? context.save()
    }

    // MARK: - 导出

    private func exportPDF() {
        if let url = PDFExporter.makePDF(for: person) {
            exportItem = ExportItem(url: url)
        } else {
            showExportError = true
        }
    }

    private func exportArchive() {
        if let url = ArchiveExporter.makeArchive(for: person) {
            exportItem = ExportItem(url: url)
        } else {
            showExportError = true
        }
    }

    private func delete(_ node: Node) {
        context.delete(node)
        try? context.save()
    }

    private var header: some View {
        HStack(spacing: 18) {
            Group {
                if let img = MediaStore.loadImage(fileName: person.coverImageFileName, personID: person.id) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    ZStack {
                        Color.brown.opacity(0.18)
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 40))
                            .foregroundStyle(.brown)
                    }
                }
            }
            .frame(width: isReader ? 110 : 88, height: isReader ? 110 : 88)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 6) {
                Text(person.name)
                    .font(.system(size: isReader ? 30 : 24, weight: .bold))
                if !person.birthYear.isEmpty {
                    Text(person.birthYear)
                        .font(.system(size: isReader ? 22 : 16))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

struct NodeCard: View {
    let node: Node
    let personID: UUID
    var large: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Group {
                    if let img = MediaStore.loadImage(fileName: node.coverImageFileName, personID: personID) {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        ZStack {
                            Color.brown.opacity(0.12)
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: large ? 28 : 20))
                                .foregroundStyle(.brown)
                        }
                    }
                }
                .frame(width: large ? 88 : 64, height: large ? 88 : 64)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(node.name)
                        .font(.system(size: large ? 26 : 18, weight: .semibold))
                    if !node.yearRange.isEmpty {
                        Text(node.yearRange)
                            .font(.system(size: large ? 20 : 14))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if !node.summary.isEmpty {
                Text(node.summary)
                    .font(.system(size: large ? 22 : 15))
                    .foregroundStyle(.secondary)
                    .lineSpacing(5)
            }
        }
        .padding(14)
        .background(Color.brown.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }
}
