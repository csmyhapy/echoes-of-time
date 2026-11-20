import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

/**
 * 数据库初始化与迁移。
 * 设计要点：
 * 1) securityLevel S3 + encrypt:true —— 照片在沙箱、索引也加密，避免"只锁了一半"。
 * 2) RDB 不会自动级联删除，删除逻辑在 Repository.deletePerson 里显式执行。
 * 3) 版本号用 store.version，从 1 起；后续升级按 2、3…… 追加 ALTER TABLE。
 */

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: 'echosoftime.db',
  securityLevel: relationalStore.SecurityLevel.S3,
  encrypt: true
};

const DDL: string[] = [
  `CREATE TABLE IF NOT EXISTS persons (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    birthYear TEXT DEFAULT '',
    summary TEXT DEFAULT '',
    story TEXT DEFAULT '',
    coverImageFileName TEXT DEFAULT '',
    bgmFileName TEXT DEFAULT '',
    bgmTitle TEXT DEFAULT '',
    createdAt INTEGER NOT NULL,
    isDemo INTEGER DEFAULT 0
  )`,
  `CREATE TABLE IF NOT EXISTS nodes (
    id TEXT PRIMARY KEY,
    personId TEXT NOT NULL,
    name TEXT NOT NULL,
    yearRange TEXT DEFAULT '',
    summary TEXT DEFAULT '',
    story TEXT DEFAULT '',
    coverImageFileName TEXT DEFAULT '',
    sortOrder INTEGER DEFAULT 0,
    webOrder INTEGER DEFAULT 0,
    isVisible INTEGER DEFAULT 1,
    createdAt INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS photos (
    id TEXT PRIMARY KEY,
    personId TEXT NOT NULL,
    nodeId TEXT DEFAULT '',
    imageFileName TEXT NOT NULL,
    audioFileName TEXT DEFAULT '',
    caption TEXT DEFAULT '',
    story TEXT DEFAULT '',
    tags TEXT DEFAULT '',
    sortOrder INTEGER DEFAULT 0,
    pairWithNext INTEGER DEFAULT 0,
    createdAt INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS voice_notes (
    id TEXT PRIMARY KEY,
    personId TEXT NOT NULL,
    scope TEXT NOT NULL,
    targetID TEXT DEFAULT '',
    audioFileName TEXT NOT NULL,
    duration INTEGER DEFAULT 0,
    createdAt INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    personId TEXT NOT NULL,
    nodeId TEXT DEFAULT '',
    photoId TEXT DEFAULT '',
    userName TEXT NOT NULL,
    content TEXT NOT NULL,
    role TEXT DEFAULT 'family',
    parentID TEXT DEFAULT '',
    isDeleted INTEGER DEFAULT 0,
    createdAt INTEGER NOT NULL
  )`,
  `CREATE INDEX IF NOT EXISTS idx_nodes_person ON nodes(personId)`,
  `CREATE INDEX IF NOT EXISTS idx_photos_node ON photos(personId, nodeId)`,
  `CREATE INDEX IF NOT EXISTS idx_voices_target ON voice_notes(personId, scope, targetID)`,
  `CREATE INDEX IF NOT EXISTS idx_msg_target ON messages(personId, nodeId, photoId)`
];

export class Db {
  private static store: relationalStore.RdbStore | undefined = undefined;
  private static opening: Promise<relationalStore.RdbStore> | undefined = undefined;

  static async get(context: common.Context): Promise<relationalStore.RdbStore> {
    if (Db.store !== undefined) {
      return Db.store;
    }
    if (Db.opening !== undefined) {
      return Db.opening;
    }
    const opening: Promise<relationalStore.RdbStore> = Db.open(context);
    Db.opening = opening;
    try {
      Db.store = await opening;
      return Db.store;
    } finally {
      Db.opening = undefined;
    }
  }

  private static async open(context: common.Context): Promise<relationalStore.RdbStore> {
    const store: relationalStore.RdbStore = await relationalStore.getRdbStore(context, STORE_CONFIG);
    await Db.migrate(store);
    return store;
  }

  private static async migrate(store: relationalStore.RdbStore): Promise<void> {
    if (store.version >= 1) {
      return;
    }
    for (let i = 0; i < DDL.length; i++) {
      await store.executeSql(DDL[i]);
    }
    store.version = 1;
  }
}
