//
//  MediaStore.swift
//  EchoesOfTime
//
//  本地媒体存储：图片、音频全部落在 App 沙盒 Application Support/Media/<personID>/
//  数据库只保存文件名，避免二进制入库
//

import Foundation
import UIKit

enum MediaStore {

    static var rootURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Media", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func folder(for personID: UUID) -> URL {
        let dir = rootURL.appendingPathComponent(personID.uuidString, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func url(fileName: String, personID: UUID) -> URL {
        folder(for: personID).appendingPathComponent(fileName)
    }

    /// 保存图片（自动压缩：长边 <= 1600，JPEG 0.8），返回文件名
    @discardableResult
    static func saveImage(_ image: UIImage, personID: UUID) -> String? {
        let longSide: CGFloat = 1600
        let size = image.size
        let scale = min(1, longSide / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }

        guard let data = resized.jpegData(compressionQuality: 0.8) else { return nil }
        let name = UUID().uuidString + ".jpg"
        let dest = url(fileName: name, personID: personID)
        do {
            try data.write(to: dest, options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func loadImage(fileName: String?, personID: UUID) -> UIImage? {
        guard let fileName else { return nil }
        let path = url(fileName: fileName, personID: personID).path
        return UIImage(contentsOfFile: path)
    }

    static func deleteFile(fileName: String, personID: UUID) {
        try? FileManager.default.removeItem(at: url(fileName: fileName, personID: personID))
    }

    static func deleteFolder(for personID: UUID) {
        try? FileManager.default.removeItem(at: folder(for: personID))
    }
}
