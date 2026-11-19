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
    @Environment(AppState.self) private var appState

    let person: Person
    var isReader: Bool = false

    @State private var showingEditPerson = false
    @State private var showingNewNode = false
    @State private var editingNode: Node?
    @State private var showVoiceRecorder = false
    @State private var exportItem: ExportItem?
    @State private var showExportError = false
    @State private var storyExpanded = false
    @State private var timelineExpanded = false
    @AppStorage("bgmEnabled") private var bgmEnabled = true

    // MARK: - 背景音乐开关（仅人物页有音乐）

    private var bgmButton: some View {
        Button {
            bgmEnabled.toggle()
            if bgmEnabled {
                BGMManager.shared.play(fileName: person.bgmFileName, personID: person.id)
            } else {
                BGMManager.shared.stop()
            }
        } label: {
            Image(systemName: bgmEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(bgmEnabled ? Color.brown : Color.secondary)
        }
        .accessibilityLabel(Text(bgmEnabled ? "bgm.off" : "bgm.on"))
    }

    private var sortedNodes: [Node] {
        // sortOrder 相同时按年代起始年排序（网站导入的 sortOrder 全是 0，需要兜底）
        person.nodes.sorted { a, b in
            if a.sortOrder != b.sortOrder { return a.sortOrder < b.sortOrder }
            if a.webOrder != b.webOrder {
                // webOrder 为 0 表示新建章节，排在网站导入章节之后
                let wa = a.webOrder == 0 ? Int.max : a.webOrder
                let wb = b.webOrder == 0 ? Int.max : b.webOrder
                return wa < wb
            }
            let ya = startYear(a.yearRange), yb = startYear(b.yearRange)
            if ya != yb { return ya < yb }
            return a.createdAt < b.createdAt
        }
    }

    private func startYear(_ range: String) -> Int {
        let numbers = range.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0.prefix(4)) }
        return numbers.first ?? 9999
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                timelineSection

                voiceSection

                if !person.story.isEmpty {
                    storySection
                }

                MessageSection(person: person, isReader: isReader)
            }
            .padding(20)
        }
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                bgmButton
            }
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

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            if sortedNodes.isEmpty {
                Text("person.empty.nodes")
                    .font(.system(size: isReader ? 22 : 15))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visibleNodes) { node in
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

                if sortedNodes.count > 3 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { timelineExpanded.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Text(timelineMoreText)
                            Image(systemName: timelineExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .font(.system(size: isReader ? 18 : 14, weight: .medium))
                        .foregroundStyle(.brown)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    /// 时间线默认只显示前 3 章，展开看全部
    private var visibleNodes: [Node] {
        timelineExpanded ? sortedNodes : Array(sortedNodes.prefix(3))
    }

    private var timelineMoreText: String {
        let hidden = max(0, sortedNodes.count - 3)
        if appState.language == .zhHans {
            return timelineExpanded ? "收起" : "展开全部 \(sortedNodes.count) 个章节（还有 \(hidden) 个）"
        }
        return timelineExpanded ? "Show less" : "Show all \(sortedNodes.count) chapters"
    }

    // MARK: - 人生故事（折叠）

    private var storySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("person.section.story")
                .font(.system(size: isReader ? 26 : 20, weight: .semibold))

            Text(ArchiveText.paragraphs(person.story))
                .font(.system(size: isReader ? 24 : 16))
                .lineSpacing(6)
                .lineLimit((isReader || storyExpanded) ? nil : 4)
                .fixedSize(horizontal: false, vertical: true)

            if !isReader {
                Button(storyExpanded ? "person.story.collapse" : "person.story.expand") {
                    withAnimation(.easeInOut(duration: 0.2)) { storyExpanded.toggle() }
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.brown)
                .buttonStyle(.borderless)
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
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if let img = MediaStore.loadImage(fileName: person.resolvedCoverFileName, personID: person.id) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [Color.brown.opacity(0.35), Color.brown.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: isReader ? 260 : 200)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 8) {
                Text(person.name)
                    .font(.system(size: isReader ? 32 : 26, weight: .bold))

                HStack(alignment: .center, spacing: 10) {
                    if !person.birthYear.isEmpty {
                        Text(person.birthYear)
                            .font(.system(size: isReader ? 20 : 15))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    statsRow
                }
            }

            if !person.summary.isEmpty {
                Text(person.summary)
                    .font(.system(size: isReader ? 22 : 15))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statValue(person.nodes.count, "unit.chapters")
            statValue(person.photos.count, "unit.photos")
            statValue(person.messages.filter { !$0.isDeleted }.count, "unit.messages")
        }
    }

    private func statValue(_ count: Int, _ key: LocalizedStringKey) -> some View {
        (Text("\(count) ").foregroundColor(.brown) + Text(key).foregroundColor(.brown.opacity(0.72)))
            .font(.system(size: isReader ? 18 : 13, weight: .medium))
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
                    if let img = MediaStore.loadImage(fileName: node.resolvedCoverFileName, personID: personID) {
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
                Text(ArchiveText.inline(node.summary))
                    .font(.system(size: large ? 22 : 15))
                    .foregroundStyle(.secondary)
                    .lineSpacing(5)
            }
        }
        .padding(14)
        .background(Color.brown.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }
}
