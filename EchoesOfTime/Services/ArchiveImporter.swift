//
//  ArchiveImporter.swift
//  EchoesOfTime
//
//  导入档案包（.echosarchive.zip）：data.json + media/
//  包内为 Stored（无压缩）ZIP，读取后媒体落盘到 Media/<personID>/
//

import Foundation
import SwiftData

// MARK: - 最小 ZIP 读取器（仅支持 stored）

enum ZipReader {

    struct Entry {
        let name: String
        let data: Data
    }

    enum Failure: Error {
        case notZip
        case unsupportedCompression
    }

    static func read(_ raw: Data) throws -> [Entry] {
        guard let eocd = findEOCD(raw) else { throw Failure.notZip }
        let count = Int(raw.u16(eocd + 10))
        let cdOffset = Int(raw.u32(eocd + 16))

        var entries: [Entry] = []
        var p = cdOffset

        for _ in 0..<count {
            guard p + 46 <= raw.count, raw.u32(p) == 0x0201_4B50 else { break }
            let method = raw.u16(p + 10)
            let compressedSize = Int(raw.u32(p + 20))
            let nameLen = Int(raw.u16(p + 28))
            let extraLen = Int(raw.u16(p + 30))
            let commentLen = Int(raw.u16(p + 32))
            let localOffset = Int(raw.u32(p + 42))

            let nameStart = p + 46
            guard nameStart + nameLen <= raw.count else { break }
            let name = String(data: raw.subdata(in: nameStart..<(nameStart + nameLen)),
                              encoding: .utf8) ?? ""
            p = nameStart + nameLen + extraLen + commentLen

            guard method == 0 else { throw Failure.unsupportedCompression }
            guard localOffset + 30 <= raw.count, raw.u32(localOffset) == 0x0403_4B50 else { continue }

            let localNameLen = Int(raw.u16(localOffset + 26))
            let localExtraLen = Int(raw.u16(localOffset + 28))
            let start = localOffset + 30 + localNameLen + localExtraLen
            guard start >= 0, start + compressedSize <= raw.count else { continue }

            entries.append(Entry(name: name, data: raw.subdata(in: start..<(start + compressedSize))))
        }
        return entries
    }

    private static func findEOCD(_ raw: Data) -> Int? {
        guard raw.count >= 22 else { return nil }
        let lower = max(0, raw.count - 65_558)
        var i = raw.count - 22
        while i >= lower {
            if raw.u32(i) == 0x0605_4B50 { return i }
            i -= 1
        }
        return nil
    }
}

private extension Data {
    func u16(_ offset: Int) -> UInt16 {
        guard offset >= 0, offset + 2 <= count else { return 0 }
        return withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt16.self) }
    }

    func u32(_ offset: Int) -> UInt32 {
        guard offset >= 0, offset + 4 <= count else { return 0 }
        return withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }
    }
}

extension JSONDecoder {
    static var archive: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

// MARK: - 导入

enum ArchiveImporter {

    struct Outcome {
        let personName: String
        let nodeCount: Int
        let photoCount: Int
        let skippedPhotos: Int
    }

    enum ImportError: LocalizedError {
        case missingData
        case unreadable

        var errorDescription: String? {
            switch self {
            case .missingData: return "This archive package has no data.json."
            case .unreadable: return "The archive package could not be read."
            }
        }
    }

    static func importArchive(at url: URL, context: ModelContext) throws -> Outcome {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let raw = try? Data(contentsOf: url) else { throw ImportError.unreadable }
        let entries = try ZipReader.read(raw)

        guard let jsonData = entries.first(where: { $0.name == "data.json" })?.data else {
            throw ImportError.missingData
        }
        let dto = try JSONDecoder.archive.decode(PersonArchiveDTO.self, from: jsonData)

        let person = Person(
            name: dto.name.isEmpty ? "Untitled" : dto.name,
            birthYear: dto.birthYear,
            summary: dto.summary,
            story: dto.story
        )
        context.insert(person)

        // 媒体落盘
        let folder = MediaStore.folder(for: person.id)
        var writtenMedia: Set<String> = []
        for entry in entries where entry.name.hasPrefix("media/") {
            let fileName = String(entry.name.dropFirst("media/".count))
            guard !fileName.isEmpty, !fileName.contains("/") else { continue }
            do {
                try entry.data.write(to: folder.appendingPathComponent(fileName), options: .atomic)
                writtenMedia.insert(fileName)
            } catch {
                continue
            }
        }

        if let cover = dto.coverImageFileName, writtenMedia.contains(cover) {
            person.coverImageFileName = cover
        }
        person.bgmFileName = "bgm_demo.m4a"

        // 章节与照片
        var nodeByName: [String: Node] = [:]
        var photoByCaption: [String: Photo] = [:]
        var photoTotal = 0
        var skipped = 0

        for (index, nodeDTO) in dto.nodes.enumerated() {
            let node = Node(
                name: nodeDTO.name,
                yearRange: nodeDTO.yearRange,
                summary: nodeDTO.summary,
                story: nodeDTO.story,
                coverImageFileName: nodeDTO.coverImageFileName.flatMap { writtenMedia.contains($0) ? $0 : nil },
                sortOrder: nodeDTO.sortOrder,
                isVisible: nodeDTO.isVisible
            )
            node.person = person
            context.insert(node)
            nodeByName[nodeDTO.name] = node
            _ = index

            for photoDTO in nodeDTO.photos.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                guard writtenMedia.contains(photoDTO.imageFileName) else {
                    skipped += 1
                    continue
                }
                let photo = Photo(
                    imageFileName: photoDTO.imageFileName,
                    audioFileName: photoDTO.audioFileName.flatMap { writtenMedia.contains($0) ? $0 : nil },
                    caption: photoDTO.caption,
                    story: photoDTO.story,
                    tags: photoDTO.tags,
                    sortOrder: photoDTO.sortOrder
                )
                photo.person = person
                photo.node = node
                context.insert(photo)
                photoTotal += 1
                if !photoDTO.caption.isEmpty {
                    photoByCaption[photoDTO.caption] = photo
                }
            }
        }

        // 留言
        for messageDTO in dto.messages where !messageDTO.content.isEmpty {
            let message = Message(
                userName: messageDTO.userName,
                content: messageDTO.content,
                role: messageDTO.role,
                createdAt: messageDTO.createdAt
            )
            message.person = person
            if let nodeName = messageDTO.nodeName, let node = nodeByName[nodeName] {
                message.node = node
            }
            if let caption = messageDTO.photoCaption, let photo = photoByCaption[caption] {
                message.photo = photo
            }
            context.insert(message)
        }

        try context.save()

        return Outcome(
            personName: person.name,
            nodeCount: dto.nodes.count,
            photoCount: photoTotal,
            skippedPhotos: skipped
        )
    }
}
