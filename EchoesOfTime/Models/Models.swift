//
//  Models.swift
//  EchoesOfTime
//
//  本地化数据模型：完全对应原网站 MySQL 表结构
//  persons / nodes / photos / voice_notes / messages
//  所有媒体文件以「文件名」形式存储，实际文件放在 App 沙盒 Media 目录下
//

import Foundation
import SwiftData

// MARK: - 人物档案（对应 persons 表）

@Model
final class Person {
    @Attribute(.unique) var id: UUID
    var name: String
    /// 生卒年，例如 "1929–2021"
    var birthYear: String
    var summary: String            // 对应 description
    var story: String              // 人生故事长文
    var coverImageFileName: String? // 封面图文件名（Media 目录内）
    var bgmFileName: String?        // 背景音乐文件名
    var createdAt: Date
    /// 内置示例档案（虚构、仅供体验），不占用正式档案名额
    var isDemo: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \Node.person)
    var nodes: [Node] = []

    @Relationship(deleteRule: .cascade, inverse: \Photo.person)
    var photos: [Photo] = []

    @Relationship(deleteRule: .cascade, inverse: \VoiceNote.person)
    var voiceNotes: [VoiceNote] = []

    @Relationship(deleteRule: .cascade, inverse: \Message.person)
    var messages: [Message] = []

    init(
        id: UUID = UUID(),
        name: String,
        birthYear: String = "",
        summary: String = "",
        story: String = "",
        coverImageFileName: String? = nil,
        createdAt: Date = .now,
        isDemo: Bool = false
    ) {
        self.id = id
        self.name = name
        self.birthYear = birthYear
        self.summary = summary
        self.story = story
        self.coverImageFileName = coverImageFileName
        self.createdAt = createdAt
        self.isDemo = isDemo
    }
}

// MARK: - 时间线章节（对应 nodes 表）

@Model
final class Node {
    @Attribute(.unique) var id: UUID
    var name: String
    /// 年代区间，例如 "1940–1955"
    var yearRange: String
    var summary: String
    var story: String
    var coverImageFileName: String?
    var sortOrder: Int
    var createdAt: Date
    var isVisible: Bool

    var person: Person?

    @Relationship(deleteRule: .cascade, inverse: \Photo.node)
    var photos: [Photo] = []

    init(
        id: UUID = UUID(),
        name: String,
        yearRange: String = "",
        summary: String = "",
        story: String = "",
        coverImageFileName: String? = nil,
        sortOrder: Int = 0,
        isVisible: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.yearRange = yearRange
        self.summary = summary
        self.story = story
        self.coverImageFileName = coverImageFileName
        self.sortOrder = sortOrder
        self.isVisible = isVisible
        self.createdAt = createdAt
    }
}

// MARK: - 照片（对应 photos 表）

@Model
final class Photo {
    @Attribute(.unique) var id: UUID
    var imageFileName: String       // 必填：Media 目录内图片文件名
    var audioFileName: String?      // 该照片的语音旁白
    var caption: String
    var story: String
    var tags: String
    var sortOrder: Int
    var createdAt: Date

    var person: Person?
    var node: Node?

    @Relationship(deleteRule: .cascade, inverse: \Message.photo)
    var messages: [Message] = []

    init(
        id: UUID = UUID(),
        imageFileName: String,
        audioFileName: String? = nil,
        caption: String = "",
        story: String = "",
        tags: String = "",
        sortOrder: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.imageFileName = imageFileName
        self.audioFileName = audioFileName
        self.caption = caption
        self.story = story
        self.tags = tags
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}

// MARK: - 语音旁白（对应 voice_notes 表）

enum VoiceNoteScope: String, Codable {
    case person
    case node
    case photo
}

@Model
final class VoiceNote {
    @Attribute(.unique) var id: UUID
    var scopeRaw: String            // "person" | "node" | "photo"
    /// 作用域目标 id（node id / photo id），人物级为 nil
    var targetID: UUID?
    var audioFileName: String
    /// 时长（秒）
    var duration: Int
    var createdAt: Date

    var person: Person?

    var scope: VoiceNoteScope {
        get { VoiceNoteScope(rawValue: scopeRaw) ?? .person }
        set { scopeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        scope: VoiceNoteScope,
        targetID: UUID? = nil,
        audioFileName: String,
        duration: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.scopeRaw = scope.rawValue
        self.targetID = targetID
        self.audioFileName = audioFileName
        self.duration = duration
        self.createdAt = createdAt
    }
}

// MARK: - 留言（对应 messages 表）

@Model
final class Message {
    @Attribute(.unique) var id: UUID
    var userName: String
    var content: String
    /// "family" / "visitor" 等
    var role: String
    var parentID: UUID?
    var createdAt: Date
    var isDeleted: Bool

    var person: Person?
    var node: Node?
    var photo: Photo?

    init(
        id: UUID = UUID(),
        userName: String,
        content: String,
        role: String = "family",
        parentID: UUID? = nil,
        isDeleted: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.userName = userName
        self.content = content
        self.role = role
        self.parentID = parentID
        self.isDeleted = isDeleted
        self.createdAt = createdAt
    }
}

// MARK: - 照片的多章节标签（对齐网站 tags 字段）

extension Photo {

    /// 所属章节 UUID 列表（存于 tags，逗号分隔）
    var taggedNodeIDs: [UUID] {
        tags.split(separator: ",").compactMap {
            UUID(uuidString: String($0).trimmingCharacters(in: .whitespaces))
        }
    }

    /// 是否属于某个章节：主章节命中，或任一标签命中
    func belongs(to node: Node) -> Bool {
        if self.node?.id == node.id { return true }
        return taggedNodeIDs.contains(node.id)
    }

    func setTaggedNodes(_ nodes: [Node]) {
        tags = nodes.map { $0.id.uuidString }.joined(separator: ",")
    }
}

// MARK: - 封面兜底（对齐网站：章节封面取 tags 里第一张照片）

extension Person {
    /// 人物封面：自身封面 → 第一张照片
    var resolvedCoverFileName: String? {
        if let c = coverImageFileName, !c.isEmpty { return c }
        return photos.sorted { $0.sortOrder < $1.sortOrder }.first?.imageFileName
    }
}

extension Node {
    /// 章节封面：自身封面 → 本章节第一张照片
    var resolvedCoverFileName: String? {
        if let c = coverImageFileName, !c.isEmpty { return c }
        guard let person else { return nil }
        return person.photos
            .filter { $0.belongs(to: self) }
            .sorted { $0.sortOrder < $1.sortOrder }
            .first?.imageFileName
    }

    /// 本章节实际照片数（按标签统计，不是单关系）
    var resolvedPhotoCount: Int {
        guard let person else { return photos.count }
        return person.photos.filter { $0.belongs(to: self) }.count
    }
}
