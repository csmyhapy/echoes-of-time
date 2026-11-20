package life.lifememory.echosoftime.data

import androidx.room.ColumnInfo
import androidx.room.Embedded
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import androidx.room.Relation

/*
 * 本地数据模型：与 iOS 的 SwiftData 五张表一一对应，也与原网站 MySQL 表结构一致。
 * persons / nodes / photos / voice_notes / messages
 * 媒体文件只存文件名，真实文件放在 filesDir/Media/<personID>/ 下。
 */

@Entity(tableName = "persons")
data class PersonEntity(
    @PrimaryKey val id: String,
    val name: String,
    val birthYear: String = "",
    val summary: String = "",
    val story: String = "",
    val coverImageFileName: String? = null,
    val bgmFileName: String? = null,
    val bgmTitle: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val isDemo: Boolean = false,
)

@Entity(
    tableName = "nodes",
    foreignKeys = [
        ForeignKey(
            entity = PersonEntity::class,
            parentColumns = ["id"],
            childColumns = ["personId"],
            onDelete = ForeignKey.CASCADE,
        )
    ],
    indices = [Index("personId")],
)
data class NodeEntity(
    @PrimaryKey val id: String,
    val name: String,
    val yearRange: String = "",
    val summary: String = "",
    val story: String = "",
    val coverImageFileName: String? = null,
    val sortOrder: Int = 0,
    val createdAt: Long = System.currentTimeMillis(),
    val isVisible: Boolean = true,
    /** 来源网站的节点顺序（导入时写入，用于保持网站上的章节排列） */
    val webOrder: Int = 0,
    val personId: String,
)

@Entity(
    tableName = "photos",
    foreignKeys = [
        ForeignKey(
            entity = PersonEntity::class,
            parentColumns = ["id"],
            childColumns = ["personId"],
            onDelete = ForeignKey.CASCADE,
        ),
        ForeignKey(
            entity = NodeEntity::class,
            parentColumns = ["id"],
            childColumns = ["nodeId"],
            onDelete = ForeignKey.SET_NULL,
        ),
    ],
    indices = [Index("personId"), Index("nodeId")],
)
data class PhotoEntity(
    @PrimaryKey val id: String,
    val imageFileName: String,
    val audioFileName: String? = null,
    val caption: String = "",
    val story: String = "",
    /** 多章节标签：逗号分隔的 node UUID（对齐网站 tags 字段） */
    val tags: String = "",
    val sortOrder: Int = 0,
    /** 导出 PDF 时与下一张并排同页 */
    val pairWithNext: Boolean = false,
    val createdAt: Long = System.currentTimeMillis(),
    val personId: String,
    val nodeId: String? = null,
)

@Entity(
    tableName = "voice_notes",
    foreignKeys = [
        ForeignKey(
            entity = PersonEntity::class,
            parentColumns = ["id"],
            childColumns = ["personId"],
            onDelete = ForeignKey.CASCADE,
        )
    ],
    indices = [Index("personId")],
)
data class VoiceNoteEntity(
    @PrimaryKey val id: String,
    /** "person" | "node" | "photo" */
    val scopeRaw: String,
    /** 作用域目标 id（node / photo），人物级为 null */
    val targetID: String? = null,
    val audioFileName: String,
    val duration: Int = 0,
    val createdAt: Long = System.currentTimeMillis(),
    val personId: String,
)

@Entity(
    tableName = "messages",
    foreignKeys = [
        ForeignKey(
            entity = PersonEntity::class,
            parentColumns = ["id"],
            childColumns = ["personId"],
            onDelete = ForeignKey.CASCADE,
        ),
        ForeignKey(
            entity = NodeEntity::class,
            parentColumns = ["id"],
            childColumns = ["nodeId"],
            onDelete = ForeignKey.SET_NULL,
        ),
        ForeignKey(
            entity = PhotoEntity::class,
            parentColumns = ["id"],
            childColumns = ["photoId"],
            onDelete = ForeignKey.SET_NULL,
        ),
    ],
    indices = [Index("personId"), Index("nodeId"), Index("photoId")],
)
data class MessageEntity(
    @PrimaryKey val id: String,
    val userName: String,
    val content: String,
    /** "family" / "visitor" */
    val role: String = "family",
    val parentID: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val isDeleted: Boolean = false,
    val personId: String,
    val nodeId: String? = null,
    val photoId: String? = null,
)

// MARK: - 聚合查询结果

data class PersonBundle(
    @Embedded val person: PersonEntity,
    @Relation(parentColumn = "id", entityColumn = "personId")
    val nodes: List<NodeEntity> = emptyList(),
    @Relation(parentColumn = "id", entityColumn = "personId")
    val photos: List<PhotoEntity> = emptyList(),
    @Relation(parentColumn = "id", entityColumn = "personId")
    val voiceNotes: List<VoiceNoteEntity> = emptyList(),
    @Relation(parentColumn = "id", entityColumn = "personId")
    val messages: List<MessageEntity> = emptyList(),
) {
    /** 与 PDF 目录共用同一套排序，保证 App 显示顺序 = PDF 目录顺序 */
    val sortedNodes: List<NodeEntity>
        get() = nodes.filter { it.isVisible }.sortedWith(nodeComparator)

    fun node(id: String?): NodeEntity? = nodes.firstOrNull { it.id == id }

    /** 某章节里的照片（主关系命中，或标签命中），按 sortOrder 排序 */
    fun photosOf(node: NodeEntity): List<PhotoEntity> =
        photos.filter { it.belongsTo(node) }.sortedBy { it.sortOrder }

    fun personVoice(): VoiceNoteEntity? = voiceNotes.firstOrNull { it.scopeRaw == "person" }

    fun nodeVoice(nodeId: String): VoiceNoteEntity? =
        voiceNotes.firstOrNull { it.scopeRaw == "node" && it.targetID == nodeId }

    fun photoVoice(photoId: String): VoiceNoteEntity? =
        voiceNotes.firstOrNull { it.scopeRaw == "photo" && it.targetID == photoId }

    /** 人物封面：自身封面 → 第一张照片 */
    val resolvedCoverFileName: String?
        get() = person.coverImageFileName?.takeIf { it.isNotEmpty() }
            ?: photos.minByOrNull { it.sortOrder }?.imageFileName

    /** 章节封面：自身封面 → 本章节第一张照片 */
    fun resolvedCover(node: NodeEntity): String? =
        node.coverImageFileName?.takeIf { it.isNotEmpty() }
            ?: photosOf(node).minByOrNull { it.sortOrder }?.imageFileName

    fun resolvedPhotoCount(node: NodeEntity): Int = photosOf(node).size
}

/** 章节展示排序：sortOrder → webOrder（0 视为最末）→ 起始年 → 创建时间 */
val nodeComparator: Comparator<NodeEntity> = Comparator { a, b ->
    if (a.sortOrder != b.sortOrder) return@Comparator a.sortOrder - b.sortOrder
    val wa = if (a.webOrder == 0) Int.MAX_VALUE else a.webOrder
    val wb = if (b.webOrder == 0) Int.MAX_VALUE else b.webOrder
    if (wa != wb) return@Comparator wa - wb
    if (a.displayStartYear != b.displayStartYear) return@Comparator a.displayStartYear - b.displayStartYear
    a.createdAt.compareTo(b.createdAt)
}

/** 从年代串取起始年（"1973-1980" / "1973年至今"），取不到给 9999 */
val NodeEntity.displayStartYear: Int
    get() {
        val first = yearRange.split(Regex("[^0-9]+"))
            .firstOrNull { it.isNotEmpty() } ?: return 9999
        return first.take(4).toIntOrNull() ?: 9999
    }

/** 是否属于某个章节：主章节命中，或任一标签命中 */
fun PhotoEntity.belongsTo(node: NodeEntity): Boolean {
    if (nodeId == node.id) return true
    return taggedNodeIds().contains(node.id)
}

fun PhotoEntity.taggedNodeIds(): List<String> =
    tags.split(",").map { it.trim() }.filter { it.isNotEmpty() }

/** 写入多章节标签（仅存 UUID，逗号分隔） */
fun PhotoEntity.withTaggedNodes(nodes: List<NodeEntity>): PhotoEntity =
    copy(tags = nodes.map { it.id }.joinToString(","))
