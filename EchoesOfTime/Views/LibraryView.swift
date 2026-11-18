//
//  LibraryView.swift
//  EchoesOfTime
//
//  档案列表（编辑模式 / 长辈浏览模式共用）
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

    var body: some View {
        VStack(spacing: 0) {
            Text("app.title")
                .font(.system(size: isReader ? 40 : 32, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
                .padding(.bottom, 6)

            List {
            if persons.isEmpty {
                emptyState
            } else {
                ForEach(persons) { person in
                    NavigationLink {
                        PersonDetailView(person: person, isReader: isReader)
                    } label: {
                        PersonRow(person: person, large: isReader)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            delete(person)
                        } label: {
                            Label("common.delete", systemImage: "trash")
                        }
                    }
                }
            }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingNewPerson) {
            PersonEditView(person: nil)
        }
        .alert("one.archive.limit.title", isPresented: $showLimitAlert) {
            Button("common.save", role: .cancel) {}
        } message: {
            Text("one.archive.limit.message")
        }
        .toolbar {
            if !isReader {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if persons.isEmpty {
                            showingNewPerson = true
                        } else {
                            showLimitAlert = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("library.empty.title")
                .font(.headline)
            Text("library.empty.desc")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !isReader {
                Button {
                    DemoData.insert(into: context, language: appState.language)
                } label: {
                    Label("library.empty.demo", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .tint(.brown)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
    }

    private func delete(_ person: Person) {
        MediaStore.deleteFolder(for: person.id)
        context.delete(person)
        try? context.save()
    }
}

struct PersonRow: View {
    let person: Person
    var large: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            cover
            VStack(alignment: .leading, spacing: 4) {
                Text(person.name)
                    .font(.system(size: large ? 28 : 18, weight: .semibold))
                if !person.birthYear.isEmpty {
                    Text(person.birthYear)
                        .font(.system(size: large ? 20 : 14))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, large ? 8 : 2)
    }

    private var cover: some View {
        Group {
            if let img = MediaStore.loadImage(fileName: person.coverImageFileName, personID: person.id) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [Color.brown.opacity(0.25), Color.brown.opacity(0.1)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: large ? 40 : 26))
                        .foregroundStyle(.brown)
                }
            }
        }
        .frame(width: large ? 84 : 56, height: large ? 84 : 56)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
