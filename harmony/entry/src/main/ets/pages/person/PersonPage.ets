import { common } from '@kit.AbilityKit';
import { router, promptAction } from '@kit.ArkUI';
import { relationalStore } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { Db } from '../../data/Db';
import { Repository } from '../../data/Repository';
import { MediaStore } from '../../data/MediaStore';
import {
  Person, PersonBundle, Node, VoiceNote, Message, Photo,
  sortedVisibleNodes, photosOfNode, resolvedPersonCover, resolvedNodeCover,
  personVoice, messagesForPerson
} from '../../models/Models';
import { PersonParams, goNode, readerScale, fmtDate } from '../../utils/Common';
import { Entitlements } from '../../services/Entitlements';
import { AudioService } from '../../services/AudioService';
import { MessageSection } from '../../components/MessageSection';
import { VoiceRecorder } from '../../components/VoiceRecorder';
import { AiHint } from '../../components/AiHint';
import { PDFExporter } from '../../services/PDFExporter';
import { PreviewMock } from '../../preview/PreviewMock';

@Entry
@Component
struct PersonPage {
  @StorageProp('mode') mode: string = 'editor';
  @StorageProp('largeText') largeText: boolean = true;

  @State bundle: PersonBundle | undefined = undefined;
  @State messages: Message[] = [];
  @State loading: boolean = true;
  @State storyOpen: boolean = false;
  @State editing: boolean = false;
  @State saving: boolean = false;
  @State playing: boolean = false;
  @State exporting: boolean = false;

  @State formName: string = '';
  @State formBirth: string = '';
  @State formSummary: string = '';
  @State formStory: string = '';

  // 章节三点菜单 / 重命名 / 删除确认
  @State menuNodeId: string = '';
  @State editNodeId: string = '';
  @State pendingDeleteId: string = '';
  @State enName: string = '';
  @State enYear: string = '';
  @State enSummary: string = '';

  private personId: string = '';
  private ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    if (PreviewMock.detect(this.ctx)) {
      this.personId = PreviewMock.PERSON_ID;
    } else {
      const params: PersonParams = router.getParams() as PersonParams;
      this.personId = params.personId;
    }
    this.load();
  }

  async load(): Promise<void> {
    this.loading = true;
    try {
      if (PreviewMock.detect(this.ctx)) {
        const previewBundle: PersonBundle = await PreviewMock.bundle(this.ctx);
        this.bundle = previewBundle;
        this.messages = messagesForPerson(previewBundle);
        return;
      }
      const store: relationalStore.RdbStore = await Db.get(this.ctx);
      const bundle: PersonBundle | undefined = await Repository.getBundle(store, this.personId);
      this.bundle = bundle;
      this.messages = bundle === undefined ? [] : messagesForPerson(bundle);
    } catch (err) {
      promptAction.showToast({ message: `读取失败：${JSON.stringify(err)}` });
    } finally {
      this.loading = false;
    }
  }

  private readerFactor(): number {
    return readerScale(this.mode, this.largeText);
  }

  private hasPersonVoice(): boolean {
    if (this.bundle === undefined) {
      return false;
    }
    return personVoice(this.bundle) !== undefined;
  }

  /** 创作进度：5 项各占 20%，与 iOS 看板一致 */
  private progressChecks(): boolean[] {
    if (this.bundle === undefined) {
      return [false, false, false, false, false];
    }
    const bundle: PersonBundle = this.bundle;
    return [
      bundle.person.story.trim().length > 0,
      bundle.nodes.length >= 3,
      bundle.photos.length >= 5,
      bundle.voices.length >= 1,
      bundle.messages.length >= 1
    ];
  }

  private progressPercent(): number {
    const checks: boolean[] = this.progressChecks();
    let done: number = 0;
    for (const ok of checks) {
      if (ok) {
        done++;
      }
    }
    return done * 20;
  }

  private charCount(): number {
    if (this.bundle === undefined) {
      return 0;
    }
    let total: number = this.bundle.person.story.length;
    for (const node of this.bundle.nodes) {
      total += node.story.length + node.summary.length;
    }
    for (const photo of this.bundle.photos) {
      total += photo.story.length + photo.caption.length;
    }
    return total;
  }

  private voiceSeconds(): number {
    if (this.bundle === undefined) {
      return 0;
    }
    let total: number = 0;
    for (const voice of this.bundle.voices) {
      total += voice.duration;
    }
    return total;
  }

  private fmtSeconds(seconds: number): string {
    const m: number = Math.floor(seconds / 60);
    const s: number = seconds % 60;
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  }

  private checkLabel(index: number): string {
    const labels: string[] = ['人物故事', '三个章节', '五张照片', '一段旁白', '一条留言'];
    return index >= 0 && index < labels.length ? labels[index] : '';
  }

  private personVoiceId(): string {
    if (this.bundle === undefined) {
      return '';
    }
    const voice: VoiceNote | undefined = personVoice(this.bundle);
    return voice === undefined ? '' : voice.id;
  }

  private nodeList(): Node[] {
    if (this.bundle === undefined) {
      return [];
    }
    const list: Node[] = sortedVisibleNodes(this.bundle);
    return list;
  }

  private hasCover(): boolean {
    return this.bundle !== undefined && resolvedPersonCover(this.bundle).length > 0;
  }

  private hasNodeCover(node: Node): boolean {
    return this.bundle !== undefined && resolvedNodeCover(this.bundle, node).length > 0;
  }

  private coverUri(): ResourceStr {
    if (this.bundle === undefined) {
      return '';
    }
    const file: string = resolvedPersonCover(this.bundle);
    if (PreviewMock.detect(this.ctx)) {
      return PreviewMock.photoSource(file);
    }
    return MediaStore.imageUri(this.ctx, this.personId, file);
  }

  private nodeCoverUri(node: Node): ResourceStr {
    if (this.bundle === undefined) {
      return '';
    }
    const file: string = resolvedNodeCover(this.bundle, node);
    if (PreviewMock.detect(this.ctx)) {
      return PreviewMock.photoSource(file);
    }
    return MediaStore.imageUri(this.ctx, this.personId, file);
  }

  private photoCount(node: Node): number {
    if (this.bundle === undefined) {
      return 0;
    }
    return photosOfNode(this.bundle, node).length;
  }

  private createdAtText(): string {
    if (this.bundle === undefined) {
      return '';
    }
    const created: number = this.bundle.person.createdAt;
    return `档案创建于 ${created > 0 ? fmtDate(created) : '—'}`;
  }

  private async startPersonVoice(): Promise<void> {
    if (this.bundle === undefined) {
      return;
    }
    const voice: VoiceNote | undefined = personVoice(this.bundle);
    if (voice === undefined) {
      promptAction.showToast({ message: '这份档案还没有人生旁白' });
      return;
    }
    const path: string = MediaStore.audioUri(this.ctx, this.personId, voice.audioFileName);
    this.playing = await AudioService.toggle(path, false);
  }

  private async exportPdf(): Promise<void> {
    if (this.bundle === undefined || this.exporting) {
      return;
    }
    if (!Entitlements.canExport()) {
      promptAction.showToast({ message: '导出 PDF 回忆册需要完整版' });
      router.pushUrl({ url: 'pages/paywall/PaywallPage' });
      return;
    }
    this.exporting = true;
    try {
      await AudioService.stop();
      const path: string = await new PDFExporter().build(this.ctx, this.bundle);
      const saved: string = await PDFExporter.saveToUser(this.ctx, path, `${this.bundle.person.name}的回忆册`);
      promptAction.showToast({ message: saved.length > 0 ? '回忆册已保存' : '已取消' });
    } catch (err) {
      promptAction.showToast({ message: '导出失败，请检查存储空间' });
    } finally {
      this.exporting = false;
    }
  }

  private nodeIndexOf(id: string): number {
    const list: Node[] = this.nodeList();
    let index: number = -1;
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === id) {
        index = i;
      }
    }
    return index;
  }

  /** 整组重写连续 sortOrder：App 列表与导出 PDF 目录用同一份顺序 */
  private async persistOrder(list: Node[]): Promise<void> {
    const store: relationalStore.RdbStore = await Db.get(this.ctx);
    for (let i = 0; i < list.length; i++) {
      const n: Node = list[i];
      n.sortOrder = i;
      await Repository.updateNode(store, n);
    }
    await this.load();
  }

  private async moveNode(id: string, delta: number): Promise<void> {
    const list: Node[] = this.nodeList().slice();
    const index: number = this.nodeIndexOf(id);
    const target: number = index + delta;
    if (index < 0 || target < 0 || target >= list.length) {
      return;
    }
    const tmp: Node = list[index];
    list[index] = list[target];
    list[target] = tmp;
    this.menuNodeId = '';
    await this.persistOrder(list);
    promptAction.showToast({ message: delta < 0 ? '已上移，PDF 目录同步更新' : '已下移，PDF 目录同步更新' });
  }

  private openNodeEdit(id: string): void {
    for (const n of this.nodeList()) {
      if (n.id === id) {
        this.enName = n.name;
        this.enYear = n.yearRange;
        this.enSummary = n.summary;
      }
    }
    this.menuNodeId = '';
    this.editNodeId = id;
  }

  private async saveNodeEdit(): Promise<void> {
    const store: relationalStore.RdbStore = await Db.get(this.ctx);
    console.info(`[EchoTest] saveNodeEdit id=${this.editNodeId} name=${this.enName} nodes=${this.nodeList().length}`);
    for (const n of this.nodeList()) {
      if (n.id === this.editNodeId) {
        const name: string = this.enName.trim();
        if (name.length > 0) {
          n.name = name;
        }
        n.yearRange = this.enYear.trim();
        n.summary = this.enSummary.trim();
        console.info(`[EchoTest] updating ${n.id} name=${n.name}`);
        await Repository.updateNode(store, n);
      }
    }
    this.editNodeId = '';
    await this.load();
    promptAction.showToast({ message: '已保存' });
  }

  /** 删除章节：库内级联 + 媒体文件一并清掉，再重排剩余章节 */
  private async confirmDeleteNode(): Promise<void> {
    const id: string = this.pendingDeleteId;
    const nodes: Node[] = this.nodeList();
    let cover: string = '';
    for (const n of nodes) {
      if (n.id === id && n.coverImageFileName.length > 0) {
        cover = n.coverImageFileName;
      }
    }
    const store: relationalStore.RdbStore = await Db.get(this.ctx);
    const photos: Photo[] = await Repository.queryPhotos(store, this.personId);
    const voices: VoiceNote[] = await Repository.queryVoices(store, this.personId);
    for (const p of photos) {
      if (p.nodeId === id) {
        if (p.imageFileName.length > 0) {
          MediaStore.deleteFile(this.ctx, this.personId, p.imageFileName);
        }
        if (p.audioFileName.length > 0) {
          MediaStore.deleteFile(this.ctx, this.personId, p.audioFileName);
        }
      }
    }
    for (const v of voices) {
      if (v.scope === 'node' && v.targetID === id && v.audioFileName.length > 0) {
        MediaStore.deleteFile(this.ctx, this.personId, v.audioFileName);
      }
    }
    if (cover.length > 0) {
      MediaStore.deleteFile(this.ctx, this.personId, cover);
    }
    await Repository.deleteNode(store, this.personId, id);
    this.pendingDeleteId = '';
    const rest: Node[] = [];
    for (const n of nodes) {
      if (n.id !== id) {
        rest.push(n);
      }
    }
    await this.persistOrder(rest);
    promptAction.showToast({ message: '章节已删除' });
  }

  async addChapter(): Promise<void> {
    const nodes: Node[] = this.nodeList();
    const max: number = Entitlements.maxNodes();
    if (nodes.length >= max) {
      promptAction.showToast({ message: Entitlements.limitHint('章节', max) });
      return;
    }
    const store: relationalStore.RdbStore = await Db.get(this.ctx);
    const node: Node = {
      id: util.generateRandomUUID(),
      personId: this.personId,
      name: '新的章节',
      yearRange: '',
      summary: '',
      story: '',
      coverImageFileName: '',
      sortOrder: nodes.length,
      webOrder: 0,
      isVisible: true,
      createdAt: Date.now()
    };
    await Repository.insertNode(store, node);
    await this.load();
    promptAction.showToast({ message: '已新建章节，点进去补上名字和故事' });
  }

  private beginEdit(): void {
    if (this.bundle === undefined) {
      return;
    }
    const p: Person = this.bundle.person;
    this.formName = p.name;
    this.formBirth = p.birthYear;
    this.formSummary = p.summary;
    this.formStory = p.story;
    this.editing = true;
  }

  private confirmDeletePerson(): void {
    AlertDialog.show({
      title: '删除这份档案？',
      message: '人物、章节、照片、旁白和留言会一起从这台设备删除，删了不能恢复。建议先导出档案包备份。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#B5483A',
        action: () => {
          this.deletePerson();
        }
      }
    });
  }

  private async deletePerson(): Promise<void> {
    const store: relationalStore.RdbStore = await Db.get(this.ctx);
    await Repository.deletePerson(store, this.personId);
    MediaStore.deletePersonMedia(this.ctx, this.personId);
    this.editing = false;
    promptAction.showToast({ message: '档案已删除' });
    router.back();
  }

  async saveEdit(): Promise<void> {    if (this.bundle === undefined) {
      return;
    }
    if (this.formName.trim().length === 0) {
      promptAction.showToast({ message: '名字不能为空' });
      return;
    }
    this.saving = true;
    try {
      const store: relationalStore.RdbStore = await Db.get(this.ctx);
      const p: Person = this.bundle.person;
      p.name = this.formName.trim();
      p.birthYear = this.formBirth.trim();
      p.summary = this.formSummary.trim();
      p.story = this.formStory.trim();
      await Repository.updatePerson(store, p);
      this.editing = false;
      await this.load();
      promptAction.showToast({ message: '已保存' });
    } finally {
      this.saving = false;
    }
  }

  build() {
    Column() {
      this.TopBar()

      if (this.loading) {
        Column() {
          LoadingProgress().width(44).height(44).color('#6B4A29')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')
      } else if (this.bundle === undefined) {
        Column() {
          Text('这份档案打不开了').fontSize(18).fontColor('#2B2622')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')
      } else {
        Scroll() {
          Column({ space: 16 }) {
            this.Hero()

            this.Actions()

            if (this.mode === 'editor') {
              Row() {
                VoiceRecorder({
                  personId: this.personId,
                  scope: 'person',
                  targetID: this.personId,
                  hasVoice: this.hasPersonVoice(),
                  voiceId: this.personVoiceId(),
                  existingCount: this.bundle === undefined ? 0 : this.bundle.voices.length,
                  fontSize: 13 * this.readerFactor(),
                  compact: true,
                  onSaved: () => {
                    this.load();
                  }
                })
                Blank()
              }
              .width('100%')
              .padding({ left: 4 })
            }

            this.Stories()

            Row() {
              Text('人生章节')
                .fontSize(20 * this.readerFactor())
                .fontWeight(FontWeight.Medium)
                .fontColor('#2B2622')
              Blank()
              if (this.mode === 'editor') {
                Text('+ 新增章节')
                  .fontSize(14)
                  .fontColor('#6B4A29')
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .borderRadius(14)
                  .backgroundColor('#F2E7D8')
                  .onClick(() => {
                    this.addChapter();
                  })
              }
            }
            .width('100%')
            .padding({ left: 4, right: 4 })

            if (this.mode === 'editor' && this.nodeList().length > 0) {
              Text('点击章节右侧三点可编辑、上移、下移或删除，PDF 目录随之更新')
                .fontSize(12)
                .fontColor('#A2958A')
                .lineHeight(18)
                .width('100%')
                .padding({ left: 4, right: 4 })
            }

            ForEach(this.nodeList(), (node: Node) => {
              this.NodeCard(node)
            }, (node: Node) => node.id)

            if (this.nodeList().length === 0) {
              Text('还没有章节。先加上「童年」「青年」「事业」「家庭」这些阶段，故事就有了骨架。')
                .fontSize(14)
                .fontColor('#8A7E73')
                .lineHeight(22)
                .padding(20)
                .width('100%')
                .backgroundColor('#FBF7F1')
                .borderRadius(14)
            }

            MessageSection({
              personId: this.personId,
              nodeId: '',
              photoId: '',
              messages: this.messages,
              editable: this.mode === 'editor',
              fontSize: 14 * this.readerFactor(),
              onChanged: () => {
                this.load();
              }
            })

            // 进度看板按 iOS 版本要求移到最后
            this.ProgressBoard()

            Text(this.createdAtText())
              .fontSize(12)
              .fontColor('#A2958A')
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 8, bottom: 24 })
          }
          .padding({ left: 20, right: 20, top: 8 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)

        if (this.editing) {
          this.EditPanel()
        }

        if (this.menuNodeId.length > 0) {
          this.NodeMenu()
        }

        if (this.editNodeId.length > 0) {
          this.NodeEditPanel()
        }

        if (this.pendingDeleteId.length > 0) {
          this.ConfirmDeleteNode()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F1E8')
  }

  @Builder
  TopBar() {
    Row() {
      Text('‹')
        .fontSize(30)
        .fontColor('#6B4A29')
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          router.back();
        })
      Text(this.bundle === undefined ? '档案' : this.bundle.person.name)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#2B2622')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      if (this.mode === 'editor' && this.bundle !== undefined) {
        Text('编辑')
          .fontSize(14)
          .fontColor('#6B4A29')
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.beginEdit();
          })
      } else {
        Text('')
          .width(44)
          .height(44)
      }
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 6, bottom: 6 })
  }

  @Builder
  Hero() {
    Column({ space: 10 }) {
      if (this.hasCover()) {
        Image(this.coverUri())
          .width('100%')
          .height(220)
          .borderRadius(18)
          .objectFit(ImageFit.Cover)
          .backgroundColor('#E8DED2')
      } else {
        Column() {
          Text(this.bundle === undefined ? '' : this.bundle.person.name.substring(0, 1))
            .fontSize(56)
            .fontColor('#B9A489')
        }
        .width('100%')
        .height(180)
        .borderRadius(18)
        .backgroundColor('#EFE6D8')
        .justifyContent(FlexAlign.Center)
      }

      Text(this.bundle === undefined ? '' : this.bundle.person.name)
        .fontSize(28 * this.readerFactor())
        .fontWeight(FontWeight.Bold)
        .fontColor('#2B2622')
        .width('100%')
        .margin({ top: 4 })

      Text(this.bundle === undefined ? '' : this.bundle.person.birthYear)
        .fontSize(15 * this.readerFactor())
        .fontColor('#8A6A45')
        .width('100%')

      Text(this.bundle === undefined ? '' : this.bundle.person.summary)
        .fontSize(15 * this.readerFactor())
        .fontColor('#5C534B')
        .lineHeight(24 * this.readerFactor())
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  ProgressBoard() {
    Column({ space: 10 }) {
      Row() {
        Text('创作进度')
          .fontSize(16 * this.readerFactor())
          .fontWeight(FontWeight.Medium)
          .fontColor('#2B2622')
        Blank()
        Text(`${this.progressPercent()}%`)
          .fontSize(16 * this.readerFactor())
          .fontColor('#6B4A29')
      }
      .width('100%')

      Progress({ value: this.progressPercent(), total: 100, type: ProgressType.Linear })
        .color('#6B4A29')
        .backgroundColor('#EDE2D3')
        .height(8)
        .width('100%')

      Row({ space: 18 }) {
        Text(`${this.charCount()} 字`).fontSize(12).fontColor('#8A7E73')
        Text(`${this.fmtSeconds(this.voiceSeconds())} 语音`).fontSize(12).fontColor('#8A7E73')
        Text(`${this.bundle === undefined ? 0 : this.bundle.photos.length} 张照片`).fontSize(12)
          .fontColor('#8A7E73')
        Text(`${this.messages.length} 条留言`).fontSize(12).fontColor('#8A7E73')
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.progressChecks(), (ok: boolean, index: number) => {
          Text(`${this.checkLabel(index)} ${ok ? '✓' : '○'}`)
            .fontSize(11)
            .fontColor(ok ? '#6B4A29' : '#A2958A')
            .backgroundColor(ok ? '#F2E7D8' : '#F6F0E8')
            .borderRadius(10)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .margin({ right: 6, bottom: 6 })
        }, (ok: boolean, index: number) => `${index}`)
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .width('100%')
    .backgroundColor('#FFFDF9')
    .borderRadius(16)
  }

  @Builder
  Actions() {
    Flex({ wrap: FlexWrap.Wrap }) {
      Row({ space: 6 }) {
        Text('▶').fontSize(15).fontColor('#FFFFFF')
        Text('人生旁白').fontSize(15 * this.readerFactor()).fontColor('#FFFFFF')
      }
      .height(44)
      .padding({ left: 18, right: 18 })
      .backgroundColor('#6B4A29')
      .borderRadius(22)
      .margin({ right: 10, bottom: 8 })
      .onClick(() => {
        this.startPersonVoice();
      })

      if (this.mode === 'editor') {
        Row({ space: 6 }) {
          Text('✎').fontSize(15).fontColor('#6B4A29')
          Text('编辑资料').fontSize(15).fontColor('#6B4A29')
        }
        .height(44)
        .padding({ left: 16, right: 16 })
        .backgroundColor('#F2E7D8')
        .borderRadius(22)
        .margin({ right: 10, bottom: 8 })
        .onClick(() => {
          this.beginEdit();
        })

        Row({ space: 6 }) {
          Text('⤓').fontSize(15).fontColor('#6B4A29')
          Text(this.exporting ? '导出中…' : '导出回忆册').fontSize(15).fontColor('#6B4A29')
        }
        .height(44)
        .padding({ left: 14, right: 14 })
        .backgroundColor('#F2E7D8')
        .borderRadius(22)
        .margin({ right: 10, bottom: 8 })
        .onClick(() => {
          this.exportPdf();
        })
      }
    }
    .width('100%')
  }

  @Builder
  Stories() {
    Column({ space: 8 }) {
      Text('人生故事')
        .fontSize(20 * this.readerFactor())
        .fontWeight(FontWeight.Medium)
        .fontColor('#2B2622')
        .width('100%')
      Text(this.bundle === undefined ? '' : this.bundle.person.story)
        .fontSize(15 * this.readerFactor())
        .fontColor('#4A423B')
        .lineHeight(26 * this.readerFactor())
        .maxLines(this.storyOpen ? 999 : 3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Text(this.storyOpen ? '收起' : '展开全文')
        .fontSize(13)
        .fontColor('#8A6A45')
        .onClick(() => {
          this.storyOpen = !this.storyOpen;
        })
    }
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .width('100%')
    .backgroundColor('#FFFDF9')
    .borderRadius(16)
  }

  @Builder
  NodeMenu() {
    Column() {
      Column() {
        Text('章节操作')
          .fontSize(13)
          .fontColor('#8A7E73')
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ bottom: 6 })

        Row() {
          Text('编辑').fontSize(17).fontColor('#2B2622')
        }
        .width('100%')
        .height(50)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.openNodeEdit(this.menuNodeId);
        })

        Divider().color('#EFE6D8')

        Row() {
          Text('上移')
            .fontSize(17)
            .fontColor(this.nodeIndexOf(this.menuNodeId) > 0 ? '#2B2622' : '#C9C0B6')
        }
        .width('100%')
        .height(50)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          if (this.nodeIndexOf(this.menuNodeId) > 0) {
            this.moveNode(this.menuNodeId, -1);
          }
        })

        Divider().color('#EFE6D8')

        Row() {
          Text('下移')
            .fontSize(17)
            .fontColor(this.nodeIndexOf(this.menuNodeId) < this.nodeList().length - 1 ? '#2B2622' : '#C9C0B6')
        }
        .width('100%')
        .height(50)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          if (this.nodeIndexOf(this.menuNodeId) < this.nodeList().length - 1) {
            this.moveNode(this.menuNodeId, 1);
          }
        })

        Divider().color('#EFE6D8')

        Row() {
          Text('删除').fontSize(17).fontColor('#B5483A')
        }
        .width('100%')
        .height(50)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.pendingDeleteId = this.menuNodeId;
          this.menuNodeId = '';
        })

        Divider().color('#EFE6D8')

        Row() {
          Text('取消').fontSize(17).fontColor('#6B4A29')
        }
        .width('100%')
        .height(50)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.menuNodeId = '';
        })
      }
      .width('82%')
      .padding({ top: 14, bottom: 6 })
      .backgroundColor('#FFFDF9')
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#66000000')
  }

  @Builder
  NodeEditPanel() {
    Column() {
      Column({ space: 12 }) {
        Text('编辑章节')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#2B2622')
          .width('100%')

        TextInput({ text: this.enName, placeholder: '章节名称' })
          .height(46)
          .fontSize(16)
          .onChange((value: string) => {
            this.enName = value;
          })

        TextInput({ text: this.enYear, placeholder: '时间范围，如 1936–1949' })
          .height(46)
          .fontSize(16)
          .onChange((value: string) => {
            this.enYear = value;
          })

        TextInput({ text: this.enSummary, placeholder: '一句话简介' })
          .height(46)
          .fontSize(16)
          .onChange((value: string) => {
            this.enSummary = value;
          })

        Row({ space: 12 }) {
          Button('取消')
            .layoutWeight(1)
            .height(44)
            .backgroundColor('#F2E7D8')
            .fontColor('#6B4A29')
            .onClick(() => {
              this.editNodeId = '';
            })
          Button('保存')
            .layoutWeight(1)
            .height(44)
            .backgroundColor('#6B4A29')
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.saveNodeEdit();
            })
        }
        .width('100%')
      }
      .width('86%')
      .padding(20)
      .backgroundColor('#FFFDF9')
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#66000000')
  }

  @Builder
  ConfirmDeleteNode() {
    Column() {
      Column({ space: 14 }) {
        Text('删除这一章？')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#2B2622')
          .width('100%')
        Text('这一章的照片、旁白和留言会一起删除，删掉后不能恢复。')
          .fontSize(14)
          .fontColor('#6F665D')
          .lineHeight(21)
          .width('100%')
        Row({ space: 12 }) {
          Button('取消')
            .layoutWeight(1)
            .height(44)
            .backgroundColor('#F2E7D8')
            .fontColor('#6B4A29')
            .onClick(() => {
              this.pendingDeleteId = '';
            })
          Button('删除')
            .layoutWeight(1)
            .height(44)
            .backgroundColor('#B5483A')
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.confirmDeleteNode();
            })
        }
        .width('100%')
      }
      .width('86%')
      .padding(20)
      .backgroundColor('#FFFDF9')
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#66000000')
  }

  @Builder
  NodeCard(node: Node) {
    Row({ space: 14 }) {
      if (this.hasNodeCover(node)) {
        Image(this.nodeCoverUri(node))
          .width(72)
          .height(72)
          .borderRadius(10)
          .objectFit(ImageFit.Cover)
          .backgroundColor('#E8DED2')
      } else {
        Column()
          .width(72)
          .height(72)
          .borderRadius(10)
          .backgroundColor('#EFE6D8')
      }

      Column({ space: 4 }) {
        Text(node.name)
          .fontSize(19 * this.readerFactor())
          .fontWeight(FontWeight.Medium)
          .fontColor('#2B2622')
        Text(node.yearRange)
          .fontSize(13 * this.readerFactor())
          .fontColor('#8A6A45')
        Text(node.summary)
          .fontSize(13 * this.readerFactor())
          .fontColor('#6F665D')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineHeight(19 * this.readerFactor())
        Text(`${this.photoCount(node)} 张照片`)
          .fontSize(12)
          .fontColor('#A2958A')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 竖排三点：编辑 / 上移 / 下移 / 删除（独立响应，不进章节详情）
      Text('⋮')
        .fontSize(22)
        .fontColor('#A2958A')
        .padding({ left: 12, right: 8, top: 6, bottom: 6 })
        .onClick(() => {
          this.menuNodeId = node.id;
        })
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .shadow({ radius: 8, color: '#10000000', offsetY: 2 })
    .onClick(() => {
      goNode(this.personId, node.id);
    })
  }

  @Builder
  EditPanel() {
    Column({ space: 12 }) {
      Text('编辑人物档案')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#2B2622')
        .width('100%')

      TextInput({ text: this.formName, placeholder: '姓名' })
        .onChange((value: string) => {
          this.formName = value;
        })
        .height(46)
      TextInput({ text: this.formBirth, placeholder: '生卒年，例如 1936–2022' })
        .onChange((value: string) => {
          this.formBirth = value;
        })
        .height(46)
      TextArea({ text: this.formSummary, placeholder: '一句话介绍' })
        .onChange((value: string) => {
          this.formSummary = value;
        })
        .height(72)
        .maxLength(120)
      AiHint({ scene: 'person', long: false })
      TextArea({ text: this.formStory, placeholder: '人生故事（长文）' })
        .onChange((value: string) => {
          this.formStory = value;
        })
        .height(140)
      AiHint({ scene: 'person', long: true })

      Row({ space: 12 }) {
        Button('取消')
          .backgroundColor('#EFE6D8')
          .fontColor('#6B4A29')
          .layoutWeight(1)
          .onClick(() => {
            this.editing = false;
          })
        Button(this.saving ? '保存中…' : '保存')
          .backgroundColor('#6B4A29')
          .fontColor('#FFFFFF')
          .layoutWeight(1)
          .enabled(!this.saving)
          .onClick(() => {
            this.saveEdit();
          })
      }
      .width('100%')

      Text('删除这份档案')
        .fontSize(13)
        .fontColor('#B5483A')
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 6, bottom: 6 })
        .onClick(() => {
          this.confirmDeletePerson();
        })
    }
    .padding(20)
    .width('100%')
    .backgroundColor('#FFFDF9')
    .borderRadius({ topLeft: 20, topRight: 20 })
    .shadow({ radius: 20, color: '#33000000', offsetY: -4 })
    .onClick(() => {
    })
  }
}
