package life.lifememory.echosoftime.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(
    entities = [PersonEntity::class, NodeEntity::class, PhotoEntity::class, VoiceNoteEntity::class, MessageEntity::class],
    version = 1,
    exportSchema = false,
)
abstract class EchoDatabase : RoomDatabase() {
    abstract fun dao(): EchoDao

    companion object {
        @Volatile
        private var instance: EchoDatabase? = null

        fun get(context: Context): EchoDatabase =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    EchoDatabase::class.java,
                    "echoes.db",
                ).build().also { instance = it }
            }
    }
}
