package life.lifememory.echosoftime.data

import android.content.Context
import kotlinx.coroutines.flow.first
import java.util.UUID

/**
 * 数据仓库：集中处理 Room 写入与媒体文件清理，对应 iOS 的 ModelContext 操作。
 * 所有写操作在协程中执行。
 */
class EchoRepository(
    private val context: Context,
    private val dao: EchoDao,
) {
    fun observePeople() = dao.observePeople()
    fun observePerson(id: String) = dao.observePerson(id)
    suspend fun person(id: String) = dao.personById(id)
    suspend fun node(id: String) = dao.nodeById(id)
    suspend fun nodesOf(personId: String) = dao.nodesOf(personId)

    suspend fun allPeople(): List<PersonEntity> =
        dao.observePeople().first()

    fun newId() = UUID.randomUUID().toString()

    // MARK: Person

    suspend fun createPerson(
        name: String,
        birthYear: String = "",
        summary: String = "",
        story: String = "",
        coverImageFileName: String? = null,
        bgmFileName: String? = null,
        bgmTitle: String? = null,
        isDemo: Boolean = false,
    ): String {
        val entity = PersonEntity(
            id = newId(),
            name = name,
            birthYear = birthYear,
            summary = summary,
            story = story,
            coverImageFileName = coverImageFileName,
            bgmFileName = bgmFileName,
            bgmTitle = bgmTitle,
            isDemo = isDemo,
        )
        dao.insertPerson(entity)
        return entity.id
    }

    suspend fun updatePerson(p: PersonEntity) = dao.updatePerson(p)

    suspend fun deletePerson(id: String) {
        dao.personById(id)?.let { MediaStore.deleteFolder(context, id) }
        dao.personById(id)?.let { dao.deletePerson(it) }
    }

    // MARK: Node

    suspend fun insertNode(
        personId: String,
        name: String,
        yearRange: String = "",
        summary: String = "",
        story: String = "",
        sortOrder: Int = 0,
        webOrder: Int = 0,
        coverImageFileName: String? = null,
        isVisible: Boolean = true,
    ): NodeEntity {
        val node = NodeEntity(
            id = newId(),
            name = name,
            yearRange = yearRange,
            summary = summary,
            story = story,
            coverImageFileName = coverImageFileName,
            sortOrder = sortOrder,
            webOrder = webOrder,
            isVisible = isVisible,
            personId = personId,
        )
        dao.insertNode(node)
        return node
    }

    suspend fun updateNode(n: NodeEntity) = dao.updateNode(n)
    /** 删除章节：先从所属照片的标签/直属归属中摘除，避免悬空引用 */
    suspend fun deleteNode(n: NodeEntity) {
        val photos = dao.photosOf(n.personId)
        for (p in photos) {
            val keptTags = p.taggedNodeIds().filter { it != n.id }
            val newNodeId = if (p.nodeId == n.id) null else p.nodeId
            if (keptTags != p.taggedNodeIds() || newNodeId != p.nodeId) {
                dao.updatePhoto(p.copy(tags = keptTags.joinToString(","), nodeId = newNodeId))
            }
        }
        dao.deleteNode(n)
    }

    /** 拖拽重排：把可见章节按新顺序写回连续 sortOrder */
    suspend fun reorderNodes(ordered: List<NodeEntity>) {
        ordered.forEachIndexed { i, n -> dao.updateNode(n.copy(sortOrder = i)) }
    }

    // MARK: Photo

    suspend fun insertPhoto(
        personId: String,
        nodeId: String?,
        imageFileName: String,
        audioFileName: String? = null,
        caption: String = "",
        story: String = "",
        sortOrder: Int = 0,
        tags: String = "",
        pairWithNext: Boolean = false,
    ): String {
        val photo = PhotoEntity(
            id = newId(),
            imageFileName = imageFileName,
            audioFileName = audioFileName,
            caption = caption,
            story = story,
            tags = tags,
            sortOrder = sortOrder,
            pairWithNext = pairWithNext,
            personId = personId,
            nodeId = nodeId,
        )
        dao.insertPhoto(photo)
        return photo.id
    }

    suspend fun updatePhoto(p: PhotoEntity) = dao.updatePhoto(p)

    suspend fun deletePhoto(p: PhotoEntity) {
        MediaStore.deleteFile(context, p.imageFileName, p.personId)
        p.audioFileName?.let { MediaStore.deleteFile(context, it, p.personId) }
        dao.deletePhoto(p)
    }

    // MARK: VoiceNote

    /** 人物旁白：已有则替换，没有则新建 */
    suspend fun savePersonVoice(personId: String, existing: VoiceNoteEntity?, fileName: String, duration: Int) {
        if (existing != null) {
            MediaStore.deleteFile(context, existing.audioFileName, personId)
            dao.updateVoice(existing.copy(audioFileName = fileName, duration = duration))
        } else {
            dao.insertVoice(
                VoiceNoteEntity(
                    id = newId(),
                    scopeRaw = "person",
                    targetID = null,
                    audioFileName = fileName,
                    duration = duration,
                    personId = personId,
                ),
            )
        }
    }

    suspend fun saveNodeVoice(personId: String, nodeId: String, existing: VoiceNoteEntity?, fileName: String, duration: Int) {
        if (existing != null) {
            MediaStore.deleteFile(context, existing.audioFileName, personId)
            dao.updateVoice(existing.copy(audioFileName = fileName, duration = duration))
        } else {
            dao.insertVoice(
                VoiceNoteEntity(
                    id = newId(),
                    scopeRaw = "node",
                    targetID = nodeId,
                    audioFileName = fileName,
                    duration = duration,
                    personId = personId,
                ),
            )
        }
    }

    suspend fun savePhotoVoice(personId: String, photoId: String, existing: VoiceNoteEntity?, fileName: String, duration: Int) {
        if (existing != null) {
            MediaStore.deleteFile(context, existing.audioFileName, personId)
            dao.updateVoice(existing.copy(audioFileName = fileName, duration = duration))
        } else {
            dao.insertVoice(
                VoiceNoteEntity(
                    id = newId(),
                    scopeRaw = "photo",
                    targetID = photoId,
                    audioFileName = fileName,
                    duration = duration,
                    personId = personId,
                ),
            )
        }
    }

    // MARK: Message

    suspend fun insertMessage(
        personId: String,
        nodeId: String?,
        photoId: String?,
        userName: String,
        content: String,
        role: String = "family",
    ) {
        dao.insertMessage(
            MessageEntity(
                id = newId(),
                userName = userName,
                content = content,
                role = role,
                personId = personId,
                nodeId = nodeId,
                photoId = photoId,
            ),
        )
    }

    suspend fun softDeleteMessage(m: MessageEntity) = dao.updateMessage(m.copy(isDeleted = true))
}
