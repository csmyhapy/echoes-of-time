package life.lifememory.echosoftime.data

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface EchoDao {

    // MARK: Person

    @Query("SELECT * FROM persons ORDER BY createdAt DESC")
    fun observePeople(): Flow<List<PersonEntity>>

    @Transaction
    @Query("SELECT * FROM persons WHERE id = :id")
    fun observePerson(id: String): Flow<PersonBundle?>

    @Query("SELECT * FROM persons WHERE isDemo = 1")
    suspend fun demoPeople(): List<PersonEntity>

    @Query("SELECT * FROM persons WHERE id = :id")
    suspend fun personById(id: String): PersonEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPerson(p: PersonEntity)

    @Update
    suspend fun updatePerson(p: PersonEntity)

    @Delete
    suspend fun deletePerson(p: PersonEntity)

    // MARK: Node

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertNode(n: NodeEntity)

    @Update
    suspend fun updateNode(n: NodeEntity)

    @Delete
    suspend fun deleteNode(n: NodeEntity)

    @Query("SELECT * FROM nodes WHERE personId = :personId")
    suspend fun nodesOf(personId: String): List<NodeEntity>

    @Query("SELECT * FROM nodes WHERE id = :id")
    suspend fun nodeById(id: String): NodeEntity?

    // MARK: Photo

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPhoto(p: PhotoEntity)

    @Update
    suspend fun updatePhoto(p: PhotoEntity)

    @Delete
    suspend fun deletePhoto(p: PhotoEntity)

    @Query("SELECT * FROM photos WHERE personId = :personId")
    suspend fun photosOf(personId: String): List<PhotoEntity>

    @Query("SELECT * FROM photos WHERE personId = :personId ORDER BY sortOrder ASC")
    fun observePhotos(personId: String): Flow<List<PhotoEntity>>

    // MARK: VoiceNote

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertVoice(v: VoiceNoteEntity)

    @Update
    suspend fun updateVoice(v: VoiceNoteEntity)

    @Delete
    suspend fun deleteVoice(v: VoiceNoteEntity)

    // MARK: Message

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertMessage(m: MessageEntity)

    @Update
    suspend fun updateMessage(m: MessageEntity)

    @Delete
    suspend fun deleteMessage(m: MessageEntity)

    @Query("SELECT * FROM messages WHERE personId = :personId AND isDeleted = 0")
    suspend fun activeMessages(personId: String): List<MessageEntity>
}
