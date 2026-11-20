import { common } from '@kit.AbilityKit';
import { pdfService } from '@kit.PDFKit';
import { Font } from '@kit.ArkUI';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { PersonBundle, Node, Photo, photosOfNode, sortedVisibleNodes, resolvedPersonCover } from '../models/Models';
import { MediaStore } from '../data/MediaStore';

/**
 * PDF 回忆册：A4 竖版（595 x 842 pt）。
 * 结构：封面 → 目录（带页码）→ 每章扉页 → 本章故事 → 照片页（图 + 说明 + 故事）。
 * pdfService 只支持按行加文本，所以换行与分页在这里算好再写。
 */

const PAGE_W: number = 595;
const PAGE_H: number = 842;
const MARGIN: number = 48;
const CONTENT_W: number = PAGE_W - MARGIN * 2;
const FOOTER_Y: number = PAGE_H - 40;

class Layout {
  lines: string[] = [];
  pages: number = 0;
}

export class PDFExporter {
  private doc: pdfService.PdfDocument = new pdfService.PdfDocument();
  private fontInfo: pdfService.FontInfo = new pdfService.FontInfo();
  private currentPage: number = -1;
  private pageNo: number = 0;
  private footerText: string = '';

  constructor() {
    const font: Font = new Font();
    const entry = font.getFontByName('HarmonyOS Sans');
    this.fontInfo.fontPath = entry !== undefined ? entry.path : '';
    this.fontInfo.fontName = '';
  }

  /** 估算文本宽度：中日韩字符按字号宽，拉丁按 0.55 倍 */
  private measure(text: string, size: number): number {
    let width: number = 0;
    for (let i = 0; i < text.length; i++) {
      const ch: string = text.charAt(i);
      const code: number = ch.charCodeAt(0);
      if (code > 0x2E80) {
        width += size;
      } else {
        width += size * 0.55;
      }
    }
    return width;
  }

  private wrap(text: string, size: number, maxWidth: number): string[] {
    const result: string[] = [];
    const paragraphs: string[] = text.split('\n');
    for (const paragraph of paragraphs) {
      if (paragraph.length === 0) {
        result.push('');
        continue;
      }
      let line: string = '';
      for (let i = 0; i < paragraph.length; i++) {
        const ch: string = paragraph.charAt(i);
        const next: string = line + ch;
        if (this.measure(next, size) > maxWidth) {
          result.push(line);
          line = ch;
        } else {
          line = next;
        }
      }
      if (line.length > 0) {
        result.push(line);
      }
    }
    return result;
  }

  /** 只算不画：供目录页码使用 */
  private preview(paragraphs: string[]): Layout {
    const layout: Layout = new Layout();
    let pages: number = 1;
    let used: number = 0;
    const maxLines: number = Math.floor((PAGE_H - MARGIN * 2) / 22);
    for (const p of paragraphs) {
      const lines: string[] = this.wrap(p, 11, CONTENT_W);
      for (const line of lines) {
        if (used >= maxLines) {
          pages++;
          used = 0;
        }
        used++;
      }
      // 段落之间的空行
      used++;
      if (used >= maxLines) {
        pages++;
        used = 0;
      }
    }
    layout.pages = pages;
    return layout;
  }

  private newPage(footer: string): pdfService.PdfPage {
    this.pageNo++;
    if (this.currentPage < 0) {
      this.doc.createDocument(PAGE_W, PAGE_H);
      this.currentPage = 0;
    } else {
      this.doc.insertBlankPage(this.pageNo - 1, PAGE_W, PAGE_H);
      this.currentPage = this.pageNo - 1;
    }
    const page: pdfService.PdfPage = this.doc.getPage(this.currentPage);
    this.footerText = footer;
    if (footer.length > 0) {
      this.drawText(page, `${this.pageNo}`, 9, PAGE_W / 2 - 4, FOOTER_Y, 0x9A8F84);
    }
    return page;
  }

  private drawText(page: pdfService.PdfPage, text: string, size: number, x: number, y: number,
    color: number): void {
    if (text.length === 0) {
      return;
    }
    const style: pdfService.TextStyle = { textColor: color, textSize: size, fontInfo: this.fontInfo };
    page.addTextObject(text, x, y, style);
  }

  /** 把一段文字写进页面，返回新的 y；页底不够时自动翻页 */
  private drawParagraph(page: pdfService.PdfPage, text: string, size: number, y: number,
    color: number, footer: string): pdfService.PdfPage {
    let current: pdfService.PdfPage = page;
    let cursor: number = y;
    const lineHeight: number = size * 1.9;
    const lines: string[] = this.wrap(text, size, CONTENT_W);
    for (const line of lines) {
      if (cursor > PAGE_H - MARGIN - 24) {
        current = this.newPage(footer);
        cursor = MARGIN;
      }
      this.drawText(current, line, size, MARGIN, cursor, color);
      cursor += lineHeight;
    }
    return current;
  }

  private drawImage(page: pdfService.PdfPage, path: string, x: number, y: number, w: number, h: number): void {
    try {
      if (path.length === 0 || !fs.accessSync(path)) {
        return;
      }
      page.addImageObject(path, x, y, w, h);
    } catch (err) {
      // 单张图片失败不能让整本失败，继续排版
    }
  }

  /** 生成某人物整本回忆册，返回沙箱内 pdf 路径 */
  async build(context: common.UIAbilityContext, bundle: PersonBundle): Promise<string> {
    const person = bundle.person;
    const nodes: Node[] = sortedVisibleNodes(bundle);
    const footer: string = `${person.name} · 岁月回声`;

    // 目录页码先算：封面 1 + 目录（按条目估 1 页，超过 14 章再加）
    const tocPages: number = Math.max(1, Math.ceil(nodes.length / 14) + 1);
    let cursorPage: number = 2 + tocPages;
    const nodeStartPage: Map<string, number> = new Map<string, number>();
    for (const node of nodes) {
      nodeStartPage.set(node.id, cursorPage);
      const paragraphs: string[] = PDFExporter.nodeParagraphs(node);
      cursorPage += 1 + this.preview(paragraphs).pages;
      const photos: Photo[] = photosOfNode(bundle, node);
      cursorPage += Math.max(1, Math.ceil(photos.length / 2));
    }

    // 封面
    const cover: pdfService.PdfPage = this.newPage('');
    this.drawText(cover, '岁月回声', 13, MARGIN, 60, 0x8A6A45);
    const coverImage: string = MediaStore.filePath(context, person.id, resolvedPersonCover(bundle));
    if (coverImage.length > 0 && fs.accessSync(coverImage)) {
      this.drawImage(cover, coverImage, MARGIN, 110, CONTENT_W, 380);
    }
    this.drawText(cover, person.name, 34, MARGIN, 540, 0x2B2622);
    this.drawText(cover, person.birthYear, 15, MARGIN, 580, 0x8A6A45);
    this.drawParagraph(cover, person.summary, 11, 615, 0x6F665D, footer);

    // 目录
    let toc: pdfService.PdfPage = this.newPage(footer);
    this.drawText(toc, '目录', 24, MARGIN, 90, 0x2B2622);
    let ty: number = 140;
    for (let i = 0; i < nodes.length; i++) {
      if (ty > PAGE_H - MARGIN - 30) {
        toc = this.newPage(footer);
        ty = MARGIN + 20;
      }
      const node: Node = nodes[i];
      this.drawText(toc, `${i + 1}. ${node.name}`, 13, MARGIN, ty, 0x2B2622);
      this.drawText(toc, node.yearRange, 10, MARGIN + 150, ty, 0x9A8F84);
      const start: number | undefined = nodeStartPage.get(node.id);
      this.drawText(toc, `${start === undefined ? '' : start}`, 11, PAGE_W - MARGIN - 20, ty, 0x6B4A29);
      ty += 30;
    }

    // 章节
    for (const node of nodes) {
      const photos: Photo[] = photosOfNode(bundle, node);
      // 扉页
      let page: pdfService.PdfPage = this.newPage(footer);
      const nodeCover: string = node.coverImageFileName.length > 0
        ? MediaStore.filePath(context, person.id, node.coverImageFileName)
        : (photos.length > 0 ? MediaStore.filePath(context, person.id, photos[0].imageFileName) : '');
      this.drawImage(page, nodeCover, MARGIN, 120, CONTENT_W, 300);
      this.drawText(page, node.name, 28, MARGIN, 460, 0x2B2622);
      this.drawText(page, node.yearRange, 13, MARGIN, 500, 0x8A6A45);
      page = this.drawParagraph(page, node.summary, 11, 530, 0x6F665D, footer);

      // 本章故事
      page = this.newPage(footer);
      this.drawText(page, '本章故事', 17, MARGIN, 90, 0x2B2622);
      page = this.drawParagraph(page, node.story, 11, 120, 0x4A423B, footer);

      // 照片页：两列，图下说明；有故事的照片独占一页
      let index: number = 0;
      while (index < photos.length) {
        const photo: Photo = photos[index];
        const path: string = MediaStore.filePath(context, person.id, photo.imageFileName);
        if (photo.story.length > 0) {
          page = this.newPage(footer);
          this.drawImage(page, path, MARGIN, 90, CONTENT_W, 340);
          this.drawText(page, photo.caption, 14, MARGIN, 450, 0x2B2622);
          page = this.drawParagraph(page, photo.story, 11, 478, 0x4A423B, footer);
          index++;
          continue;
        }
        page = this.newPage(footer);
        const halfW: number = (CONTENT_W - 16) / 2;
        this.drawImage(page, path, MARGIN, 90, halfW, 220);
        this.drawText(page, photo.caption, 10, MARGIN, 322, 0x6F665D);
        const second: Photo | undefined = index + 1 < photos.length ? photos[index + 1] : undefined;
        if (second !== undefined && second.story.length === 0) {
          this.drawImage(page, MediaStore.filePath(context, person.id, second.imageFileName),
            MARGIN + halfW + 16, 90, halfW, 220);
          this.drawText(page, second.caption, 10, MARGIN + halfW + 16, 322, 0x6F665D);
          index += 2;
        } else {
          index += 1;
        }
      }
    }

    const pdfPath: string = `${context.filesDir}/memory_${util.generateRandomUUID()}.pdf`;
    const ok: boolean = this.doc.saveDocument(pdfPath);
    this.doc.releaseDocument();
    if (!ok) {
      throw new Error('save pdf failed');
    }
    return pdfPath;
  }

  static nodeParagraphs(node: Node): string[] {
    const result: string[] = [];
    if (node.summary.length > 0) {
      result.push(node.summary);
    }
    if (node.story.length > 0) {
      result.push(node.story);
    }
    return result;
  }

  /** 导出后让用户选保存位置；返回保存的 uri，取消返回空串 */
  static async saveToUser(context: common.UIAbilityContext, pdfPath: string, name: string): Promise<string> {
    const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
    const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
    options.newFileNames = [`${name}.pdf`];
    const uris: string[] = await documentPicker.save(options);
    if (uris.length === 0) {
      return '';
    }
    const src = fs.openSync(pdfPath, fs.OpenMode.READ_ONLY);
    const dest = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
    try {
      fs.copyFileSync(src.fd, dest.fd);
    } finally {
      fs.closeSync(src);
      fs.closeSync(dest);
    }
    if (fs.accessSync(pdfPath)) {
      fs.unlinkSync(pdfPath);
    }
    return uris[0];
  }
}
