package life.lifememory.echosoftime.data

import android.content.Context
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File
import java.io.FileOutputStream
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

/**
 * 档案包：data.json + media/ 打成 .echosarchive.zip（与 iOS 格式互通）。
 * 既是备份/恢复格式，也是「从网站迁移」的导入格式。
 */

@Serializable
data class PersonArchiveDTO(
    val app: String,
    val version: Int,
    val exportedAt: String,
    val name: String,
    val birthYear: String,
    val summary: String,
    val story: String,
    val coverImageFileName: String? = null,
    val nodes: List<NodeArchiveDTO>,
    val voiceNotes: List<VoiceArchiveDTO>,
    val messages: List<MessageArchiveDTO>,
    val unassignedPhotos: List<PhotoArchiveDTO>? = null,
)

@Serializable
data class NodeArchiveDTO(
    val webID: Int? = null,
    val name: String,
    val yearRange: String,
    val summary: String,
    val story: String,
    val coverImageFileName: String? = null,
    val sortOrder: Int,
    val isVisible: Boolean,
    val photos: List<PhotoArchiveDTO>,
)

@Serializable
data class PhotoArchiveDTO(
    val imageFileName: String,
    val audioFileName: String? = null,
    val caption: String,
    val story: String,
    val tags: String,
    val sortOrder: Int,
    val pairWithNext: Boolean? = null,
    val webNodeIDs: List<Int>? = null,
)

@Serializable
data class VoiceArchiveDTO(
    val scope: String,
    val targetID: String? = null,
    val audioFileName: String,
    val duration: Int,
)

@Serializable
data class MessageArchiveDTO(
    val userName: String,
    val content: String,
    val role: String,
    val createdAt: Long,
    val nodeName: String? = null,
    val photoCaption: String? = null,
    val isPersonLevel: Boolean,
)

object ArchiveIO {

    private val json = Json { prettyPrint = true; ignoreUnknownKeys = true }

    fun safeFileName(name: String): String =
        name.replace(Regex("[^\\p{L}\\p{N}_-]+"), "_").trim('_').ifEmpty { "archive" }

    // MARK: - 导出

    /** 把指定人物打成档案包，返回临时文件（失败返回 null） */
    fun makeArchive(context: Context, bundle: PersonBundle): File? {
        val person = bundle.person
        val nodes = bundle.sortedNodes
        val voices = bundle.voiceNotes.sortedBy { it.createdAt }
        val messages = bundle.messages.filter { !it.isDeleted }.sortedBy { it.createdAt }

        val dto = PersonArchiveDTO(
            app = "EchoesOfTime",
            version = 1,
            exportedAt = java.time.Instant.now().toString(),
            name = person.name,
            birthYear = person.birthYear,
            summary = person.summary,
            story = person.story,
            coverImageFileName = person.coverImageFileName,
            nodes = nodes.map { node ->
                NodeArchiveDTO(
                    webID = if (node.webOrder > 0) node.webOrder else null,
                    name = node.name,
                    yearRange = node.yearRange,
                    summary = node.summary,
                    story = node.story,
                    coverImageFileName = node.coverImageFileName,
                    sortOrder = node.sortOrder,
                    isVisible = node.isVisible,
                    photos = bundle.photosOf(node).map { p ->
                        PhotoArchiveDTO(
                            imageFileName = p.imageFileName,
                            audioFileName = p.audioFileName,
                            caption = p.caption,
                            story = p.story,
                            tags = p.tags,
                            sortOrder = p.sortOrder,
                            pairWithNext = p.pairWithNext,
                        )
                    },
                )
            },
            voiceNotes = voices.map { v ->
                VoiceArchiveDTO(v.scopeRaw, v.targetID, v.audioFileName, v.duration)
            },
            messages = messages.map { m ->
                MessageArchiveDTO(
                    userName = m.userName,
                    content = m.content,
                    role = m.role,
                    createdAt = m.createdAt,
                    nodeName = m.nodeId?.let { nid -> bundle.node(nid)?.name },
                    photoCaption = m.photoId?.let { pid ->
                        bundle.photos.firstOrNull { it.id == pid }?.caption
                    },
                    isPersonLevel = m.nodeId == null && m.photoId == null,
                )
            },
        )

        val outDir = File(context.cacheDir, "exports").apply { mkdirs() }
        val out = File(outDir, "${safeFileName(person.name)}.echosarchive.zip")
        return try {
            ZipOutputStream(FileOutputStream(out)).use { zos ->
                zos.putNextEntry(ZipEntryCompat("data.json"))
                json.encodeToString(PersonArchiveDTO.serializer(), dto).byteInputStream().copyTo(zos)
                zos.closeEntry()

                val folder = MediaStore.folder(context, person.id)
                folder.listFiles()?.forEach { file ->
                    if (file.isFile) {
                        zos.putNextEntry(ZipEntryCompat("media/${file.name}"))
                        file.inputStream().copyTo(zos)
                        zos.closeEntry()
                    }
                }
            }
            out
        } catch (_: Exception) {
            null
        }
    }

    // MARK: - 导入

    data class Outcome(
        val personName: String,
        val nodeCount: Int,
        val photoCount: Int,
        val skippedPhotos: Int,
    )

    @Throws(Exception::class)
    suspend fun importArchive(context: Context, repo: EchoRepository, zipFile: File): Outcome {
        val raw = zipFile.inputStream().use { input -> ZipInputStream(input.buffered()) }
        var jsonData: ByteArray? = null
        val media = mutableMapOf<String, ByteArray>()

        raw.use { zis ->
            while (true) {
                val entry = zis.nextEntry ?: break
                val bytes = zis.readBytes()
                when {
                    entry.name == "data.json" -> jsonData = bytes
                    entry.name.startsWith("media/") -> {
                        val name = entry.name.removePrefix("media/")
                        if (name.isNotEmpty() && '/' !in name) media[name] = bytes
                    }
                }
                zis.closeEntry()
            }
        }

        val data = jsonData ?: throw IllegalStateException("missing data.json")
        val dto = json.decodeFromString(PersonArchiveDTO.serializer(), data.decodeToString())

        val personId = repo.createPerson(
            name = dto.name.ifEmpty { "Untitled" }.let { ArchiveText.inline(it) },
            birthYear = ArchiveText.inline(dto.birthYear),
            summary = ArchiveText.inline(dto.summary),
            story = ArchiveText.clean(dto.story),
        )

        // 媒体落盘
        val folder = MediaStore.folder(context, personId)
        val written = mutableSetOf<String>()
        for ((name, bytes) in media) {
            val dest = File(folder, name)
            FileOutputStream(dest).use { it.write(bytes) }
            written += name
        }

        dto.coverImageFileName?.takeIf { it in written }?.let { cover ->
            repo.person(personId)?.let { repo.updatePerson(it.copy(coverImageFileName = cover)) }
        }

        var photoTotal = 0
        var skipped = 0
        val photoByCaption = mutableMapOf<String, PhotoEntity>()
        val nodeByName = mutableMapOf<String, NodeEntity>()

        for (nodeDTO in dto.nodes) {
            val node = repo.insertNode(
                personId = personId,
                name = ArchiveText.inline(nodeDTO.name),
                yearRange = ArchiveText.inline(nodeDTO.yearRange),
                summary = ArchiveText.inline(nodeDTO.summary),
                story = ArchiveText.clean(nodeDTO.story),
                sortOrder = nodeDTO.sortOrder,
                webOrder = nodeDTO.webID ?: 0,
                coverImageFileName = nodeDTO.coverImageFileName?.takeIf { it in written },
                isVisible = nodeDTO.isVisible,
            )
            nodeByName[nodeDTO.name] = node
        }

        suspend fun makePhoto(photoDTO: PhotoArchiveDTO, primaryNode: NodeEntity?): Boolean {
            if (photoDTO.imageFileName !in written) return false
            val audio = photoDTO.audioFileName?.takeIf { it in written }
            val id = repo.insertPhoto(
                personId = personId,
                nodeId = primaryNode?.id,
                imageFileName = photoDTO.imageFileName,
                audioFileName = audio,
                caption = ArchiveText.inline(photoDTO.caption),
                story = ArchiveText.clean(photoDTO.story),
                sortOrder = photoDTO.sortOrder,
                tags = primaryNode?.id ?: "",
                pairWithNext = photoDTO.pairWithNext ?: false,
            )
            val photo = PhotoEntity(
                id = id, imageFileName = photoDTO.imageFileName, audioFileName = audio,
                caption = photoDTO.caption, story = photoDTO.story, tags = primaryNode?.id ?: "",
                sortOrder = photoDTO.sortOrder, pairWithNext = photoDTO.pairWithNext ?: false,
                personId = personId, nodeId = primaryNode?.id,
            )
            if (photoDTO.caption.isNotEmpty() && photoByCaption[photoDTO.caption] == null) {
                photoByCaption[photoDTO.caption] = photo
            }
            return true
        }

        for (nodeDTO in dto.nodes) {
            val node = nodeByName[nodeDTO.name] ?: continue
            for (photoDTO in nodeDTO.photos.sortedBy { it.sortOrder }) {
                if (makePhoto(photoDTO, node)) photoTotal++ else skipped++
            }
        }
        for (photoDTO in dto.unassignedPhotos ?: emptyList()) {
            if (makePhoto(photoDTO, null)) photoTotal++ else skipped++
        }

        // 语音
        for (voiceDTO in dto.voiceNotes) {
            if (voiceDTO.audioFileName in written) {
                when (voiceDTO.scope) {
                    "person" -> repo.savePersonVoice(personId, null, voiceDTO.audioFileName, voiceDTO.duration)
                    "node" -> voiceDTO.targetID?.let { tid ->
                        repo.saveNodeVoice(personId, tid, null, voiceDTO.audioFileName, voiceDTO.duration)
                    }
                    "photo" -> voiceDTO.targetID?.let { tid ->
                        repo.savePhotoVoice(personId, tid, null, voiceDTO.audioFileName, voiceDTO.duration)
                    }
                }
            }
        }

        // 留言
        for (messageDTO in dto.messages) {
            if (messageDTO.content.isEmpty()) continue
            val node = messageDTO.nodeName?.let { nodeByName[it] }
            val photo = messageDTO.photoCaption?.let { photoByCaption[it] }
            repo.insertMessage(
                personId = personId,
                nodeId = node?.id,
                photoId = photo?.id,
                userName = ArchiveText.inline(messageDTO.userName),
                content = ArchiveText.clean(messageDTO.content),
                role = messageDTO.role,
            )
        }

        return Outcome(dto.name, dto.nodes.size, photoTotal, skipped)
    }
}

private fun ByteArray.byteInputStream(): java.io.InputStream = java.io.ByteArrayInputStream(this)

private class ZipEntryCompat(name: String) : java.util.zip.ZipEntry(name)
