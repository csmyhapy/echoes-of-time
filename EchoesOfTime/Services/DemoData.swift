//
//  DemoData.swift
//  EchoesOfTime
//
//  演示档案：中英文各一套，按当前界面语言自动选择。
//  英文界面 → Eleanor Whitfield（约克郡乡村教师）
//  中文界面 → 王秀兰（长沙纺织厂女工）
//  照片与旁白为打包在 App 内的示例资源，首次插入时复制到本地媒体目录。
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
        case .en, .es:
            // 西语 demo 尚未制作前，先回退英文档案，界面文案仍为西语
            insertEnglish(into: context)
        }
    }

    /// 判断这份档案是不是内置示例，返回它对应的语言
    static func demoLanguage(of person: Person) -> AppLanguage? {
        switch person.name {
        case "Eleanor Whitfield": return .en
        case "王秀兰": return .zhHans
        default: return nil
        }
    }

    // MARK: - English demo

    @MainActor
    private static func insertEnglish(into context: ModelContext) {
        let person = Person(
            name: "Eleanor Whitfield",
            birthYear: "1929–2021",
            summary: "A schoolteacher from the Yorkshire moors. She kept every report card, every pressed flower, and every letter her husband wrote during the war.",
            story: "This is a fictional demo archive, created to show how Echoes of Time works. Eleanor's chapters are invented, but the shape is real: one chapter for each season of a life, with the photographs, the voice, and the small stories that go with them.",
            isDemo: true
        )
        context.insert(person)
        person.coverImageFileName = importPhoto("demo_en_cover", personID: person.id)
        person.bgmFileName = "bgm_demo.m4a"

        // 人物人生旁白
        if let f = importAudio("demo_en_person", personID: person.id) {
            let note = VoiceNote(scope: .person, audioFileName: f, duration: 35)
            note.person = person
            context.insert(note)
        }

        // Chapter 1: Childhood
        let n0 = makeNode("Childhood in Yorkshire",
                          yearRange: "1929–1945",
                          summary: "Growing up between the moors and the war years.",
                          story: "I grew up in a stone cottage between the moors and the fields. My mother kept the fire and the garden, and my father worked the land. The village school had wooden desks and a chalkboard on the wall, and we walked there each morning across the fields. Those years were hard, but what I remember is the light on the moors.",
                          voice: "demo_en_node_childhood", voiceDur: 30,
                          order: 0, person: person, context: context)

        addPhoto("demo_en_childhood",
                 caption: "The cottage where I was born",
                 story: "The cottage where I was born, with the moors behind it.",
                 node: n0, person: person, order: 0, context: context)
        addPhoto("demo_en_child_play",
                 caption: "Playing by the dry-stone wall",
                 story: "Me at seven, playing by the dry-stone wall. The wind never stops up there.",
                 audio: "demo_en_photo_play",
                 node: n0, person: person, order: 1, context: context)
        addPhoto("demo_en_child_school",
                 caption: "The village classroom",
                 story: "Wooden desks, a chalkboard, and one teacher for all the ages.",
                 node: n0, person: person, order: 2, context: context)
        addPhoto("demo_en_child_mother",
                 caption: "Mother at the kitchen fire",
                 story: "My mother at the kitchen fire, where she kept us fed and warm.",
                 node: n0, person: person, order: 3, context: context)

        addMessage("Margaret", role: "family",
                   content: "You always talked about the moors. I can still see you running along that wall.",
                   person: person, node: n0, photo: nil, context: context)

        // Chapter 2: Wedding
        let n1 = makeNode("Our Wedding Day",
                          yearRange: "1953",
                          summary: "A small church wedding, and a borrowed dress.",
                          story: "We married in the parish church in June 1953. My dress was borrowed, and the village gave us a small tea in the hall. He was quiet and steady, and we stayed together for nearly sixty years. The portrait was taken a week later, and we laughed through most of it.",
                          voice: "demo_en_node_wedding", voiceDur: 28,
                          order: 1, person: person, context: context)

        addPhoto("demo_en_wedding",
                 caption: "Just married, June 1953",
                 story: "Our wedding day at the parish church, June 1953.",
                 node: n1, person: person, order: 0, context: context)
        addPhoto("demo_en_wed_church",
                 caption: "Family at the church door",
                 story: "Family and friends crowded at the church door to wave us off.",
                 node: n1, person: person, order: 1, context: context)
        let portrait = addPhoto("demo_en_wed_portrait",
                                caption: "The studio portrait",
                                story: "Taken a week later. He was so serious, and I could not stop smiling.",
                                audio: "demo_en_photo_portrait",
                                node: n1, person: person, order: 2, context: context)
        addPhoto("demo_en_wed_chest",
                 caption: "The hope chest",
                 story: "Folded linens, knitted blankets, and our wedding teacups.",
                 node: n1, person: person, order: 3, context: context)

        addMessage("Dorothy", role: "family",
                   content: "I lent you that blue coat for the church, and you laughed all the way through the photos.",
                   person: person, node: n1, photo: nil, context: context)
        addMessage("Dorothy", role: "family",
                   content: "So proper, the two of you. You looked like a wedding plate from the cupboard.",
                   person: person, node: nil, photo: portrait, context: context)

        // Chapter 3: Teaching
        let n2 = makeNode("Teaching Years",
                          yearRange: "1951–1989",
                          summary: "Thirty-eight years in a two-room village school.",
                          story: "I began teaching at sixteen and stayed in that two-room school for thirty-eight years. I knew every child by name, and I kept their report cards and their pressed flowers long after they had grown up. The children came and went, but the classroom stayed the same.",
                          voice: "demo_en_node_teacher", voiceDur: 33,
                          order: 2, person: person, context: context)

        let klass = addPhoto("demo_en_teacher",
                             caption: "My first classroom",
                             story: "The classroom where I taught for thirty-eight years.",
                             node: n2, person: person, order: 0, context: context)
        addPhoto("demo_en_teach_staff",
                 caption: "The school staff",
                 story: "The teachers, outside the old stone door.",
                 node: n2, person: person, order: 1, context: context)
        addPhoto("demo_en_teach_class",
                 caption: "At the blackboard",
                 story: "Reading and arithmetic. I still remember every child's voice.",
                 audio: "demo_en_photo_class",
                 node: n2, person: person, order: 2, context: context)
        addPhoto("demo_en_teach_walk",
                 caption: "Walking home from school",
                 story: "Children along the stone wall at the end of the school day.",
                 node: n2, person: person, order: 3, context: context)

        addMessage("Alice", role: "family",
                   content: "You were the one who taught me to read. I never forgot you.",
                   person: person, node: n2, photo: nil, context: context)
        addMessage("Alice", role: "family",
                   content: "I sat in the front row, and you marked every story of mine.",
                   person: person, node: nil, photo: klass, context: context)

        // Chapter 4: Later Years
        let n3 = makeNode("Later Years",
                          yearRange: "1990–2021",
                          summary: "The garden, the grandchildren, and the old photo albums.",
                          story: "After I retired, I kept the garden and read the old albums. The grandchildren came on Sundays, and we sat together and looked at the photographs. Life grew quiet, but it was full, and I was grateful for every year.",
                          voice: "demo_en_node_later", voiceDur: 28,
                          order: 3, person: person, context: context)

        let grandkid = addPhoto("demo_en_later",
                                caption: "Reading the old albums",
                                story: "Reading the old albums in the garden room.",
                                node: n3, person: person, order: 0, context: context)
        addPhoto("demo_en_late_garden",
                 caption: "My garden",
                 story: "Where I spent every quiet afternoon.",
                 node: n3, person: person, order: 1, context: context)
        addPhoto("demo_en_late_grandkid",
                 caption: "Sunday afternoons",
                 story: "With the grandchildren, reading together on the sofa.",
                 audio: "demo_en_photo_grandkid",
                 node: n3, person: person, order: 2, context: context)
        addPhoto("demo_en_late_album",
                 caption: "The leather album",
                 story: "All the photographs spread out on the table.",
                 node: n3, person: person, order: 3, context: context)

        addMessage("Margaret", role: "family",
                   content: "Mum kept every card we sent. The garden was her whole world.",
                   person: person, node: n3, photo: nil, context: context)
        addMessage("Emily", role: "family",
                   content: "I loved Sunday afternoons on the sofa with you.",
                   person: person, node: nil, photo: grandkid, context: context)

        // 人物级留言
        addMessage("Emily", role: "family",
                   content: "We kept your photographs and your words. We look at them whenever we miss you.",
                   person: person, node: nil, photo: nil, context: context)

        try? context.save()
    }

    // MARK: - 中文演示

    @MainActor
    private static func insertChinese(into context: ModelContext) {
        let person = Person(
            name: "王秀兰",
            birthYear: "1936–2022",
            summary: "长沙的一位普通女工，在纺织厂干了三十年。她留着每一张工牌、每一张粮票，还有儿女从小到大的成绩单。",
            story: "这是为了体验「忆生相伴」而制作的虚构演示档案。王秀兰的人生是编的，但章节的结构是真的：一段人生一个章节，配上当时的照片、声音和几句家常话。",
            isDemo: true
        )
        context.insert(person)
        person.coverImageFileName = importPhoto("demo_zh_cover", personID: person.id)
        person.bgmFileName = "bgm_demo.m4a"

        // 人物人生旁白
        if let f = importAudio("demo_person", personID: person.id) {
            let note = VoiceNote(scope: .person, audioFileName: f, duration: 37)
            note.person = person
            context.insert(note)
        }

        // 第一章 童年时光
        let n0 = makeNode("童年时光",
                          yearRange: "1936–1949",
                          summary: "在湘江边的土砖屋里长大，屋后有稻田，门前有池塘。",
                          story: "我生在湘江边的土砖屋，屋后是稻田，门前一口塘。娘在青石台阶上捶衣服，孩子们在塘边玩水。村小学就在祠堂旁边，木课桌，土墙上一块木黑板。日子苦，可记得的都是亮的。",
                          voice: "demo_node_childhood", voiceDur: 21,
                          order: 0, person: person, context: context)

        addPhoto("demo_zh_childhood",
                 caption: "老屋门前，八岁那年",
                 story: "这是我八岁，站在老屋门前，身后是土砖墙。",
                 node: n0, person: person, order: 0, context: context)
        addPhoto("demo_zh_c1",
                 caption: "塘边玩水",
                 story: "夏天光着脚在塘边，水刚没过小腿，凉丝丝的。",
                 audio: "demo_photo_c1",
                 node: n0, person: person, order: 1, context: context)
        addPhoto("demo_zh_c2",
                 caption: "村小学的木课桌",
                 story: "教室在祠堂旁，土墙上一块木黑板，我们坐长条板凳。",
                 node: n0, person: person, order: 2, context: context)
        addPhoto("demo_zh_c3",
                 caption: "娘在河边捶衣服",
                 story: "娘蹲在青石台阶上捶衣服，一锤子一锤子，声音传得很远。",
                 node: n0, person: person, order: 3, context: context)

        addMessage("王志强", role: "family",
                   content: "姐，你总说那口塘，我记着。那年夏天你把我从水里拽上来，自己也吓了一身水。",
                   person: person, node: n0, photo: nil, context: context)

        // 第二章 我们的婚礼
        let n1 = makeNode("我们的婚礼",
                          yearRange: "1962",
                          summary: "一件红棉袄，一屋子的乡亲，和墙上那个大大的双喜。",
                          story: "六二年冬天结的婚。红棉袄是跟表姐借的，院子里摆了八桌，墙上贴个大红喜字。他穿一件洗得发白的中山装，站得笔直。照相馆的结婚照是第二年补的。",
                          voice: "demo_node_wedding", voiceDur: 25,
                          order: 1, person: person, context: context)

        addPhoto("demo_zh_wedding",
                 caption: "结婚那天，院子里",
                 story: "结婚那天院子里摆酒席，亲戚都来了。",
                 node: n1, person: person, order: 0, context: context)
        addPhoto("demo_zh_w1",
                 caption: "院子里摆了八桌",
                 story: "乡亲们围坐在方桌旁，墙上贴着大红喜字。",
                 node: n1, person: person, order: 1, context: context)
        let w2 = addPhoto("demo_zh_w2",
                          caption: "第二年补照的结婚照",
                          story: "照相馆里补的，他嫌自己站得太直，像根电线杆。",
                          audio: "demo_photo_w2",
                          node: n1, person: person, order: 2, context: context)
        addPhoto("demo_zh_w3",
                 caption: "陪嫁的木箱和被褥",
                 story: "木箱、红被褥、搪瓷脸盆，一样一样摆好。",
                 node: n1, person: person, order: 3, context: context)

        addMessage("李桂芳", role: "family",
                   content: "红棉袄是我陪你去借的，你穿上就一直笑，新郎官站得比电线杆还直。",
                   person: person, node: n1, photo: nil, context: context)
        addMessage("李桂芳", role: "family",
                   content: "这张补照的，你俩站得真端正，像年画里的人。",
                   person: person, node: nil, photo: w2, context: context)

        // 第三章 纺织厂的岁月
        let n2 = makeNode("纺织厂的岁月",
                          yearRange: "1958–1990",
                          summary: "在织布机前站了三十年，听惯了机器响。",
                          story: "五八年进的纺织厂，织布机一响就是一整天，三班倒。站久了腿肿，耳朵到现在还嗡嗡的。一整班姐妹们在一起，中午拎着铝饭盒去食堂，那是我年轻最有劲的十几年。",
                          voice: "demo_node_factory", voiceDur: 23,
                          order: 2, person: person, context: context)

        let worker = addPhoto("demo_zh_worker",
                              caption: "车间里的织布机",
                              story: "我在这台织布机前站了三十年，闭着眼都知道哪根线断了。",
                              audio: "demo_photo_worker",
                              node: n2, person: person, order: 0, context: context)
        addPhoto("demo_zh_k1",
                 caption: "厂门口的班组合影",
                 story: "一整班姐妹在厂门口合影，蓝工装，工作帽。",
                 node: n2, person: person, order: 1, context: context)
        addPhoto("demo_zh_k2",
                 caption: "食堂的铝饭盒",
                 story: "中午拎着饭盒去食堂，姐妹们凑一桌吃饭。",
                 node: n2, person: person, order: 2, context: context)
        addPhoto("demo_zh_k3",
                 caption: "下班骑车回家",
                 story: "下班路上一队人骑自行车，沿路的杨树叶子沙沙响。",
                 node: n2, person: person, order: 3, context: context)

        addMessage("张玉梅", role: "family",
                   content: "三班的姐妹们还记得你，机器一响，你说话最响。",
                   person: person, node: n2, photo: nil, context: context)
        addMessage("张玉梅", role: "family",
                   content: "这台机器我也熟，我们班当年就是在它旁边下的班。",
                   person: person, node: nil, photo: worker, context: context)

        // 第四章 晚年生活
        let n3 = makeNode("晚年生活",
                          yearRange: "1991–2022",
                          summary: "院子里晾着辣椒，孙子孙女围着桌子包饺子。",
                          story: "退休以后，我就在院子里种点辣椒，红了就挂在屋檐下。孙子孙女一回来，我就擀皮包饺子。日子慢，人也老了，可一大家子坐在一起，我心里就踏实。",
                          voice: "demo_node_later", voiceDur: 21,
                          order: 3, person: person, context: context)

        let later = addPhoto("demo_zh_later",
                             caption: "和孙子孙女一起包饺子",
                             story: "孙女包的歪歪扭扭，她还非要摆在最中间。",
                             audio: "demo_photo_later",
                             node: n3, person: person, order: 0, context: context)
        addPhoto("demo_zh_l1",
                 caption: "屋檐下挂的辣椒",
                 story: "辣椒红了就挂在屋檐下，一串一串的。",
                 node: n3, person: person, order: 1, context: context)
        addPhoto("demo_zh_l2",
                 caption: "公园里晒太阳",
                 story: "午后带孙子在公园长椅上坐坐，晒晒太阳。",
                 node: n3, person: person, order: 2, context: context)
        addPhoto("demo_zh_l3",
                 caption: "年夜饭全家福",
                 story: "一大家子围圆桌坐满，桌上有鱼有饺子。",
                 node: n3, person: person, order: 3, context: context)

        addMessage("王小梅", role: "family",
                   content: "妈，院子里的辣椒还挂着，我们没舍得摘，等你回来。",
                   person: person, node: n3, photo: nil, context: context)
        addMessage("陈小雨", role: "family",
                   content: "奶奶，我现在也会包了，就是没您包得好看。",
                   person: person, node: nil, photo: later, context: context)

        // 人物级留言
        addMessage("陈小雨", role: "family",
                   content: "奶奶，我们把您的照片和话都留着，想您了就翻一翻。",
                   person: person, node: nil, photo: nil, context: context)

        try? context.save()
    }

    // MARK: - 组装

    @MainActor
    private static func makeNode(_ name: String,
                                 yearRange: String,
                                 summary: String,
                                 story: String,
                                 voice: String,
                                 voiceDur: Int,
                                 order: Int,
                                 person: Person,
                                 context: ModelContext) -> Node {
        let node = Node(name: name, yearRange: yearRange, summary: summary, story: story)
        node.sortOrder = order
        node.person = person
        context.insert(node)

        if let f = importAudio(voice, personID: person.id) {
            let note = VoiceNote(scope: .node, targetID: node.id, audioFileName: f, duration: voiceDur)
            note.person = person
            context.insert(note)
        }
        return node
    }

    @MainActor
    @discardableResult
    private static func addPhoto(_ base: String,
                                 caption: String,
                                 story: String,
                                 audio: String? = nil,
                                 node: Node,
                                 person: Person,
                                 order: Int,
                                 context: ModelContext) -> Photo? {
        guard let fileName = importPhoto(base, personID: person.id) else { return nil }
        var audioFile: String?
        if let audio { audioFile = importAudio(audio, personID: person.id) }
        let photo = Photo(imageFileName: fileName,
                          audioFileName: audioFile,
                          caption: caption,
                          story: story)
        photo.sortOrder = order
        photo.node = node
        photo.person = person
        context.insert(photo)
        if node.coverImageFileName == nil { node.coverImageFileName = fileName }
        return photo
    }

    @MainActor
    private static func addMessage(_ name: String,
                                   role: String,
                                   content: String,
                                   person: Person,
                                   node: Node?,
                                   photo: Photo?,
                                   context: ModelContext) {
        let m = Message(userName: name, content: content, role: role)
        m.person = person
        m.node = node
        m.photo = photo
        context.insert(m)
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

    /// 从 App 包内复制演示旁白音频到本地媒体目录，返回文件名
    private static func importAudio(_ base: String, personID: UUID) -> String? {
        let fileName = base + ".m4a"
        let dest = MediaStore.url(fileName: fileName, personID: personID)

        // Xcode 按 group 扁平拷贝到 bundle 根，也保留子目录两种可能
        let candidates = [
            Bundle.main.url(forResource: base, withExtension: "m4a"),
            Bundle.main.url(forResource: base, withExtension: "m4a", subdirectory: "DemoVoices")
        ]
        guard let source = candidates.compactMap({ $0 }).first else { return nil }

        do {
            // demo 资源固定，每次启动覆盖刷新，便于替换口音版本
            if FileManager.default.fileExists(atPath: dest.path) {
                try? FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: source, to: dest)
            return fileName
        } catch {
            return nil
        }
    }
}
