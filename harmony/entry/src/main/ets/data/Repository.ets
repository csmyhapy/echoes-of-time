import { relationalStore } from '@kit.ArkData';
import { Person, Node, Photo, VoiceNote, Message, PersonBundle } from '../models/Models';

/**
 * 数据访问层：所有 SQL 只出现在这里，页面不直接碰 RdbStore。
 * 命名与 iOS 的 ModelContext 操作一一对应，便于对照维护。
 */
export class Repository {

  // MARK: - 查询

  static async listPersons(store: relationalStore.RdbStore): Promise<Person[]> {
    const rs: relationalStore.ResultSet = await store.querySql('SELECT * FROM persons ORDER BY createdAt ASC');
    const list: Person[] = [];
    try {
      while (rs.goToNextRow()) {
        list.push(Repository.readPerson(rs));
      }
    } finally {
      rs.close();
    }
    return list;
  }

  static async getPerson(store: relationalStore.RdbStore, id: string): Promise<Person | undefined> {
    const rs: relationalStore.ResultSet =
      await store.querySql('SELECT * FROM persons WHERE id = ? LIMIT 1', [id]);
    try {
      if (rs.goToNextRow()) {
        return Repository.readPerson(rs);
      }
      return undefined;
    } finally {
      rs.close();
    }
  }

  static async getBundle(store: relationalStore.RdbStore, personId: string): Promise<PersonBundle | undefined> {
    const person: Person | undefined = await Repository.getPerson(store, personId);
    if (person === undefined) {
      return undefined;
    }
    const bundle: PersonBundle = {
      person: person,
      nodes: await Repository.queryNodes(store, personId),
      photos: await Repository.queryPhotos(store, personId),
      voices: await Repository.queryVoices(store, personId),
      messages: await Repository.queryMessages(store, personId)
    };
    return bundle;
  }

  static async queryNodes(store: relationalStore.RdbStore, personId: string): Promise<Node[]> {
    const rs: relationalStore.ResultSet =
      await store.querySql('SELECT * FROM nodes WHERE personId = ?', [personId]);
    const list: Node[] = [];
    try {
      while (rs.goToNextRow()) {
        list.push(Repository.readNode(rs));
      }
    } finally {
      rs.close();
    }
    return list;
  }

  static async queryPhotos(store: relationalStore.RdbStore, personId: string): Promise<Photo[]> {
    const rs: relationalStore.ResultSet =
      await store.querySql('SELECT * FROM photos WHERE personId = ?', [personId]);
    const list: Photo[] = [];
    try {
      while (rs.goToNextRow()) {
        list.push(Repository.readPhoto(rs));
      }
    } finally {
      rs.close();
    }
    return list;
  }

  static async queryVoices(store: relationalStore.RdbStore, personId: string): Promise<VoiceNote[]> {
    const rs: relationalStore.ResultSet =
      await store.querySql('SELECT * FROM voice_notes WHERE personId = ?', [personId]);
    const list: VoiceNote[] = [];
    try {
      while (rs.goToNextRow()) {
        list.push(Repository.readVoice(rs));
      }
    } finally {
      rs.close();
    }
    return list;
  }

  static async queryMessages(store: relationalStore.RdbStore, personId: string): Promise<Message[]> {
    const rs: relationalStore.ResultSet =
      await store.querySql('SELECT * FROM messages WHERE personId = ? ORDER BY createdAt ASC', [personId]);
    const list: Message[] = [];
    try {
      while (rs.goToNextRow()) {
        list.push(Repository.readMessage(rs));
      }
    } finally {
      rs.close();
    }
    return list;
  }

  static async hasDemo(store: relationalStore.RdbStore): Promise<boolean> {
    const rs: relationalStore.ResultSet =
      await store.querySql('SELECT COUNT(*) AS c FROM persons WHERE isDemo = 1');
    try {
      if (rs.goToNextRow()) {
        return rs.getLong(rs.getColumnIndex('c')) > 0;
      }
      return false;
    } finally {
      rs.close();
    }
  }

  // MARK: - 写入

  static async insertPerson(store: relationalStore.RdbStore, p: Person): Promise<void> {
    await store.insert('persons', Repository.personValues(p));
  }

  static async insertNode(store: relationalStore.RdbStore, n: Node): Promise<void> {
    await store.insert('nodes', Repository.nodeValues(n));
  }

  static async insertPhoto(store: relationalStore.RdbStore, p: Photo): Promise<void> {
    await store.insert('photos', Repository.photoValues(p));
  }

  static async insertVoice(store: relationalStore.RdbStore, v: VoiceNote): Promise<void> {
    await store.insert('voice_notes', Repository.voiceValues(v));
  }

  static async insertMessage(store: relationalStore.RdbStore, m: Message): Promise<void> {
    await store.insert('messages', Repository.messageValues(m));
  }

  static async updatePerson(store: relationalStore.RdbStore, p: Person): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('persons');
    predicates.equalTo('id', p.id);
    await store.update(Repository.personValues(p), predicates);
  }

  static async updateNode(store: relationalStore.RdbStore, n: Node): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('nodes');
    predicates.equalTo('id', n.id);
    await store.update(Repository.nodeValues(n), predicates);
  }

  static async updatePhoto(store: relationalStore.RdbStore, p: Photo): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('photos');
    predicates.equalTo('id', p.id);
    await store.update(Repository.photoValues(p), predicates);
  }

  /** 删除章节：连同其照片、章节旁白、章节留言一起删（对应 iOS 的 cascade） */
  static async deleteNode(store: relationalStore.RdbStore, personId: string, nodeId: string): Promise<void> {
    await store.executeSql('DELETE FROM messages WHERE personId = ? AND nodeId = ?', [personId, nodeId]);
    await store.executeSql('DELETE FROM voice_notes WHERE personId = ? AND scope = ? AND targetID = ?',
      [personId, 'node', nodeId]);
    await store.executeSql('DELETE FROM photos WHERE personId = ? AND nodeId = ?', [personId, nodeId]);
    await store.executeSql('DELETE FROM nodes WHERE id = ?', [nodeId]);
  }

  /** 删除照片：连带照片留言 */
  static async deletePhoto(store: relationalStore.RdbStore, personId: string, photoId: string): Promise<void> {
    await store.executeSql('DELETE FROM messages WHERE personId = ? AND photoId = ?', [personId, photoId]);
    await store.executeSql('DELETE FROM photos WHERE id = ?', [photoId]);
  }

  /** 拖拽排序后一次性写回 sortOrder */
  static async reorderPhotos(store: relationalStore.RdbStore, orderedIds: string[]): Promise<void> {
    for (let i = 0; i < orderedIds.length; i++) {
      await store.executeSql('UPDATE photos SET sortOrder = ? WHERE id = ?', [i, orderedIds[i]]);
    }
  }

  static async setPersonCover(store: relationalStore.RdbStore, personId: string, fileName: string): Promise<void> {
    await store.executeSql('UPDATE persons SET coverImageFileName = ? WHERE id = ?', [fileName, personId]);
  }

  static async setNodeCover(store: relationalStore.RdbStore, nodeId: string, fileName: string): Promise<void> {
    await store.executeSql('UPDATE nodes SET coverImageFileName = ? WHERE id = ?', [fileName, nodeId]);
  }

  static async deleteMessage(store: relationalStore.RdbStore, messageId: string): Promise<void> {
    await store.executeSql('UPDATE messages SET isDeleted = 1 WHERE id = ?', [messageId]);
  }

  static async updateVoice(store: relationalStore.RdbStore, v: VoiceNote): Promise<void> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('voice_notes');
    predicates.equalTo('id', v.id);
    await store.update(Repository.voiceValues(v), predicates);
  }

  static async deleteVoice(store: relationalStore.RdbStore, voiceId: string): Promise<void> {
    await store.executeSql('DELETE FROM voice_notes WHERE id = ?', [voiceId]);
  }

  static async countPhotos(store: relationalStore.RdbStore, personId: string): Promise<number> {
    return Repository.count(store, 'SELECT COUNT(*) AS c FROM photos WHERE personId = ?', personId);
  }

  static async countVoices(store: relationalStore.RdbStore, personId: string): Promise<number> {
    return Repository.count(store, 'SELECT COUNT(*) AS c FROM voice_notes WHERE personId = ?', personId);
  }

  static async countMessages(store: relationalStore.RdbStore, personId: string): Promise<number> {
    return Repository.count(
      store,
      'SELECT COUNT(*) AS c FROM messages WHERE personId = ? AND isDeleted = 0',
      personId
    );
  }

  private static async count(store: relationalStore.RdbStore, sql: string, arg: string): Promise<number> {
    const rs: relationalStore.ResultSet = await store.querySql(sql, [arg]);
    try {
      if (rs.goToNextRow()) {
        return rs.getLong(rs.getColumnIndex('c'));
      }
      return 0;
    } finally {
      rs.close();
    }
  }

  /** 删除档案：RDB 不自动级联，五张表 + 媒体目录一并清理（媒体目录由调用方删） */
  static async deletePerson(store: relationalStore.RdbStore, personId: string): Promise<void> {
    await store.executeSql('DELETE FROM messages WHERE personId = ?', [personId]);
    await store.executeSql('DELETE FROM voice_notes WHERE personId = ?', [personId]);
    await store.executeSql('DELETE FROM photos WHERE personId = ?', [personId]);
    await store.executeSql('DELETE FROM nodes WHERE personId = ?', [personId]);
    await store.executeSql('DELETE FROM persons WHERE id = ?', [personId]);
  }

  // MARK: - 行映射

  private static readPerson(rs: relationalStore.ResultSet): Person {
    const person: Person = {
      id: rs.getString(rs.getColumnIndex('id')),
      name: rs.getString(rs.getColumnIndex('name')),
      birthYear: rs.getString(rs.getColumnIndex('birthYear')),
      summary: rs.getString(rs.getColumnIndex('summary')),
      story: rs.getString(rs.getColumnIndex('story')),
      coverImageFileName: rs.getString(rs.getColumnIndex('coverImageFileName')),
      bgmFileName: rs.getString(rs.getColumnIndex('bgmFileName')),
      bgmTitle: rs.getString(rs.getColumnIndex('bgmTitle')),
      createdAt: rs.getLong(rs.getColumnIndex('createdAt')),
      isDemo: rs.getLong(rs.getColumnIndex('isDemo')) === 1
    };
    return person;
  }

  private static readNode(rs: relationalStore.ResultSet): Node {
    const node: Node = {
      id: rs.getString(rs.getColumnIndex('id')),
      personId: rs.getString(rs.getColumnIndex('personId')),
      name: rs.getString(rs.getColumnIndex('name')),
      yearRange: rs.getString(rs.getColumnIndex('yearRange')),
      summary: rs.getString(rs.getColumnIndex('summary')),
      story: rs.getString(rs.getColumnIndex('story')),
      coverImageFileName: rs.getString(rs.getColumnIndex('coverImageFileName')),
      sortOrder: rs.getLong(rs.getColumnIndex('sortOrder')),
      webOrder: rs.getLong(rs.getColumnIndex('webOrder')),
      isVisible: rs.getLong(rs.getColumnIndex('isVisible')) === 1,
      createdAt: rs.getLong(rs.getColumnIndex('createdAt'))
    };
    return node;
  }

  private static readPhoto(rs: relationalStore.ResultSet): Photo {
    const photo: Photo = {
      id: rs.getString(rs.getColumnIndex('id')),
      personId: rs.getString(rs.getColumnIndex('personId')),
      nodeId: rs.getString(rs.getColumnIndex('nodeId')),
      imageFileName: rs.getString(rs.getColumnIndex('imageFileName')),
      audioFileName: rs.getString(rs.getColumnIndex('audioFileName')),
      caption: rs.getString(rs.getColumnIndex('caption')),
      story: rs.getString(rs.getColumnIndex('story')),
      tags: rs.getString(rs.getColumnIndex('tags')),
      sortOrder: rs.getLong(rs.getColumnIndex('sortOrder')),
      pairWithNext: rs.getLong(rs.getColumnIndex('pairWithNext')) === 1,
      createdAt: rs.getLong(rs.getColumnIndex('createdAt'))
    };
    return photo;
  }

  private static readVoice(rs: relationalStore.ResultSet): VoiceNote {
    const note: VoiceNote = {
      id: rs.getString(rs.getColumnIndex('id')),
      personId: rs.getString(rs.getColumnIndex('personId')),
      scope: rs.getString(rs.getColumnIndex('scope')),
      targetID: rs.getString(rs.getColumnIndex('targetID')),
      audioFileName: rs.getString(rs.getColumnIndex('audioFileName')),
      duration: rs.getLong(rs.getColumnIndex('duration')),
      createdAt: rs.getLong(rs.getColumnIndex('createdAt'))
    };
    return note;
  }

  private static readMessage(rs: relationalStore.ResultSet): Message {
    const message: Message = {
      id: rs.getString(rs.getColumnIndex('id')),
      personId: rs.getString(rs.getColumnIndex('personId')),
      nodeId: rs.getString(rs.getColumnIndex('nodeId')),
      photoId: rs.getString(rs.getColumnIndex('photoId')),
      userName: rs.getString(rs.getColumnIndex('userName')),
      content: rs.getString(rs.getColumnIndex('content')),
      role: rs.getString(rs.getColumnIndex('role')),
      parentID: rs.getString(rs.getColumnIndex('parentID')),
      isDeleted: rs.getLong(rs.getColumnIndex('isDeleted')) === 1,
      createdAt: rs.getLong(rs.getColumnIndex('createdAt'))
    };
    return message;
  }

  // MARK: - 值对象

  private static personValues(p: Person): relationalStore.ValuesBucket {
    const v: relationalStore.ValuesBucket = {
      id: p.id,
      name: p.name,
      birthYear: p.birthYear,
      summary: p.summary,
      story: p.story,
      coverImageFileName: p.coverImageFileName,
      bgmFileName: p.bgmFileName,
      bgmTitle: p.bgmTitle,
      createdAt: p.createdAt,
      isDemo: p.isDemo ? 1 : 0
    };
    return v;
  }

  private static nodeValues(n: Node): relationalStore.ValuesBucket {
    const v: relationalStore.ValuesBucket = {
      id: n.id,
      personId: n.personId,
      name: n.name,
      yearRange: n.yearRange,
      summary: n.summary,
      story: n.story,
      coverImageFileName: n.coverImageFileName,
      sortOrder: n.sortOrder,
      webOrder: n.webOrder,
      isVisible: n.isVisible ? 1 : 0,
      createdAt: n.createdAt
    };
    return v;
  }

  private static photoValues(p: Photo): relationalStore.ValuesBucket {
    const v: relationalStore.ValuesBucket = {
      id: p.id,
      personId: p.personId,
      nodeId: p.nodeId,
      imageFileName: p.imageFileName,
      audioFileName: p.audioFileName,
      caption: p.caption,
      story: p.story,
      tags: p.tags,
      sortOrder: p.sortOrder,
      pairWithNext: p.pairWithNext ? 1 : 0,
      createdAt: p.createdAt
    };
    return v;
  }

  private static voiceValues(v: VoiceNote): relationalStore.ValuesBucket {
    const values: relationalStore.ValuesBucket = {
      id: v.id,
      personId: v.personId,
      scope: v.scope,
      targetID: v.targetID,
      audioFileName: v.audioFileName,
      duration: v.duration,
      createdAt: v.createdAt
    };
    return values;
  }

  private static messageValues(m: Message): relationalStore.ValuesBucket {
    const v: relationalStore.ValuesBucket = {
      id: m.id,
      personId: m.personId,
      nodeId: m.nodeId,
      photoId: m.photoId,
      userName: m.userName,
      content: m.content,
      role: m.role,
      parentID: m.parentID,
      isDeleted: m.isDeleted ? 1 : 0,
      createdAt: m.createdAt
    };
    return v;
  }
}
