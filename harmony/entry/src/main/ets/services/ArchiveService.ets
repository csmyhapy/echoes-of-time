import { common } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { zlib } from '@kit.BasicServicesKit';
import { relationalStore } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { Db } from '../data/Db';
import { Repository } from '../data/Repository';
import { MediaStore } from '../data/MediaStore';
import { PersonBundle, Person, Node, Photo, VoiceNote, Message } from '../models/Models';

/**
 * 档案包：.echosarchive.zip
 * 结构：data.json（version/exportedAt/person/nodes/photos/voices/messages）+ media/ 原始文件。
 * 与 iOS ArchiveExporter / ArchiveImporter 保持同名同结构，便于 iOS ⇄ 鸿蒙互导。
 */

interface ArchiveRoot {
  version: number;
  exportedAt: string;
  person: Person;
  nodes: Node[];
  photos: Photo[];
  voices: VoiceNote[];
  messages: Message[];
}

export class ArchiveService {

  private static async writeText(path: string, text: string): Promise<void> {
    const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    try {
      const encoder: util.TextEncoder = new util.TextEncoder();
      const bytes: Uint8Array = encoder.encodeInto(text);
      fs.writeSync(file.fd, bytes.buffer as ArrayBuffer);
    } finally {
      fs.closeSync(file);
    }
  }

  private static readText(path: string): string {
    const content: string = fs.readTextSync(path);
    return content;
  }

  /** 导出某个人物的档案包，返回用户选定的保存路径（取消返回空串） */
  static async exportPerson(context: common.UIAbilityContext, bundle: PersonBundle): Promise<string> {
    const workDir: string = `${context.filesDir}/export_${util.generateRandomUUID()}`;
    const mediaDir: string = `${workDir}/media`;
    fs.mkdirSync(mediaDir, true);

    const root: ArchiveRoot = {
      version: 1,
      exportedAt: new Date().toISOString(),
      person: bundle.person,
      nodes: bundle.nodes,
      photos: bundle.photos,
      voices: bundle.voices,
      messages: bundle.messages
    };
    await ArchiveService.writeText(`${workDir}/data.json`, JSON.stringify(root));

    // 复制本人物名下所有媒体（照片、旁白、BGM）
    const srcDir: string = MediaStore.personDir(context, bundle.person.id);
    const names: string[] = fs.listFileSync(srcDir);
    for (const name of names) {
      fs.copyFileSync(`${srcDir}/${name}`, `${mediaDir}/${name}`);
    }

    const zipPath: string = `${context.filesDir}/${ArchiveService.safeName(bundle.person.name)}.echosarchive.zip`;
    if (fs.accessSync(zipPath)) {
      fs.unlinkSync(zipPath);
    }
    await zlib.compressFile(workDir, zipPath, {});

    // 让用户选保存位置（文件管理 / 云盘）
    const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
    const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
    options.newFileNames = [`${ArchiveService.safeName(bundle.person.name)}.echosarchive.zip`];
    const uris: string[] = await documentPicker.save(options);
    if (uris.length === 0) {
      return '';
    }
    const dest = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
    try {
      fs.copyFileSync(zipPath, dest.fd);
    } finally {
      fs.closeSync(dest);
    }
    ArchiveService.cleanup(workDir);
    return uris[0];
  }

  /**
   * 导入档案包：返回新建人物的 id；用户取消或格式不对返回空串。
   * 同名人物不覆盖，导入为「名字（导入）」副本，避免误删原档。
   */
  static async importArchive(context: common.UIAbilityContext): Promise<string> {
    const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
    const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
    options.maxSelectNumber = 1;
    options.fileSuffixFilters = ['.zip'];
    const uris: string[] = await documentPicker.select(options);
    if (uris.length === 0) {
      return '';
    }

    const tempZip: string = `${context.filesDir}/import_${util.generateRandomUUID()}.zip`;
    const src = fs.openSync(uris[0], fs.OpenMode.READ_ONLY);
    try {
      fs.copyFileSync(src.fd, tempZip);
    } finally {
      fs.closeSync(src);
    }

    const outDir: string = `${context.filesDir}/import_${util.generateRandomUUID()}`;
    await zlib.decompressFile(tempZip, outDir, {});

    const dataPath: string = `${outDir}/data.json`;
    if (!fs.accessSync(dataPath)) {
      ArchiveService.cleanup(outDir);
      return '';
    }
    const root: ArchiveRoot = JSON.parse(ArchiveService.readText(dataPath)) as ArchiveRoot;

    const person: Person = root.person;
    person.id = util.generateRandomUUID();
    person.name = `${person.name}（导入）`;
    person.isDemo = false;

    const store: relationalStore.RdbStore = await Db.get(context);
    await Repository.insertPerson(store, person);

    // 媒体落盘
    const destDir: string = MediaStore.personDir(context, person.id);
    const mediaOut: string = `${outDir}/media`;
    if (fs.accessSync(mediaOut)) {
      const names: string[] = fs.listFileSync(mediaOut);
      for (const name of names) {
        fs.copyFileSync(`${mediaOut}/${name}`, `${destDir}/${name}`);
      }
    }

    for (const node of root.nodes) {
      node.id = util.generateRandomUUID();
      node.personId = person.id;
      await Repository.insertNode(store, node);
    }
    for (const photo of root.photos) {
      photo.personId = person.id;
      await Repository.insertPhoto(store, photo);
    }
    for (const voice of root.voices) {
      voice.personId = person.id;
      await Repository.insertVoice(store, voice);
    }
    for (const message of root.messages) {
      message.personId = person.id;
      await Repository.insertMessage(store, message);
    }

    ArchiveService.cleanup(outDir);
    if (fs.accessSync(tempZip)) {
      fs.unlinkSync(tempZip);
    }
    return person.id;
  }

  private static safeName(name: string): string {
    let result: string = '';
    for (let i = 0; i < name.length; i++) {
      const ch: string = name.charAt(i);
      if (ch === '/' || ch === '\\' || ch === ':' || ch === '*' || ch === '?' ||
        ch === '"' || ch === '<' || ch === '>' || ch === '|') {
        result += '_';
      } else {
        result += ch;
      }
    }
    return result.length > 0 ? result : 'memory';
  }

  private static cleanup(dir: string): void {
    if (!fs.accessSync(dir)) {
      return;
    }
    const names: string[] = fs.listFileSync(dir);
    for (const name of names) {
      const path: string = `${dir}/${name}`;
      if (fs.statSync(path).isDirectory()) {
        ArchiveService.cleanup(path);
      } else {
        fs.unlinkSync(path);
      }
    }
    fs.rmdirSync(dir);
  }
}
