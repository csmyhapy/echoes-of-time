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
    @State private var orderWarning: String?
    @State private var storyExpanded = false
    @State private var timelineExpanded = false
    @State private var showingPaywall = false
    @AppStorage("bgmEnabled") private var bgmEnabled = true

    // MARK: - 背景音乐开关（仅人物页有音乐；开关位于底部栏）

    private var sortedNodes: [Node] {
        // 与 PDF 目录共用同一套排序（Node.displaysBefore），保证 App 显示顺序 = PDF 目录顺序
        person.nodes.filter { $0.isVisible }.sorted { Node.displaysBefore($0, $1) }
    }

    /// 导出前章节顺序检查：返回需提醒的问题文本，无问题返回 nil
    /// 检测：起始年相同的并列章节；纯年代兜底模式下的年代倒退
    private var chapterOrderIssue: String? {
        let nodes = sortedNodes
        guard nodes.count >= 2 else { return nil }

        // 同年并列：起始年相同的章节成组
        var sameYear = [String]()
        let groups = Dictionary(grouping: nodes, by: { $0.displayStartYear })
        for (year, group) in groups where group.count >= 2 {
            let names = group.map { $0.name }.joined(separator: "、")
            sameYear.append("\(year)年：\(names)")
        }

        // 仅当没有手动顺序（sortOrder/webOrder 全0，纯按年代排）时检查年代倒退
        var regress = [String]()
        if nodes.allSatisfy({ $0.sortOrder == 0 && $0.webOrder == 0 }) {
            for i in 1..<nodes.count where nodes[i].displayStartYear < nodes[i - 1].displayStartYear {
                regress.append("\(nodes[i - 1].name) → \(nodes[i].name)")
            }
        }

        if sameYear.isEmpty && regress.isEmpty { return nil }
        var parts = [String]()
        if !sameYear.isEmpty { parts.append("起始年相同（按创建先后排列）：" + sameYear.joined(separator: "；")) }
        if !regress.isEmpty { parts.append("年代排列倒退：" + regress.joined(separator: "；")) }
        return parts.joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                coverBlock
                infoBlock
                summaryBlock

                if !person.story.isEmpty {
                    storySection
                }

                voiceSection

                timelineSection

                MessageSection(person: person, isReader: isReader)
            }
            .padding(20)
        }
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isReader {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.edit") { showingEditPerson = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if PDFExporter.featureEnabled {
                            Button {
                                exportPDF()
                            } label: {
                                Label("export.pdf", systemImage: "doc.richtext")
                            }
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
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .alert("export.failed", isPresented: $showExportError) {
            Button("common.save", role: .cancel) {}
        }
        .alert("chapter.order.reminder", isPresented: Binding(get: { orderWarning != nil }, set: { if !$0 { orderWarning = nil } })) {
            Button("chapter.order.proceed") { orderWarning = nil; performExportPDF() }
            Button("common.cancel", role: .cancel) { orderWarning = nil }
        } message: {
            Text(orderWarning ?? "")
        }
        .onAppear {
            if bgmEnabled {
                BGMManager.shared.play(fileName: person.bgmFileName, personID: person.id)
            }
        }
        // 注意：push 到节点/照片页时不在此停止，保持背景音乐连续；
        // 返回藏书列表由 LibraryView 统一停止。
        .onChange(of: showVoiceRecorder) { _, isShowing in
            if isShowing {
                BGMManager.shared.stop()
            } else if bgmEnabled {
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
                        if PurchaseManager.shared.canAddNode(currentCount: person.nodes.count) {
                            showingNewNode = true
                        } else {
                            showingPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.brown)
                    }
                    .buttonStyle(.borderless)
                }
            }

            if !isReader && !sortedNodes.isEmpty {
                Text("chapter.drag.hint")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
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
                    .onDrag {
                        guard !isReader else { return NSItemProvider() }
                        return NSItemProvider(object: node.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], isTargeted: nil) { providers in
                        guard !isReader, let item = providers.first else { return false }
                        item.loadObject(ofClass: NSString.self) { value, _ in
                            DispatchQueue.main.async {
                                guard let s = value as? String,
                                      let fromID = UUID(uuidString: s), fromID != node.id else { return }
                                reorderNode(from: fromID, to: node.id)
                            }
                        }
                        return true
                    }
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
        let body = ArchiveText.parse(person.story)
        let expanded = isReader || storyExpanded
        return VStack(alignment: .leading, spacing: 10) {
            Text("person.section.story")
                .font(.system(size: isReader ? 26 : 20, weight: .semibold))

            ArchiveParagraphView(
                paragraphs: body.paragraphs,
                expanded: expanded,
                fontSize: isReader ? 24 : 16,
                lineSpacing: 6
            )

            if body.hasSignature && expanded {
                signatureBlock(body)
            }

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

    /// 落款：分隔线 + 署名，整体右对齐
    private func signatureBlock(_ body: ArchiveText.Body) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            if !body.separator.isEmpty {
                Text(body.separator)
                    .font(.system(size: isReader ? 15 : 12))
                    .foregroundStyle(.secondary)
            }
            Text(body.signature)
                .font(.system(size: isReader ? 18 : 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.top, 2)
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
                    Button {
                        if personVoiceNote != nil
                            || PurchaseManager.shared.canAddVoice(currentCount: person.voiceNotes.count) {
                            showVoiceRecorder = true
                        } else {
                            showingPaywall = true
                        }
                    } label: {
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
        guard PurchaseManager.shared.canExport else { showingPaywall = true; return }
        if let issue = chapterOrderIssue {
            orderWarning = issue   // 顺序存疑，先提醒，确认后再导出
            return
        }
        performExportPDF()
    }

    private func performExportPDF() {
        if let url = PDFExporter.makePDF(for: person) {
            exportItem = ExportItem(url: url)
        } else {
            showExportError = true
        }
    }

    private func exportArchive() {
        guard PurchaseManager.shared.canExport else { showingPaywall = true; return }
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

    /// 拖拽重排可见章节，写回连续 sortOrder；App列表与PDF目录都按 sortOrder 优先
    private func reorderNode(from fromID: UUID, to toID: UUID) {
        var arr = person.nodes.filter { $0.isVisible }
        guard let fromIdx = arr.firstIndex(where: { $0.id == fromID }),
              let toIdx = arr.firstIndex(where: { $0.id == toID }) else { return }
        let moved = arr.remove(at: fromIdx)
        arr.insert(moved, at: toIdx)
        for (i, n) in arr.enumerated() { n.sortOrder = i }
        try? context.save()
    }

    private var coverBlock: some View {
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
        }
    }

    private var infoBlock: some View {
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

                if let title = person.bgmTitle, !title.isEmpty {
                    Label(title, systemImage: "music.note")
                        .font(.system(size: isReader ? 16 : 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
        }
    }

    private var summaryBlock: some View {
        Group {
            if !person.summary.isEmpty {
                Text(ArchiveText.inline(person.summary))
                    .font(.system(size: isReader ? 22 : 15))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, isReader ? 44 : 30)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statValue(person.nodes.count, "unit.chapters")

            if isReader {
                statValue(person.photos.count, "unit.photos")
            } else {
                NavigationLink {
                    PhotoLibraryView(person: person)
                } label: {
                    HStack(spacing: 2) {
                        statValue(person.photos.count, "unit.photos")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.brown.opacity(0.72))
                    }
                }
                .buttonStyle(.plain)
            }

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
