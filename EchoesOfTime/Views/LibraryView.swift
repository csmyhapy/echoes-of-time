//
//  LibraryView.swift
//  EchoesOfTime
//
//  首页：显示当前档案（一个 App 一位人物），并提供建档 / 添加章节 / 编辑入口。
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

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header

                if persons.isEmpty {
                    emptyCard
                } else {
                    ForEach(persons) { person in
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

                    actionButtons
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
        .padding(.bottom, 4)
    }

    // MARK: - 空状态

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

    // MARK: - 操作区

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                if persons.isEmpty {
                    showingNewPerson = true
                } else {
                    showLimitAlert = true
                }
            } label: {
                Label("library.create.person", systemImage: "person.badge.plus")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.bordered)
            .tint(.brown)

            Button {
                addingChapterFor = persons.first
            } label: {
                Label("library.action.addChapter", systemImage: "plus.rectangle.on.folder")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brown)

            Button {
                editingPerson = persons.first
            } label: {
                Label("library.action.editArchive", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(.brown)
        }
        .padding(.top, 4)
    }

    private func delete(_ person: Person) {
        MediaStore.deleteFolder(for: person.id)
        context.delete(person)
        try? context.save()
    }
}

// MARK: - 档案大卡片

struct ArchiveCard: View {
    let person: Person
    var large: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cover
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

    private var cover: some View {
        Group {
            if let img = MediaStore.loadImage(fileName: person.coverImageFileName, personID: person.id) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [Color.brown.opacity(0.35), Color.brown.opacity(0.12)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: large ? 56 : 40))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
