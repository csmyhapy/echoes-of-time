//
//  ArchiveExporter.swift
//  EchoesOfTime
//
//  导出档案包：data.json + media/ 打成一个 .echosarchive.zip。
//  该格式同时作为 P6「从网站迁移」的导入格式。
//

import Foundation

enum ArchiveExporter {

    static func makeArchive(for person: Person) -> URL? {
        guard let json = try? JSONEncoder.archive.encode(makeDTO(for: person)) else { return nil }

        var entries: [(String, Data)] = [("data.json", json)]

        let folder = MediaStore.folder(for: person.id)
        if let contents = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for fileURL in contents {
                let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                guard !isDir, let data = try? Data(contentsOf: fileURL) else { continue }
                entries.append(("media/" + fileURL.lastPathComponent, data))
            }
        }

        let zipData = ZipWriter.make(entries: entries)
        let name = PDFExporter.safeFileName(person.name)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name).echosarchive.zip")
        do {
            try zipData.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - DTO

    private static func makeDTO(for person: Person) -> PersonArchiveDTO {
        let nodes = person.nodes
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { node in
                NodeArchiveDTO(
                    name: node.name,
                    yearRange: node.yearRange,
                    summary: node.summary,
                    story: node.story,
                    coverImageFileName: node.coverImageFileName,
                    sortOrder: node.sortOrder,
                    isVisible: node.isVisible,
                    photos: node.photos
                        .sorted { $0.sortOrder < $1.sortOrder }
                        .map { photo in
                            PhotoArchiveDTO(
                                imageFileName: photo.imageFileName,
                                audioFileName: photo.audioFileName,
                                caption: photo.caption,
                                story: photo.story,
                                tags: photo.tags,
                                sortOrder: photo.sortOrder
                            )
                        }
                )
            }

        let voices = person.voiceNotes
            .sorted { $0.createdAt < $1.createdAt }
            .map { note in
                VoiceArchiveDTO(
                    scope: note.scopeRaw,
                    targetID: note.targetID?.uuidString,
                    audioFileName: note.audioFileName,
                    duration: note.duration
                )
            }

        let messages = person.messages
            .filter { !$0.isDeleted }
            .sorted { $0.createdAt < $1.createdAt }
            .map { msg in
                MessageArchiveDTO(
                    userName: msg.userName,
                    content: msg.content,
                    role: msg.role,
                    createdAt: msg.createdAt,
                    nodeName: msg.node?.name,
                    photoCaption: msg.photo?.caption,
                    isPersonLevel: msg.node == nil && msg.photo == nil
                )
            }

        return PersonArchiveDTO(
            app: "EchoesOfTime",
            version: 1,
            exportedAt: Date(),
            name: person.name,
            birthYear: person.birthYear,
            summary: person.summary,
            story: person.story,
            coverImageFileName: person.coverImageFileName,
            nodes: nodes,
            voiceNotes: voices,
            messages: messages
        )
    }
}

// MARK: - 数据结构

struct PersonArchiveDTO: Codable {
    var app: String
    var version: Int
    var exportedAt: Date
    var name: String
    var birthYear: String
    var summary: String
    var story: String
    var coverImageFileName: String?
    var nodes: [NodeArchiveDTO]
    var voiceNotes: [VoiceArchiveDTO]
    var messages: [MessageArchiveDTO]
    /// 只在照片库、未分配到任何章节的照片（网站 tags 为空的那批）
    var unassignedPhotos: [PhotoArchiveDTO]? = nil
}

struct NodeArchiveDTO: Codable {
    /// 来源网站的节点 ID，导入时用于把照片的多章节标签映射回本机节点
    var webID: Int? = nil
    var name: String
    var yearRange: String
    var summary: String
    var story: String
    var coverImageFileName: String?
    var sortOrder: Int
    var isVisible: Bool
    var photos: [PhotoArchiveDTO]
}

struct PhotoArchiveDTO: Codable {
    var imageFileName: String
    var audioFileName: String?
    var caption: String
    var story: String
    var tags: String
    var sortOrder: Int
    /// 来源网站的 tags 字段（可属于多个章节），导入时映射为 App 内的节点 UUID 列表
    var webNodeIDs: [Int]? = nil
}

struct VoiceArchiveDTO: Codable {
    var scope: String
    var targetID: String?
    var audioFileName: String
    var duration: Int
}

struct MessageArchiveDTO: Codable {
    var userName: String
    var content: String
    var role: String
    var createdAt: Date
    var nodeName: String?
    var photoCaption: String?
    var isPersonLevel: Bool
}

extension JSONEncoder {
    static var archive: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

// MARK: - 最小 ZIP 写入器（stored，无压缩，通用可解压）

enum ZipWriter {

    static func make(entries: [(String, Data)]) -> Data {
        var local = Data()
        var central = Data()
        let (dosTime, dosDate) = dosDateTime(Date())

        for (name, data) in entries {
            let nameData = Data(name.utf8)
            let crc = crc32(data)
            let offset = UInt32(local.count)

            // 本地文件头
            var header = Data()
            header.appendLE(UInt32(0x0403_4B50))
            header.appendLE(UInt16(20))
            header.appendLE(UInt16(0x0800))          // UTF-8 文件名
            header.appendLE(UInt16(0))               // stored
            header.appendLE(dosTime)
            header.appendLE(dosDate)
            header.appendLE(crc)
            header.appendLE(UInt32(data.count))
            header.appendLE(UInt32(data.count))
            header.appendLE(UInt16(nameData.count))
            header.appendLE(UInt16(0))
            header.append(nameData)

            local.append(header)
            local.append(data)

            // 中央目录
            var cd = Data()
            cd.appendLE(UInt32(0x0201_4B50))
            cd.appendLE(UInt16(20))
            cd.appendLE(UInt16(20))
            cd.appendLE(UInt16(0x0800))
            cd.appendLE(UInt16(0))
            cd.appendLE(dosTime)
            cd.appendLE(dosDate)
            cd.appendLE(crc)
            cd.appendLE(UInt32(data.count))
            cd.appendLE(UInt32(data.count))
            cd.appendLE(UInt16(nameData.count))
            cd.appendLE(UInt16(0))
            cd.appendLE(UInt16(0))
            cd.appendLE(UInt16(0))
            cd.appendLE(UInt16(0))
            cd.appendLE(UInt32(0))
            cd.appendLE(offset)
            cd.append(nameData)
            central.append(cd)
        }

        var eocd = Data()
        eocd.appendLE(UInt32(0x0605_4B50))
        eocd.appendLE(UInt16(0))
        eocd.appendLE(UInt16(0))
        eocd.appendLE(UInt16(entries.count))
        eocd.appendLE(UInt16(entries.count))
        eocd.appendLE(UInt32(central.count))
        eocd.appendLE(UInt32(local.count))
        eocd.appendLE(UInt16(0))

        var out = Data()
        out.append(local)
        out.append(central)
        out.append(eocd)
        return out
    }

    // MARK: - 辅助

    private static func dosDateTime(_ date: Date) -> (UInt16, UInt16) {
        let comps = Calendar(identifier: .gregorian)
            .dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = max(1980, comps.year ?? 1980)
        let time = UInt16(((comps.hour ?? 0) << 11) | ((comps.minute ?? 0) << 5) | ((comps.second ?? 0) / 2))
        let day = UInt16(((year - 1980) << 9) | ((comps.month ?? 1) << 5) | (comps.day ?? 1))
        return (time, day)
    }

    private static let crcTable: [UInt32] = {
        var table = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1) != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1
            }
            table[i] = c
        }
        return table
    }()

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }
}

private extension Data {
    mutating func appendLE(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
    }

    mutating func appendLE(_ value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 24) & 0xFF))
    }
}
