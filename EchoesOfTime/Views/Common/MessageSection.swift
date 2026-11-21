//
//  MessageSection.swift
//  EchoesOfTime
//
//  家人留言区：可挂在人物、章节、照片上；只读模式下隐藏输入框。
//

import SwiftUI
import SwiftData
import UIKit

struct MessageSection: View {
    let person: Person
    let node: Node?
    let photo: Photo?
    var isReader: Bool = false
    /// 是否显示底部输入框；false 时仅展示留言（编辑入口放在别处）
    var showsInput: Bool = true

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var expanded = false
    @State private var draft = ""
    @State private var showingPaywall = false
    @State private var author = UserDefaults.standard.string(forKey: "familyName") ?? "Family"

    init(person: Person, node: Node? = nil, photo: Photo? = nil, isReader: Bool = false, showsInput: Bool = true) {
        self.person = person
        self.node = node
        self.photo = photo
        self.isReader = isReader
        self.showsInput = showsInput
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
                ForEach(visibleMessages) { msg in
                    messageRow(msg)
                }

                if messages.count > 2 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Text(moreText)
                            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .font(.system(size: isReader ? 18 : 14, weight: .medium))
                        .foregroundStyle(.brown)
                    }
                    .buttonStyle(.borderless)
                }
            }

            if showsInput && !isReader {
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
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }

    /// 默认只显示最新 2 条
    private var visibleMessages: [Message] {
        expanded ? messages : Array(messages.suffix(2))
    }

    private var moreText: String {
        appState.language == .zhHans
        ? (expanded ? "收起" : "查看全部 \(messages.count) 条留言")
        : (expanded ? "Show less" : "Show all \(messages.count) messages")
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
            Text(ArchiveText.inline(msg.content))
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

        let total = person.messages.filter { !$0.isDeleted }.count
        guard PurchaseManager.shared.canAddMessage(currentCount: total) else {
            showingPaywall = true
            return
        }

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

// MARK: - AI 写作协助提示（降低创作门槛：提示用户可把零散素材交给 AI 整理/润色，并附可复制提示词）

struct AIWriteHelper: View {
    enum Kind {
        /// 一句话简介：只给引导语，不附长提示词
        case summary
        /// 人生故事整体（人物档案长文）
        case lifeStory
        /// 章节故事（节点长文）
        case chapterStory
        /// 照片故事/配文
        case photoStory
    }

    let kind: Kind
    @State private var copied = false

    /// 中文环境展示中文提示词，其余语言展示英文提示词
    private var isChinese: Bool {
        (Bundle.main.preferredLocalizations.first ?? "en").hasPrefix("zh")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("ai.helper.title", systemImage: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.brown)

            Text(guide)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if kind != .summary {
                Button {
                    UIPasteboard.general.string = prompt
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: copied ? "checkmark.doc.on.doc" : "doc.on.doc")
                        Text(copied ? "ai.helper.copied" : "ai.helper.copy")
                        Spacer()
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.brown)
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var guide: String {
        switch kind {
        case .summary: return String(localized: "ai.helper.guide.summary")
        case .lifeStory: return String(localized: "ai.helper.guide.life")
        case .chapterStory: return String(localized: "ai.helper.guide.chapter")
        case .photoStory: return String(localized: "ai.helper.guide.photo")
        }
    }

    private var prompt: String { isChinese ? zhPrompt : enPrompt }

    private var zhPrompt: String {
        switch kind {
        case .summary: return ""
        case .lifeStory:
            return """
            请帮我把下面零散的人生经历整理成一篇平实、温暖的回忆录，按时间顺序组织，保留真实细节和我说话的口吻，不要编造我没提到的内容，篇幅适中。

            我的素材：（在这里粘贴你想到的人和事、时间、地点、感受，几条短句即可）
            """
        case .chapterStory:
            return """
            请帮我把这一段时期的零散回忆整理成一个章节，按时间和事件顺序写得通顺自然，保留具体细节、人物和当时的感受，不要添油加醋，文字朴实有温度。

            我的素材：（在这里粘贴这一阶段记得的几件事，几句话即可）
            """
        case .photoStory:
            return """
            请围绕这张照片，根据我给的零散信息写一段简短生动的说明，交代时间、地点、人物和当时的情境与感受，不虚构。

            我的素材：（在这里写这张照片拍于何时何地、有谁、发生了什么）
            """
        }
    }

    private var enPrompt: String {
        switch kind {
        case .summary: return ""
        case .lifeStory:
            return """
            Please help me organize these scattered memories of my life into a plain, warm memoir in chronological order. Keep the true details and my own voice; do not invent anything I did not mention; keep it a comfortable length.

            My notes: (paste the people, events, times, places, and feelings you remember here — a few short lines are enough)
            """
        case .chapterStory:
            return """
            Please help me turn these scattered recollections of this period into one chapter, ordered by time and events and written naturally. Keep the concrete details, people, and how I felt; do not embellish; keep the tone plain and warm.

            My notes: (paste a few things you remember from this period — a few sentences are enough)
            """
        case .photoStory:
            return """
            Based on the scattered notes I give you about this photo, write a short, lively caption: when it was taken, where, who is in it, and the situation and feelings at the time; do not make anything up.

            My notes: (write when and where this photo was taken, who is in it, and what was happening)
            """
        }
    }
}
