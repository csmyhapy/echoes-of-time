/**
 * 数据模型：与 iOS SwiftData / Android Room 五张表一一对应。
 * 媒体文件只存文件名，真实文件在 filesDir/media/<personId>/ 下。
 * 可选字段统一用空字符串而非 null，读写更简单。
 */

export interface Person {
  id: string;
  name: string;
  birthYear: string;
  summary: string;
  story: string;
  coverImageFileName: string;
  bgmFileName: string;
  bgmTitle: string;
  createdAt: number;
  isDemo: boolean;
}

export interface Node {
  id: string;
  personId: string;
  name: string;
  yearRange: string;
  summary: string;
  story: string;
  coverImageFileName: string;
  sortOrder: number;
  webOrder: number;
  isVisible: boolean;
  createdAt: number;
}

export interface Photo {
  id: string;
  personId: string;
  nodeId: string;
  imageFileName: string;
  audioFileName: string;
  caption: string;
  story: string;
  tags: string;
  sortOrder: number;
  pairWithNext: boolean;
  createdAt: number;
}

export interface VoiceNote {
  id: string;
  personId: string;
  /** person | node | photo */
  scope: string;
  targetID: string;
  audioFileName: string;
  duration: number;
  createdAt: number;
}

export interface Message {
  id: string;
  personId: string;
  nodeId: string;
  photoId: string;
  userName: string;
  content: string;
  /** family | visitor */
  role: string;
  parentID: string;
  isDeleted: boolean;
  createdAt: number;
}

export interface PersonBundle {
  person: Person;
  nodes: Node[];
  photos: Photo[];
  voices: VoiceNote[];
  messages: Message[];
}

// MARK: - 排序与归属规则（App 列表与 PDF 目录必须共用）

/** 从年代串取起始年（"1936–1949" / "1958年至今"），取不到给 9999 */
export function displayStartYear(yearRange: string): number {
  let digits: string = '';
  for (let i = 0; i < yearRange.length; i++) {
    const ch: string = yearRange.charAt(i);
    if (ch >= '0' && ch <= '9') {
      digits += ch;
      if (digits.length === 4) {
        break;
      }
    } else if (digits.length > 0) {
      break;
    }
  }
  if (digits.length === 0) {
    return 9999;
  }
  const parsed: number = Number.parseInt(digits);
  return Number.isNaN(parsed) ? 9999 : parsed;
}

/** sortOrder → webOrder（0 视为最末）→ 起始年 → createdAt */
export function compareNodes(a: Node, b: Node): number {
  if (a.sortOrder !== b.sortOrder) {
    return a.sortOrder - b.sortOrder;
  }
  const wa: number = a.webOrder === 0 ? 2147483647 : a.webOrder;
  const wb: number = b.webOrder === 0 ? 2147483647 : b.webOrder;
  if (wa !== wb) {
    return wa - wb;
  }
  const ya: number = displayStartYear(a.yearRange);
  const yb: number = displayStartYear(b.yearRange);
  if (ya !== yb) {
    return ya - yb;
  }
  return a.createdAt - b.createdAt;
}

export function sortedVisibleNodes(bundle: PersonBundle): Node[] {
  const list: Node[] = bundle.nodes.filter((n: Node) => n.isVisible);
  list.sort(compareNodes);
  return list;
}

export function taggedNodeIds(photo: Photo): string[] {
  const parts: string[] = photo.tags.split(',');
  const result: string[] = [];
  for (let i = 0; i < parts.length; i++) {
    const t: string = parts[i].trim();
    if (t.length > 0) {
      result.push(t);
    }
  }
  return result;
}

/** 主章节命中，或 tags 命中 */
export function photoBelongsTo(photo: Photo, node: Node): boolean {
  if (photo.nodeId === node.id) {
    return true;
  }
  return taggedNodeIds(photo).indexOf(node.id) >= 0;
}

export function photosOfNode(bundle: PersonBundle, node: Node): Photo[] {
  const list: Photo[] = bundle.photos.filter((p: Photo) => photoBelongsTo(p, node));
  list.sort((a: Photo, b: Photo) => a.sortOrder - b.sortOrder);
  return list;
}

/** 人物封面：自身封面 → 第一张照片 */
export function resolvedPersonCover(bundle: PersonBundle): string {
  if (bundle.person.coverImageFileName.length > 0) {
    return bundle.person.coverImageFileName;
  }
  const sorted: Photo[] = bundle.photos.slice().sort((a: Photo, b: Photo) => a.sortOrder - b.sortOrder);
  return sorted.length > 0 ? sorted[0].imageFileName : '';
}

/** 章节封面：自身封面 → 本章节第一张照片 */
export function resolvedNodeCover(bundle: PersonBundle, node: Node): string {
  if (node.coverImageFileName.length > 0) {
    return node.coverImageFileName;
  }
  const photos: Photo[] = photosOfNode(bundle, node);
  return photos.length > 0 ? photos[0].imageFileName : '';
}

export function personVoice(bundle: PersonBundle): VoiceNote | undefined {
  return bundle.voices.find((v: VoiceNote) => v.scope === 'person');
}

export function nodeVoice(bundle: PersonBundle, nodeId: string): VoiceNote | undefined {
  return bundle.voices.find((v: VoiceNote) => v.scope === 'node' && v.targetID === nodeId);
}

export function photoVoice(bundle: PersonBundle, photoId: string): VoiceNote | undefined {
  return bundle.voices.find((v: VoiceNote) => v.scope === 'photo' && v.targetID === photoId);
}

/** 某章节 / 某照片的留言（不含已删除） */
export function messagesForNode(bundle: PersonBundle, nodeId: string): Message[] {
  return bundle.messages.filter((m: Message) => !m.isDeleted && m.nodeId === nodeId && m.photoId.length === 0);
}

export function messagesForPhoto(bundle: PersonBundle, photoId: string): Message[] {
  return bundle.messages.filter((m: Message) => !m.isDeleted && m.photoId === photoId);
}

export function messagesForPerson(bundle: PersonBundle): Message[] {
  return bundle.messages.filter((m: Message) => !m.isDeleted && m.nodeId.length === 0 && m.photoId.length === 0);
}
