package life.lifememory.echosoftime.data

import android.content.Context
import java.io.FileOutputStream

/**
 * 演示档案：中英文各一套，按当前界面语言自动选择（与 iOS DemoData.swift 一致）。
 * 英文 → Eleanor Whitfield（约克郡乡村教师）；中文 → 王秀兰（长沙纺织厂女工）。
 * 照片与旁白是打包在 assets 内的示例资源，首次插入时复制到本地媒体目录。
 */
object DemoData {

    fun demoLanguageOf(person: PersonEntity): AppLanguage? = when (person.name) {
        "Eleanor Whitfield" -> AppLanguage.EN
        "王秀兰" -> AppLanguage.ZH_HANS
        else -> null
    }

    suspend fun insert(repo: EchoRepository, ctx: Context, language: AppLanguage) {
        when (language) {
            AppLanguage.ZH_HANS -> insertChinese(repo, ctx)
            else -> insertEnglish(repo, ctx)
        }
    }

    // MARK: - English demo

    private suspend fun insertEnglish(repo: EchoRepository, ctx: Context) {
        val personId = repo.createPerson(
            name = "Eleanor Whitfield",
            birthYear = "1929–2021",
            summary = "A schoolteacher from the Yorkshire moors. She kept every report card, every pressed flower, and every letter her husband wrote during the war.",
            story = "This is a fictional demo archive, created to show how Echoes of Time works. Eleanor's chapters are invented, but the shape is real: one chapter for each season of a life, with the photographs, the voice, and the small stories that go with them.",
            bgmFileName = "bgm_demo.m4a",
            isDemo = true,
        )
        repo.person(personId)?.let { p ->
            repo.updatePerson(p.copy(coverImageFileName = copyPhoto(ctx, "demo_en_cover", personId)))
        }

        copyAudio(ctx, "demo_en_person", personId)?.let {
            repo.savePersonVoice(personId, null, it, 35)
        }

        // Chapter 1: Childhood
        val n0 = repo.insertNode(
            personId,
            name = "Childhood in Yorkshire",
            yearRange = "1929–1945",
            summary = "Growing up between the moors and the war years.",
            story = "I grew up in a stone cottage between the moors and the fields. My mother kept the fire and the garden, and my father worked the land. The village school had wooden desks and a chalkboard on the wall, and we walked there each morning across the fields. Those years were hard, but what I remember is the light on the moors.",
            sortOrder = 0,
        )
        copyAudio(ctx, "demo_en_node_childhood", personId)?.let {
            repo.saveNodeVoice(personId, n0.id, null, it, 30)
        }
        addPhoto(repo, ctx, personId, n0, "demo_en_childhood", "The cottage where I was born", "The cottage where I was born, with the moors behind it.", null, 0)
        addPhoto(repo, ctx, personId, n0, "demo_en_child_play", "Playing by the dry-stone wall", "Me at seven, playing by the dry-stone wall. The wind never stops up there.", "demo_en_photo_play", 1)
        addPhoto(repo, ctx, personId, n0, "demo_en_child_school", "The village classroom", "Wooden desks, a chalkboard, and one teacher for all the ages.", null, 2)
        addPhoto(repo, ctx, personId, n0, "demo_en_child_mother", "Mother at the kitchen fire", "My mother at the kitchen fire, where she kept us fed and warm.", null, 3)
        repo.insertMessage(personId, n0.id, null, "Margaret", "You always talked about the moors. I can still see you running along that wall.")

        // Chapter 2: Wedding
        val n1 = repo.insertNode(
            personId,
            name = "Our Wedding Day",
            yearRange = "1953",
            summary = "A small church wedding, and a borrowed dress.",
            story = "We married in the parish church in June 1953. My dress was borrowed, and the village gave us a small tea in the hall. He was quiet and steady, and we stayed together for nearly sixty years. The portrait was taken a week later, and we laughed through most of it.",
            sortOrder = 1,
        )
        copyAudio(ctx, "demo_en_node_wedding", personId)?.let { repo.saveNodeVoice(personId, n1.id, null, it, 28) }
        addPhoto(repo, ctx, personId, n1, "demo_en_wedding", "Just married, June 1953", "Our wedding day at the parish church, June 1953.", null, 0)
        addPhoto(repo, ctx, personId, n1, "demo_en_wed_church", "Family at the church door", "Family and friends crowded at the church door to wave us off.", null, 1)
        val portrait = addPhoto(repo, ctx, personId, n1, "demo_en_wed_portrait", "The studio portrait", "Taken a week later. He was so serious, and I could not stop smiling.", "demo_en_photo_portrait", 2)
        addPhoto(repo, ctx, personId, n1, "demo_en_wed_chest", "The hope chest", "Folded linens, knitted blankets, and our wedding teacups.", null, 3)
        repo.insertMessage(personId, n1.id, null, "Dorothy", "I lent you that blue coat for the church, and you laughed all the way through the photos.")
        portrait?.let { repo.insertMessage(personId, null, it.id, "Dorothy", "So proper, the two of you. You looked like a wedding plate from the cupboard.") }

        // Chapter 3: Teaching
        val n2 = repo.insertNode(
            personId,
            name = "Teaching Years",
            yearRange = "1951–1989",
            summary = "Thirty-eight years in a two-room village school.",
            story = "I began teaching at sixteen and stayed in that two-room school for thirty-eight years. I knew every child by name, and I kept their report cards and their pressed flowers long after they had grown up. The children came and went, but the classroom stayed the same.",
            sortOrder = 2,
        )
        copyAudio(ctx, "demo_en_node_teacher", personId)?.let { repo.saveNodeVoice(personId, n2.id, null, it, 33) }
        val klass = addPhoto(repo, ctx, personId, n2, "demo_en_teacher", "My first classroom", "The classroom where I taught for thirty-eight years.", null, 0)
        addPhoto(repo, ctx, personId, n2, "demo_en_teach_staff", "The school staff", "The teachers, outside the old stone door.", null, 1)
        addPhoto(repo, ctx, personId, n2, "demo_en_teach_class", "At the blackboard", "Reading and arithmetic. I still remember every child's voice.", "demo_en_photo_class", 2)
        addPhoto(repo, ctx, personId, n2, "demo_en_teach_walk", "Walking home from school", "Children along the stone wall at the end of the school day.", null, 3)
        repo.insertMessage(personId, n2.id, null, "Alice", "You were the one who taught me to read. I never forgot you.")
        klass?.let { repo.insertMessage(personId, null, it.id, "Alice", "I sat in the front row, and you marked every story of mine.") }

        // Chapter 4: Later Years
        val n3 = repo.insertNode(
            personId,
            name = "Later Years",
            yearRange = "1990–2021",
            summary = "The garden, the grandchildren, and the old photo albums.",
            story = "After I retired, I kept the garden and read the old albums. The grandchildren came on Sundays, and we sat together and looked at the photographs. Life grew quiet, but it was full, and I was grateful for every year.",
            sortOrder = 3,
        )
        copyAudio(ctx, "demo_en_node_later", personId)?.let { repo.saveNodeVoice(personId, n3.id, null, it, 28) }
        val grandkid = addPhoto(repo, ctx, personId, n3, "demo_en_later", "Reading the old albums", "Reading the old albums in the garden room.", null, 0)
        addPhoto(repo, ctx, personId, n3, "demo_en_late_garden", "My garden", "Where I spent every quiet afternoon.", null, 1)
        addPhoto(repo, ctx, personId, n3, "demo_en_late_grandkid", "Sunday afternoons", "With the grandchildren, reading together on the sofa.", "demo_en_photo_grandkid", 2)
        addPhoto(repo, ctx, personId, n3, "demo_en_late_album", "The leather album", "All the photographs spread out on the table.", null, 3)
        repo.insertMessage(personId, n3.id, null, "Margaret", "Mum kept every card we sent. The garden was her whole world.")
        grandkid?.let { repo.insertMessage(personId, null, it.id, "Emily", "I loved Sunday afternoons on the sofa with you.") }

        // 人物级留言
        repo.insertMessage(personId, null, null, "Emily", "We kept your photographs and your words. We look at them whenever we miss you.")
    }

    // MARK: - 中文演示

    private suspend fun insertChinese(repo: EchoRepository, ctx: Context) {
        val personId = repo.createPerson(
            name = "王秀兰",
            birthYear = "1936–2022",
            summary = "长沙的一位普通女工，在纺织厂干了三十年。她留着每一张工牌、每一张粮票，还有儿女从小到大的成绩单。",
            story = "这是为了体验「忆生相伴」而制作的虚构演示档案。王秀兰的人生是编的，但章节的结构是真的：一段人生一个章节，配上当时的照片、声音和几句家常话。",
            bgmFileName = "bgm_demo.m4a",
            isDemo = true,
        )
        repo.person(personId)?.let { p ->
            repo.updatePerson(p.copy(coverImageFileName = copyPhoto(ctx, "demo_zh_cover", personId)))
        }

        copyAudio(ctx, "demo_person", personId)?.let { repo.savePersonVoice(personId, null, it, 37) }

        // 第一章 童年时光
        val n0 = repo.insertNode(
            personId,
            name = "童年时光",
            yearRange = "1936–1949",
            summary = "在湘江边的土砖屋里长大，屋后有稻田，门前有池塘。",
            story = "我生在湘江边的土砖屋，屋后是稻田，门前一口塘。娘在青石台阶上捶衣服，孩子们在塘边玩水。村小学就在祠堂旁边，木课桌，土墙上一块木黑板。日子苦，可记得的都是亮的。",
            sortOrder = 0,
        )
        copyAudio(ctx, "demo_node_childhood", personId)?.let { repo.saveNodeVoice(personId, n0.id, null, it, 21) }
        addPhoto(repo, ctx, personId, n0, "demo_zh_childhood", "老屋门前，八岁那年", "这是我八岁，站在老屋门前，身后是土砖墙。", null, 0)
        addPhoto(repo, ctx, personId, n0, "demo_zh_c1", "塘边玩水", "夏天光着脚在塘边，水刚没过小腿，凉丝丝的。", "demo_photo_c1", 1)
        addPhoto(repo, ctx, personId, n0, "demo_zh_c2", "村小学的木课桌", "教室在祠堂旁，土墙上一块木黑板，我们坐长条板凳。", null, 2)
        addPhoto(repo, ctx, personId, n0, "demo_zh_c3", "娘在河边捶衣服", "娘蹲在青石台阶上捶衣服，一锤子一锤子，声音传得很远。", null, 3)
        repo.insertMessage(personId, n0.id, null, "王志强", "姐，你总说那口塘，我记着。那年夏天你把我从水里拽上来，自己也吓了一身水。")

        // 第二章 我们的婚礼
        val n1 = repo.insertNode(
            personId,
            name = "我们的婚礼",
            yearRange = "1962",
            summary = "一件红棉袄，一屋子的乡亲，和墙上那个大大的双喜。",
            story = "六二年冬天结的婚。红棉袄是跟表姐借的，院子里摆了八桌，墙上贴个大红喜字。他穿一件洗得发白的中山装，站得笔直。照相馆的结婚照是第二年补的。",
            sortOrder = 1,
        )
        copyAudio(ctx, "demo_node_wedding", personId)?.let { repo.saveNodeVoice(personId, n1.id, null, it, 25) }
        addPhoto(repo, ctx, personId, n1, "demo_zh_wedding", "结婚那天，院子里", "结婚那天院子里摆酒席，亲戚都来了。", null, 0)
        addPhoto(repo, ctx, personId, n1, "demo_zh_w1", "院子里摆了八桌", "乡亲们围坐在方桌旁，墙上贴着大红喜字。", null, 1)
        val w2 = addPhoto(repo, ctx, personId, n1, "demo_zh_w2", "第二年补照的结婚照", "照相馆里补的，他嫌自己站得太直，像根电线杆。", "demo_photo_w2", 2)
        addPhoto(repo, ctx, personId, n1, "demo_zh_w3", "陪嫁的木箱和被褥", "木箱、红被褥、搪瓷脸盆，一样一样摆好。", null, 3)
        repo.insertMessage(personId, n1.id, null, "李桂芳", "红棉袄是我陪你去借的，你穿上就一直笑，新郎官站得比电线杆还直。")
        w2?.let { repo.insertMessage(personId, null, it.id, "李桂芳", "这张补照的，你俩站得真端正，像年画里的人。") }

        // 第三章 纺织厂的岁月
        val n2 = repo.insertNode(
            personId,
            name = "纺织厂的岁月",
            yearRange = "1958–1990",
            summary = "在织布机前站了三十年，听惯了机器响。",
            story = "五八年进的纺织厂，织布机一响就是一整天，三班倒。站久了腿肿，耳朵到现在还嗡嗡的。一整班姐妹们在一起，中午拎着铝饭盒去食堂，那是我年轻最有劲的十几年。",
            sortOrder = 2,
        )
        copyAudio(ctx, "demo_node_factory", personId)?.let { repo.saveNodeVoice(personId, n2.id, null, it, 23) }
        val worker = addPhoto(repo, ctx, personId, n2, "demo_zh_worker", "车间里的织布机", "我在这台织布机前站了三十年，闭着眼都知道哪根线断了。", "demo_photo_worker", 0)
        addPhoto(repo, ctx, personId, n2, "demo_zh_k1", "厂门口的班组合影", "一整班姐妹在厂门口合影，蓝工装，工作帽。", null, 1)
        addPhoto(repo, ctx, personId, n2, "demo_zh_k2", "食堂的铝饭盒", "中午拎着饭盒去食堂，姐妹们凑一桌吃饭。", null, 2)
        addPhoto(repo, ctx, personId, n2, "demo_zh_k3", "下班骑车回家", "下班路上一队人骑自行车，沿路的杨树叶子沙沙响。", null, 3)
        repo.insertMessage(personId, n2.id, null, "张玉梅", "三班的姐妹们还记得你，机器一响，你说话最响。")
        worker?.let { repo.insertMessage(personId, null, it.id, "张玉梅", "这台机器我也熟，我们班当年就是在它旁边下的班。") }

        // 第四章 晚年生活
        val n3 = repo.insertNode(
            personId,
            name = "晚年生活",
            yearRange = "1991–2022",
            summary = "院子里晾着辣椒，孙子孙女围着桌子包饺子。",
            story = "退休以后，我就在院子里种点辣椒，红了就挂在屋檐下。孙子孙女一回来，我就擀皮包饺子。日子慢，人也老了，可一大家子坐在一起，我心里就踏实。",
            sortOrder = 3,
        )
        copyAudio(ctx, "demo_node_later", personId)?.let { repo.saveNodeVoice(personId, n3.id, null, it, 21) }
        val later = addPhoto(repo, ctx, personId, n3, "demo_zh_later", "和孙子孙女一起包饺子", "孙女包的歪歪扭扭，她还非要摆在最中间。", "demo_photo_later", 0)
        addPhoto(repo, ctx, personId, n3, "demo_zh_l1", "屋檐下挂的辣椒", "辣椒红了就挂在屋檐下，一串一串的。", null, 1)
        addPhoto(repo, ctx, personId, n3, "demo_zh_l2", "公园里晒太阳", "午后带孙子在公园长椅上坐坐，晒晒太阳。", null, 2)
        addPhoto(repo, ctx, personId, n3, "demo_zh_l3", "年夜饭全家福", "一大家子围圆桌坐满，桌上有鱼有饺子。", null, 3)
        repo.insertMessage(personId, n3.id, null, "王小梅", "妈，院子里的辣椒还挂着，我们没舍得摘，等你回来。")
        later?.let { repo.insertMessage(personId, null, it.id, "陈小雨", "奶奶，我现在也会包了，就是没您包得好看。") }

        repo.insertMessage(personId, null, null, "陈小雨", "奶奶，我们把您的照片和话都留着，想您了就翻一翻。")
    }

    // MARK: - 组装辅助

    private suspend fun addPhoto(
        repo: EchoRepository,
        ctx: Context,
        personId: String,
        node: NodeEntity,
        base: String,
        caption: String,
        story: String,
        audio: String?,
        order: Int,
    ): PhotoEntity? {
        val image = copyPhoto(ctx, base, personId) ?: return null
        val audioFile = audio?.let { copyAudio(ctx, it, personId) }
        val photoId = repo.insertPhoto(
            personId = personId,
            nodeId = node.id,
            imageFileName = image,
            audioFileName = audioFile,
            caption = caption,
            story = story,
            sortOrder = order,
            tags = node.id,
        )
        if (node.coverImageFileName == null) {
            repo.updateNode(node.copy(coverImageFileName = image))
        }
        return PhotoEntity(
            id = photoId, imageFileName = image, audioFileName = audioFile,
            caption = caption, story = story, tags = node.id,
            sortOrder = order, personId = personId, nodeId = node.id,
        )
    }

    /** 从 assets 复制演示照片到本地媒体目录，返回文件名（已存在则直接复用） */
    private fun copyPhoto(ctx: Context, base: String, personId: String): String? {
        val name = "$base.jpg"
        val dest = MediaStore.url(ctx, name, personId)
        if (dest.exists()) return name
        return try {
            ctx.assets.open("demo/photos/$base.jpg").use { input ->
                FileOutputStream(dest).use { input.copyTo(it) }
            }
            name
        } catch (_: Exception) {
            null
        }
    }

    /** 从 assets 复制演示旁白音频到本地媒体目录，返回文件名（固定覆盖刷新） */
    private fun copyAudio(ctx: Context, base: String, personId: String): String? {
        val name = "$base.m4a"
        val dest = MediaStore.url(ctx, name, personId)
        return try {
            ctx.assets.open("demo/voices/$base.m4a").use { input ->
                FileOutputStream(dest, false).use { input.copyTo(it) }
            }
            name
        } catch (_: Exception) {
            null
        }
    }
}
