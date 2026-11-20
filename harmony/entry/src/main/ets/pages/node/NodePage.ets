import { common } from '@kit.AbilityKit';
import { router, promptAction } from '@kit.ArkUI';
import { relationalStore } from '@kit.ArkData';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { util } from '@kit.ArkTS';
import { Db } from '../../data/Db';
import { Repository } from '../../data/Repository';
import { MediaStore } from '../../data/MediaStore';
import {
  PersonBundle, Node, Photo, VoiceNote, Message,
  photosOfNode, resolvedNodeCover, nodeVoice, messagesForNode
} from '../../models/Models';
import { NodeParams, goPhoto, readerScale } from '../../utils/Common';
import { Entitlements } from '../../services/Entitlements';
import { AudioService } from '../../services/AudioService';
import { MessageSection } from '../../components/MessageSection';
import { VoiceRecorder } from '../../components/VoiceRecorder';
import { PreviewMock } from '../../preview/PreviewMock';

@Entry
@Component
struct NodePage {
  @StorageProp('mode') mode: string = 'editor';
  @StorageProp('largeText') largeText: boolean = true;

  @State bundle: PersonBundle | undefined = undefined;
  @State node: Node | undefined = undefined;
  @State photos: Photo[] = [];
  @State messages: Message[] = [];
  @State loading: boolean = true;
  @State storyOpen: boolean = false;
  @State editing: boolean = false;
  @State saving: boolean = false;
  @State playing: boolean = false;
  @State importing: boolean = false;

  @State formName: string = '';
  @State formYears: string = '';
  @State formSummary: string = '';
  @State formStory: string = '';

  private personId: string = '';
  private nodeId: string = '';
  private ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    if (PreviewMock.detect(this.ctx)) {
      this.personId = PreviewMock.PERSON_ID;
      this.nodeId = '';
    } else {
      const params: NodeParams = router.getParams() as NodeParams;
      this.personId = params.personId;
      this.nodeId = params.nodeId;
    }
    this.load();
  }

  async load(): Promise<void> {
    this.loading = true;
    try {
      if (PreviewMock.detect(this.ctx)) {
        const previewBundle: PersonBundle = await PreviewMock.bundle(this.ctx);
        this.bundle = previewBundle;
        const firstNode: Node | undefined = previewBundle.nodes[0];
        this.node = firstNode;
        this.photos = firstNode === undefined ? [] : photosOfNode(previewBundle, firstNode);
        this.messages = firstNode === undefined ? [] : messagesForNode(previewBundle, firstNode.id);
        return;
      }
      const store: relationalStore.RdbStore = await Db.get(this.ctx);
      const bundle: PersonBundle | undefined = await Repository.getBundle(store, this.personId);
      this.bundle = bundle;
      if (bundle !== undefined) {
        const found: Node | undefined = bundle.nodes.find((n: Node) => n.id === this.nodeId);
        this.node = found;
        this.photos = found === undefined ? [] : photosOfNode(bundle, found);
        this.messages = messagesForNode(bundle, this.nodeId);
      }
    } catch (err) {
      promptAction.showToast({ message: `读取失败：${JSON.stringify(err)}` });
    } finally {
      this.loading = false;
    }
  }

  private readerFactor(): number {
    return readerScale(this.mode, this.largeText);
  }

  private hasCover(): boolean {
    return this.bundle !== undefined && this.node !== undefined &&
      resolvedNodeCover(this.bundle, this.node).length > 0;
  }

  private coverUri(): ResourceStr {
    if (this.bundle === undefined || this.node === undefined) {
      return '';
    }
    const file: string = resolvedNodeCover(this.bundle, this.node);
    if (PreviewMock.detect(this.ctx)) {
      return PreviewMock.photoSource(file);
    }
    return MediaStore.imageUri(this.ctx, this.personId, file);
  }

  private photoUri(photo: Photo): ResourceStr {
    if (PreviewMock.detect(this.ctx)) {
      return PreviewMock.photoSource(photo.imageFileName);
    }
    return MediaStore.imageUri(this.ctx, this.personId, photo.imageFileName);
  }

  private nodeVoiceNote(): VoiceNote | undefined {
    if (this.bundle === undefined || this.node === undefined) {
      return undefined;
    }
    return nodeVoice(this.bundle, this.node.id);
  }

  private nodeVoiceId(): string {
    const voice: VoiceNote | undefined = this.nodeVoiceNote();
    return voice === undefined ? '' : voice.id;
  }

  private async playNodeVoice(): Promise<void> {
    const voice: VoiceNote | undefined = this.nodeVoiceNote();
    if (voice === undefined) {
      promptAction.showToast({ message: '这一章还没有旁白' });
      return;
    }
    const path: string = MediaStore.audioUri(this.ctx, this.personId, voice.audioFileName);
    this.playing = await AudioService.toggle(path, false);
  }

  private async addPhotos(): Promise<void> {
    if (!Entitlements.isPaid()) {
      promptAction.showToast({ message: Entitlements.limitHint('照片', 0) });
      return;
    }
    const max: number = Entitlements.maxPhotos();
    if (this.bundle === undefined) {
      return;
    }
    const total: number = this.bundle.photos.length;
    if (total >= max) {
      promptAction.showToast({ message: Entitlements.limitHint('照片', max) });
      return;
    }

    const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = Math.min(9, max - total);
    const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
    this.importing = true;
    try {
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(options);
      const store: relationalStore.RdbStore = await Db.get(this.ctx);
      let order: number = this.photos.length;
      for (let i = 0; i < result.photoUris.length; i++) {
        const fileName: string = await MediaStore.importUserPhoto(this.ctx, this.personId, result.photoUris[i]);
        const photo: Photo = {
          id: util.generateRandomUUID(),
          personId: this.personId,
          nodeId: this.nodeId,
          imageFileName: fileName,
          audioFileName: '',
          caption: '',
          story: '',
          tags: '',
          sortOrder: order,
          pairWithNext: false,
          createdAt: Date.now() + i
        };
        await Repository.insertPhoto(store, photo);
        order++;
      }
      await this.load();
      promptAction.showToast({ message: `已加入 ${result.photoUris.length} 张照片` });
    } catch (err) {
      promptAction.showToast({ message: `导入失败：${JSON.stringify(err)}` });
    } finally {
      this.importing = false;
    }
  }

  private beginEdit(): void {
    if (this.node === undefined) {
      return;
    }
    this.formName = this.node.name;
    this.formYears = this.node.yearRange;
    this.formSummary = this.node.summary;
    this.formStory = this.node.story;
    this.editing = true;
  }

  async saveEdit(): Promise<void> {
    if (this.node === undefined) {
      return;
    }
    if (this.formName.trim().length === 0) {
      promptAction.showToast({ message: '章节名不能为空' });
      return;
    }
    this.saving = true;
    try {
      const store: relationalStore.RdbStore = await Db.get(this.ctx);
      const node: Node = this.node;
      node.name = this.formName.trim();
      node.yearRange = this.formYears.trim();
      node.summary = this.formSummary.trim();
      node.story = this.formStory.trim();
      await Repository.updateNode(store, node);
      this.editing = false;
      await this.load();
      promptAction.showToast({ message: '已保存' });
    } finally {
      this.saving = false;
    }
  }

  private confirmDelete(): void {
    if (this.node === undefined) {
      return;
    }
    AlertDialog.show({
      title: '删除这一章？',
      message: '章节里的照片、旁白和留言会一起删除，删了不能恢复。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#B5483A',
        action: () => {
          this.deleteNode();
        }
      }
    });
  }

  private async deleteNode(): Promise<void> {
    if (this.node === undefined) {
      return;
    }
    const store: relationalStore.RdbStore = await Db.get(this.ctx);
    for (let i = 0; i < this.photos.length; i++) {
      MediaStore.deleteFile(this.ctx, this.personId, this.photos[i].imageFileName);
      if (this.photos[i].audioFileName.length > 0) {
        MediaStore.deleteFile(this.ctx, this.personId, this.photos[i].audioFileName);
      }
    }
    // 章节旁白文件一并删
    if (this.bundle !== undefined) {
      this.bundle.voices
        .filter((v: VoiceNote) => v.scope === 'node' && v.targetID === this.nodeId)
        .forEach((v: VoiceNote) => {
          MediaStore.deleteFile(this.ctx, this.personId, v.audioFileName);
        });
    }
    await Repository.deleteNode(store, this.personId, this.nodeId);
    promptAction.showToast({ message: '章节已删除' });
    router.back();
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
      } else if (this.node === undefined) {
        Column() {
          Text('这一章不见了').fontSize(18).fontColor('#2B2622')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')
      } else {
        Scroll() {
          Column({ space: 14 }) {
            this.Header()

            this.StoryCard()

            if (this.mode === 'editor') {
              Row() {
                VoiceRecorder({
                  personId: this.personId,
                  scope: 'node',
                  targetID: this.nodeId,
                  hasVoice: this.nodeVoiceNote() !== undefined,
                  voiceId: this.nodeVoiceId(),
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
            }

            Row() {
              Text(`照片 · ${this.photos.length}`)
                .fontSize(19 * this.readerFactor())
                .fontWeight(FontWeight.Medium)
                .fontColor('#2B2622')
              Blank()
              if (this.mode === 'editor') {
                Text(this.importing ? '导入中…' : '+ 加照片')
                  .fontSize(14)
                  .fontColor('#6B4A29')
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .borderRadius(14)
                  .backgroundColor('#F2E7D8')
                  .onClick(() => {
                    if (!this.importing) {
                      this.addPhotos();
                    }
                  })
              }
            }
            .width('100%')

            if (this.photos.length === 0) {
              Text('这一章还没有照片。照片不用多，一张能讲出故事的就好。')
                .fontSize(14)
                .fontColor('#8A7E73')
                .lineHeight(22)
                .padding(18)
                .width('100%')
                .backgroundColor('#FBF7F1')
                .borderRadius(14)
            } else {
              Grid() {
                ForEach(this.photos, (photo: Photo, index: number) => {
                  GridItem() {
                    this.PhotoCell(photo, index)
                  }
                }, (photo: Photo) => photo.id)
              }
              .columnsTemplate('1fr 1fr')
              .columnsGap(10)
              .rowsGap(14)
              .width('100%')
            }

            MessageSection({
              personId: this.personId,
              nodeId: this.nodeId,
              photoId: '',
              messages: this.messages,
              editable: this.mode === 'editor',
              fontSize: 14 * this.readerFactor(),
              onChanged: () => {
                this.load();
              }
            })

            Blank().height(24)
          }
          .padding({ left: 20, right: 20, top: 6 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)

        if (this.editing) {
          this.EditPanel()
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
      Text(this.node === undefined ? '章节' : this.node.name)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#2B2622')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      if (this.mode === 'editor') {
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
  Header() {
    Column({ space: 8 }) {
      if (this.hasCover()) {
        Image(this.coverUri())
          .width('100%')
          .height(190)
          .borderRadius(16)
          .objectFit(ImageFit.Cover)
          .backgroundColor('#E8DED2')
      }
      Text(this.node === undefined ? '' : this.node.name)
        .fontSize(26 * this.readerFactor())
        .fontWeight(FontWeight.Bold)
        .fontColor('#2B2622')
        .width('100%')
      Text(this.node === undefined ? '' : this.node.yearRange)
        .fontSize(14 * this.readerFactor())
        .fontColor('#8A6A45')
        .width('100%')
      Text(this.node === undefined ? '' : this.node.summary)
        .fontSize(14 * this.readerFactor())
        .fontColor('#6F665D')
        .lineHeight(22 * this.readerFactor())
        .width('100%')

      Row({ space: 10 }) {
        Row({ space: 6 }) {
          Text('▶').fontSize(13).fontColor('#FFFFFF')
          Text(this.nodeVoiceNote() === undefined ? '暂无旁白' : '章节旁白')
            .fontSize(14 * this.readerFactor())
            .fontColor('#FFFFFF')
        }
        .height(40)
        .padding({ left: 16, right: 16 })
        .backgroundColor('#6B4A29')
        .borderRadius(20)
        .onClick(() => {
          this.playNodeVoice();
        })
        Blank()
      }
      .width('100%')
      .margin({ top: 4 })
    }
    .width('100%')
  }

  @Builder
  StoryCard() {
    Column({ space: 6 }) {
      Text(this.node === undefined ? '' : this.node.story)
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
  PhotoCell(photo: Photo, index: number) {
    Column({ space: 6 }) {
      Image(this.photoUri(photo))
        .width('100%')
        .aspectRatio(1)
        .borderRadius(10)
        .objectFit(ImageFit.Cover)
        .backgroundColor('#E8DED2')
        .onClick(() => {
          goPhoto(this.personId, this.nodeId, photo.id);
        })

      Text(photo.caption.length > 0 ? photo.caption : `第 ${index + 1} 张`)
        .fontSize(12 * this.readerFactor())
        .fontColor('#6F665D')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      if (photo.audioFileName.length > 0) {
        Text('◉ 有旁白')
          .fontSize(11)
          .fontColor('#8A6A45')
          .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  EditPanel() {
    Column({ space: 10 }) {
      Row() {
        Text('编辑章节')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#2B2622')
        Blank()
        Text('删除章节')
          .fontSize(13)
          .fontColor('#B5483A')
          .onClick(() => {
            this.confirmDelete();
          })
      }
      .width('100%')

      TextInput({ text: this.formName, placeholder: '章节名，例如「童年时光」' })
        .onChange((value: string) => {
          this.formName = value;
        })
        .height(44)
      TextInput({ text: this.formYears, placeholder: '年代，例如 1936–1949' })
        .onChange((value: string) => {
          this.formYears = value;
        })
        .height(44)
      TextArea({ text: this.formSummary, placeholder: '一句话概括这一章' })
        .onChange((value: string) => {
          this.formSummary = value;
        })
        .height(64)
      TextArea({ text: this.formStory, placeholder: '这一章的故事' })
        .onChange((value: string) => {
          this.formStory = value;
        })
        .height(120)

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
    }
    .padding(20)
    .width('100%')
    .backgroundColor('#FFFDF9')
    .borderRadius({ topLeft: 20, topRight: 20 })
    .shadow({ radius: 20, color: '#33000000', offsetY: -4 })
  }
}
