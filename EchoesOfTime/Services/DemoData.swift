//
//  DemoData.swift
//  EchoesOfTime
//
//  演示档案：中英文各一套，按当前界面语言自动选择。
//  英文界面 → Eleanor Whitfield（约克郡乡村教师）
//  中文界面 → 王秀兰（长沙纺织厂女工）
//  照片为打包在 App 内的示例图，首次插入时复制到本地媒体目录。
//

import Foundation
import SwiftData
import UIKit

enum DemoData {

    @MainActor
    static func insert(into context: ModelContext, language: AppLanguage) {
        switch language {
        case .zhHans:
            insertChinese(into: context)
        case .en:
            insertEnglish(into: context)
        }
    }

    // MARK: - English demo

    @MainActor
    private static func insertEnglish(into context: ModelContext) {
        let person = Person(
            name: "Eleanor Whitfield",
            birthYear: "1929–2021",
            summary: "A schoolteacher from the Yorkshire moors. She kept every report card, every pressed flower, and every letter her husband wrote during the war.",
            story: "This is a fictional demo archive, created to show how Echoes of Time works. Eleanor's chapters are invented, but the shape is real: one chapter for each season of a life, with the photographs, the voice, and the small stories that go with them."
        )
        context.insert(person)
        person.coverImageFileName = importPhoto("demo_en_cover", personID: person.id)
        person.bgmFileName = "bgm_demo.m4a"

        addNode(name: "Childhood in Yorkshire",
                yearRange: "1929–1945",
                summary: "Growing up between the moors and the war years.",
                photoBase: "demo_en_childhood",
                caption: "The cottage where I was born",
                order: 0, to: person, in: context)

        addNode(name: "Our Wedding Day",
                yearRange: "1953",
                summary: "A small church wedding, and a borrowed dress.",
                photoBase: "demo_en_wedding",
                caption: "Just married, June 1953",
                order: 1, to: person, in: context)

        addNode(name: "Teaching Years",
                yearRange: "1951–1989",
                summary: "Thirty-eight years in a two-room village school.",
                photoBase: "demo_en_teacher",
                caption: "My first classroom",
                order: 2, to: person, in: context)

        addNode(name: "Later Years",
                yearRange: "1990–2021",
                summary: "The garden, the grandchildren, and the old photo albums.",
                photoBase: "demo_en_later",
                caption: "Reading the old albums in the garden",
                order: 3, to: person, in: context)

        try? context.save()
    }

    // MARK: - 中文演示

    @MainActor
    private static func insertChinese(into context: ModelContext) {
        let person = Person(
            name: "王秀兰",
            birthYear: "1936–2022",
            summary: "长沙的一位普通女工，在纺织厂干了三十年。她留着每一张工牌、每一张粮票，还有儿女从小到大的成绩单。",
            story: "这是为了体验「忆生相伴」而制作的虚构演示档案。王秀兰的人生是编的，但章节的结构是真的：一段人生一个章节，配上当时的照片、声音和几句家常话。"
        )
        context.insert(person)
        person.coverImageFileName = importPhoto("demo_zh_cover", personID: person.id)
        person.bgmFileName = "bgm_demo.m4a"

        addNode(name: "童年时光",
                yearRange: "1936–1949",
                summary: "在湘江边的土砖屋里长大，屋后有稻田，门前有池塘。",
                photoBase: "demo_zh_childhood",
                caption: "老屋门前，八岁那年",
                order: 0, to: person, in: context)

        addNode(name: "我们的婚礼",
                yearRange: "1962",
                summary: "一件红棉袄，一屋子的乡亲，和墙上那个大大的双喜。",
                photoBase: "demo_zh_wedding",
                caption: "结婚那天，院子里",
                order: 1, to: person, in: context)

        addNode(name: "纺织厂的岁月",
                yearRange: "1958–1990",
                summary: "在织布机前站了三十年，听惯了机器响。",
                photoBase: "demo_zh_worker",
                caption: "车间里的织布机",
                order: 2, to: person, in: context)

        addNode(name: "晚年生活",
                yearRange: "1991–2022",
                summary: "院子里晾着辣椒，孙子孙女围着桌子包饺子。",
                photoBase: "demo_zh_later",
                caption: "和孙子孙女一起包饺子",
                order: 3, to: person, in: context)

        try? context.save()
    }

    // MARK: - 组装

    @MainActor
    private static func addNode(name: String,
                                yearRange: String,
                                summary: String,
                                photoBase: String,
                                caption: String,
                                order: Int,
                                to person: Person,
                                in context: ModelContext) {
        let node = Node(name: name, yearRange: yearRange, summary: summary)
        node.sortOrder = order
        node.person = person
        context.insert(node)

        guard let fileName = importPhoto(photoBase, personID: person.id) else { return }
        let photo = Photo(imageFileName: fileName, caption: caption)
        photo.sortOrder = 0
        photo.node = node
        photo.person = person
        context.insert(photo)
        node.coverImageFileName = fileName
    }

    /// 从 App 包内复制演示照片到本地媒体目录，返回文件名
    private static func importPhoto(_ base: String, personID: UUID) -> String? {
        let fileName = base + ".jpg"
        let dest = MediaStore.url(fileName: fileName, personID: personID)
        if FileManager.default.fileExists(atPath: dest.path) { return fileName }

        let candidates = [
            Bundle.main.url(forResource: base, withExtension: "jpg"),
            Bundle.main.url(forResource: base, withExtension: "jpg", subdirectory: "DemoPhotos")
        ]
        guard let source = candidates.compactMap({ $0 }).first else { return nil }

        do {
            try FileManager.default.copyItem(at: source, to: dest)
            return fileName
        } catch {
            return nil
        }
    }
}
