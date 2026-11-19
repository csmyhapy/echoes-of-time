//
//  LibraryView.swift
//  EchoesOfTime
//
//  首页：正式档案（一个 App 一位人物）+ 内置示例档案（不占名额，小卡展示）
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.createdAt, order: .reverse) private var persons: [Person]

    var isReader: Bool = false

    @State private var showingNewPerson = false
    @State private var showLimitAlert = false
    @State private var editingPerson: Person?
    @State private var addingChapterFor: Person?

    /// 用户自己的正式档案
    private var realPersons: [Person] { persons.filter { !$0.isDemo } }
    /// 内置示例（虚构，仅供体验）
    private var demoPersons: [Person] { persons.filter { $0.isDemo } }

    @ViewBuilder
    var body: some View {
        #if DEBUG
        // 调试：启动参数直达人物页/章节页（截图与排版核对用，Release 不编译）
        if let target = debugTarget, let first = realPersons.first {
            if target == "node" {
                let nodes = first.nodes.sorted { $0.sortOrder < $1.sortOrder }
                let node = debugNodeName.flatMap { name in nodes.first { $0.name == name } } ?? nodes.first
                if let node {
                    NodeDetailView(node: node, isReader: isReader)
                } else {
                    mainContent
                }
            } else if target == "person" {
                PersonDetailView(person: first, isReader: isReader)
            } else {
                mainContent
            }
        } else {
            mainContent
        }
        #else
        mainContent
        #endif
    }

    #if DEBUG
    private var debugTarget: String? {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("debug-node") { return "node" }
        if args.contains("debug-person") { return "person" }
        return nil
    }

    private var debugNodeName: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "debug-node"), args.count > i + 1 else { return nil }
        let next = args[i + 1]
        return next.hasPrefix("-") || next.hasPrefix("debug") ? nil : next
    }
    #endif

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                if realPersons.isEmpty && demoPersons.isEmpty {
                    emptyCard
                } else {
                    ForEach(realPersons) { person in
                        NavigationLink {
                            PersonDetailView(person: person, isReader: isReader)
                        } label: {
                            ArchiveCard(person: person, large: isReader)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if !isReader {
                                Button("common.edit") { editingPerson = person }
                                Button("common.delete", role: .destructive) { delete(person) }
                            }
                        }
                    }

                    if realPersons.isEmpty {
                        createPrompt
                    } else if realPersons.count == 1 {
                        actionButtons
                    } else if appState.isDeveloper {
                        // 多档案（开发者）：新建入口单独保留，其余操作在各档案详情页内
                        Button {
                            showingNewPerson = true
                        } label: {
                            Label("library.create.person", systemImage: "person.badge.plus")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                    }

                    if !demoPersons.isEmpty {
                        demoSection
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingNewPerson) {
            PersonEditView(person: nil)
        }
        .sheet(item: $editingPerson) { person in
            PersonEditView(person: person)
        }
        .sheet(item: $addingChapterFor) { person in
            NodeEditView(person: person, node: nil)
        }
        .alert("one.archive.limit.title", isPresented: $showLimitAlert) {
            Button("common.save", role: .cancel) {}
        } message: {
            Text("one.archive.limit.message")
        }
    }

    // MARK: - 顶部

    private var header: some View {
        VStack(spacing: 6) {
            Text("app.title")
                .font(.system(size: isReader ? 40 : 32, weight: .bold))
                .frame(maxWidth: .infinity)

            Text("library.subtitle")
                .font(.system(size: isReader ? 20 : 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    // MARK: - 空状态（连示例都没有）

    private var emptyCard: some View {
        VStack(spacing: 18) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.brown.opacity(0.75))

            VStack(spacing: 6) {
                Text("library.empty.title")
                    .font(.headline)
                Text("library.empty.desc")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !isReader {
                Button {
                    showingNewPerson = true
                } label: {
                    Label("library.create.person", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brown)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - 尚无正式档案时的建档引导（示例存在时显示）

    private var createPrompt: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(.brown.opacity(0.8))

            VStack(spacing: 4) {
                Text("library.create.first")
                    .font(.headline)
                Text("library.create.first.desc")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !isReader {
                Button {
                    showingNewPerson = true
                } label: {
                    Label("library.create.person", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brown)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - 正式档案的操作区

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                if appState.isDeveloper {
                    showingNewPerson = true   // 开发者：不限人物数量
                } else {
                    showLimitAlert = true     // 普通用户：一人一档
                }
            } label: {
                Label("library.create.person", systemImage: "person.badge.plus")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.bordered)
            .tint(.brown)

            Button {
                addingChapterFor = realPersons.first
            } label: {
                Label("library.action.addChapter", systemImage: "plus.rectangle.on.folder")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brown)

            Button {
                editingPerson = realPersons.first
            } label: {
                Label("library.action.editArchive", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(.brown)
        }
        .padding(.top, 2)
    }

    // MARK: - 示例档案区（小卡 + 明确标注）

    private var demoSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Text("demo.section.title")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("demo.section.note")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 2)

            ForEach(demoPersons) { person in
                NavigationLink {
                    PersonDetailView(person: person, isReader: isReader)
                } label: {
                    DemoRow(person: person)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if !isReader {
                        Button("common.delete", role: .destructive) { delete(person) }
                    }
                }
            }
        }
        .padding(.top, 6)
    }

    private func delete(_ person: Person) {
        MediaStore.deleteFolder(for: person.id)
        context.delete(person)
        try? context.save()
    }
}

// MARK: - 正式档案大卡片

struct ArchiveCard: View {
    let person: Person
    var large: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CoverImage(fileName: person.resolvedCoverFileName,
                       personID: person.id,
                       iconSize: large ? 56 : 40)
                .frame(maxWidth: .infinity)
                .frame(height: large ? 240 : 190)
                .clipped()

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.name)
                            .font(.system(size: large ? 32 : 24, weight: .bold))
                        if !person.birthYear.isEmpty {
                            Text(person.birthYear)
                                .font(.system(size: large ? 22 : 14))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: large ? 20 : 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }

                stats

                if !person.summary.isEmpty {
                    Text(person.summary)
                        .font(.system(size: large ? 20 : 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 4)
    }

    private var stats: some View {
        HStack(spacing: 14) {
            stat(person.nodes.count, "unit.chapters")
            stat(person.photos.count, "unit.photos")
            stat(person.voiceNotes.count, "unit.voice")
        }
    }

    private func stat(_ count: Int, _ key: String) -> some View {
        (Text("\(count) ") + Text(LocalizedStringKey(key)))
            .font(.system(size: large ? 18 : 12, weight: .medium))
            .foregroundStyle(.brown.opacity(0.85))
    }
}

// MARK: - 示例档案小卡

struct DemoRow: View {
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            CoverImage(fileName: person.coverImageFileName, personID: person.id, iconSize: 22)
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(person.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("demo.badge")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.brown.opacity(0.14))
                        .foregroundStyle(.brown)
                        .clipShape(Capsule())
                }
                if !person.birthYear.isEmpty {
                    Text(person.birthYear)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Text("demo.note")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - 封面图通用组件

struct CoverImage: View {
    let fileName: String?
    let personID: UUID
    var iconSize: CGFloat = 32

    var body: some View {
        Group {
            if let name = fileName,
               let img = MediaStore.loadImage(fileName: name, personID: personID) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [Color.brown.opacity(0.35), Color.brown.opacity(0.12)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: iconSize))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
    }
}
