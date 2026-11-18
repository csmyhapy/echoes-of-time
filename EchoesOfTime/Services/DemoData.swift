//
//  DemoData.swift
//  EchoesOfTime
//
//  开发演示数据：插入一份带章节与照片的示例档案。
//  正式使用时用户通过 "New Archive" 建档，此数据仅用于验收浏览流程。
//

import Foundation
import SwiftData
import UIKit

enum DemoData {

    @MainActor
    static func insert(into context: ModelContext) {
        let person = Person(
            name: "Eleanor Whitfield",
            birthYear: "1929–2021",
            summary: String(localized: "library.sample.summary"),
            story: ""
        )
        context.insert(person)
        person.coverImageFileName = placeholder(personID: person.id, text: "E")

        let n1 = Node(
            name: "Childhood in Yorkshire",
            yearRange: "1929–1945",
            summary: "Growing up between the moors and the war years."
        )
        n1.sortOrder = 0
        n1.person = person
        context.insert(n1)
        addPhotos(to: n1, person: person, in: context,
                  captions: ["The cottage where I was born", "Summer on the moors"])

        let n2 = Node(
            name: "Teaching Years",
            yearRange: "1951–1989",
            summary: "Thirty-eight years in a small village school."
        )
        n2.sortOrder = 1
        n2.person = person
        context.insert(n2)
        addPhotos(to: n2, person: person, in: context,
                  captions: ["My first classroom", "The children's garden"])

        try? context.save()
    }

    private static func addPhotos(to node: Node, person: Person, in context: ModelContext, captions: [String]) {
        for (i, caption) in captions.enumerated() {
            guard let name = placeholder(personID: person.id, text: "\(i + 1)") else { continue }
            let photo = Photo(imageFileName: name, caption: caption)
            photo.sortOrder = i
            photo.node = node
            photo.person = person
            context.insert(photo)
            if i == 0 { node.coverImageFileName = name }
        }
    }

    /// 棕色渐变占位图（仅演示用）
    private static func placeholder(personID: UUID, text: String) -> String? {
        let size = CGSize(width: 800, height: 800)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let colors = [
                UIColor(red: 0.29, green: 0.20, blue: 0.14, alpha: 1).cgColor,
                UIColor(red: 0.61, green: 0.47, blue: 0.34, alpha: 1).cgColor
            ]
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors as CFArray, locations: [0, 1]) {
                ctx.cgContext.drawLinearGradient(g, start: .zero,
                                                 end: CGPoint(x: size.width, y: size.height),
                                                 options: [])
            }
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 160, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85)
            ]
            let s = NSAttributedString(string: text, attributes: attrs)
            let sz = s.size()
            s.draw(at: CGPoint(x: (size.width - sz.width) / 2,
                               y: (size.height - sz.height) / 2))
        }
        return MediaStore.saveImage(img, personID: personID)
    }
}
