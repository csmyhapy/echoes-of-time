//
//  MessageSection.swift
//  EchoesOfTime
//
//  家人留言区：可挂在人物、章节、照片上；只读模式下隐藏输入框。
//

import SwiftUI
import SwiftData

struct MessageSection: View {
    let person: Person
    let node: Node?
    let photo: Photo?
    var isReader: Bool = false

    @Environment(\.modelContext) private var context
    @State private var draft = ""
    @State private var author = UserDefaults.standard.string(forKey: "familyName") ?? "Family"

    init(person: Person, node: Node? = nil, photo: Photo? = nil, isReader: Bool = false) {
        self.person = person
        self.node = node
        self.photo = photo
        self.isReader = isReader
    }

    private var messages: [Message] {
        person.messages
            .filter { msg in
                guard !msg.isDeleted else { return false }
                if let photo {
                    return msg.photo?.id == photo.id
                }
                if let node {
                    return msg.photo == nil && msg.node?.id == node.id
                }
                return msg.node == nil && msg.photo == nil
            }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("messages.title")
                    .font(.system(size: isReader ? 24 : 18, weight: .semibold))
                Spacer()
                Text("\(messages.count)")
                    .font(.system(size: isReader ? 20 : 14))
                    .foregroundStyle(.secondary)
            }

            if messages.isEmpty {
                Text("messages.empty")
                    .font(.system(size: isReader ? 20 : 14))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(messages) { msg in
                    messageRow(msg)
                }
            }

            if !isReader {
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("messages.placeholder", text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        send()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(.brown)
                    }
                    .buttonStyle(.borderless)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func messageRow(_ msg: Message) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(msg.userName.isEmpty ? "Family" : msg.userName)
                    .font(.system(size: isReader ? 19 : 13, weight: .semibold))
                    .foregroundStyle(.brown)
                Spacer()
                Text(msg.createdAt, style: .date)
                    .font(.system(size: isReader ? 16 : 11))
                    .foregroundStyle(.secondary)
            }
            Text(msg.content)
                .font(.system(size: isReader ? 22 : 15))
                .lineSpacing(4)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brown.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
        .contextMenu {
            if !isReader {
                Button("common.delete", role: .destructive) {
                    context.delete(msg)
                    try? context.save()
                }
            }
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let msg = Message(
            userName: author.isEmpty ? "Family" : author,
            content: text,
            role: "family"
        )
        msg.person = person
        msg.node = node
        msg.photo = photo
        context.insert(msg)
        try? context.save()
        draft = ""
    }
}
