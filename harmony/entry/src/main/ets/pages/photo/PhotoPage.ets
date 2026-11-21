import { common } from '@kit.AbilityKit';
import { router, promptAction } from '@kit.ArkUI';
import { relationalStore } from '@kit.ArkData';
import { Db } from '../../data/Db';
import { Repository } from '../../data/Repository';
import { MediaStore } from '../../data/MediaStore';
import { PersonBundle, Photo, Message, Node, photosOfNode, messagesForPhoto } from '../../models/Models';
import { PhotoParams, readerScale, fmtDate } from '../../utils/Common';
import { MessageSection } from '../../components/MessageSection';
import { AudioService } from '../../services/AudioService';
import { AiHint } from '../../components/AiHint';
import { PreviewMock } from '../../preview/PreviewMock';

@Entry
@Component
struct PhotoPage {
  @StorageProp('mode') mode: string = 'editor';
  @StorageProp('largeText') largeText: boolean = true;

  @State bundle: PersonBundle | undefined = undefined;
  @State photo: Photo | undefined = undefined;
  @State messages: Message[] = [];
  @State loading: boolean = true;
  @State editing: boolean = false;
  @State saving: boolean = false;
  @State zoom: number = 1;
  @State playing: boolean = false;

  @State formCaption: string = '';
  @State formStory: string = '';

  private personId: string = '';
  private nodeId: string = '';
  private photoId: string = '';
  private ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    if (PreviewMock.detect(this.ctx)) {
      this.personId = PreviewMock.PERSON_ID;
      this.nodeId = '';
      this.photoId = '';
    } else {
      const params: PhotoParams = router.getParams() as PhotoParams;
      this.personId = params.personId;
      this.nodeId = params.nodeId;
      this.photoId = params.photoId;
    }
    this.load();
  }

  async load(): Promise<void> {
    this.loading = true;
    try {
      if (PreviewMock.detect(this.ctx)) {
        const previewBundle: PersonBundle = await PreviewMock.bundle(this.ctx);
        this.bundle = previewBundle;
        const firstPhoto: Photo | undefined = previewBundle.photos[0];
        this.photo = firstPhoto;
        if (firstPhoto !== undefined) {
          this.nodeId = firstPhoto.nodeId;
          this.messages = messagesForPhoto(previewBundle, firstPhoto.id);
        }
        return;
      }
      const store: relationalStore.RdbStore = await Db.get(this.ctx);
      const bundle: PersonBundle | undefined = await Repository.getBundle(store, this.personId);
      this.bundle = bundle;
      if (bundle !== undefined) {
        const found: Photo | undefined = bundle.photos.find((p: Photo) => p.id === this.photoId);
        this.photo = found;
        this.messages = messagesForPhoto(bundle, this.photoId);
      }
    } finally {
      this.loading = false;
    }
  }

  private readerFactor(): number {
    return readerScale(this.mode, this.largeText);
  }

  private imageUri(): ResourceStr {
    if (this.photo === undefined) {
      return '';
    }
    if (PreviewMock.detect(this.ctx)) {
      return PreviewMock.photoSource(this.photo.imageFileName);
    }
    return MediaStore.imageUri(this.ctx, this.personId, this.photo.imageFileName);
  }

  private audioUri(): string {
    if (this.photo === undefined || this.photo.audioFileName.length === 0) {
      return '';
    }
    return MediaStore.audioUri(this.ctx, this.personId, this.photo.audioFileName);
  }

  private async playAudio(): Promise<void> {
    if (this.audioUri().length === 0) {
      promptAction.showToast({ message: '这张照片没有旁白' });
      return;
    }
    this.playing = await AudioService.toggle(this.audioUri(), false);
  }

  private photosInNode(): Photo[] {
    if (this.bundle === undefined) {
      return [];
    }
    const node: Node | undefined = this.bundle.nodes.find((n: Node) => n.id === this.nodeId);
    if (node === undefined) {
      return [];
    }
    return photosOfNode(this.bundle, node);
  }

  private async setAsPersonCover(): Promise<void> {
    if (this.photo === undefined) {
      return;
    }
    const store: relationalStore.RdbStore = await Db.get(this.ctx);
    await Repository.setPersonCover(store, this.personId, this.photo.imageFileName);
    promptAction.showToast({ message: '已设为人物封面' });
  }

  private async setAsCover(): Promise<void> {
    if (this.photo === undefined) {
      return;
    }
    const store: relationalStore.RdbStore = await Db.get(this.ctx);
    await Repository.setNodeCover(store, this.nodeId, this.photo.imageFileName);
    promptAction.showToast({ message: '已设为章节封面' });
    router.back();
  }

  private async move(delta: number): Promise<void> {
    if (this.photo === undefined) {
      return;
    }
    const list: Photo[] = this.photosInNode();
    const index: number = list.findIndex((p: Photo) => p.id === this.photoId);
    const target: number = index + delta;
    if (index < 0 || target < 0 || target >= list.length) {
      return;
    }
    const ids: string[] = list.map((p: Photo) => p.id);
    ids[index] = list[target].id;
    ids[target] = list[index].id;
    const store: relationalStore.RdbStore = await Db.get(this.ctx);
    await Repository.reorderPhotos(store, ids);
    await this.load();
    promptAction.showToast({ message: '顺序已调整' });
  }

  private confirmDelete(): void {
    AlertDialog.show({
      title: '删除这张照片？',
      message: '照片和它的旁白会从这台设备上删除，删了不能恢复。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#B5483A',
        action: () => {
          this.deletePhoto();
        }
      }
    });
  }

  private async deletePhoto(): Promise<void> {
    if (this.photo === undefined) {
      return;
    }
    const store: relationalStore.RdbStore = await Db.get(this.ctx);
    MediaStore.deleteFile(this.ctx, this.personId, this.photo.imageFileName);
    if (this.photo.audioFileName.length > 0) {
      MediaStore.deleteFile(this.ctx, this.personId, this.photo.audioFileName);
    }
    await Repository.deletePhoto(store, this.personId, this.photoId);
    promptAction.showToast({ message: '照片已删除' });
    router.back();
  }

  private beginEdit(): void {
    if (this.photo === undefined) {
      return;
    }
    this.formCaption = this.photo.caption;
    this.formStory = this.photo.story;
    this.editing = true;
  }

  async saveEdit(): Promise<void> {
    if (this.photo === undefined) {
      return;
    }
    this.saving = true;
    try {
      const store: relationalStore.RdbStore = await Db.get(this.ctx);
      const photo: Photo = this.photo;
      photo.caption = this.formCaption.trim();
      photo.story = this.formStory.trim();
      await Repository.updatePhoto(store, photo);
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
      } else if (this.photo === undefined) {
        Column() {
          Text('这张照片不见了').fontSize(18).fontColor('#2B2622')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')
      } else {
        Scroll() {
          Column({ space: 16 }) {
            // 大图区：双击复位，双指缩放
            Stack() {
              Image(this.imageUri())
                .width('100%')
                .height(360)
                .objectFit(ImageFit.Contain)
                .scale({ x: this.zoom, y: this.zoom })
            }
            .width('100%')
            .height(360)
            .backgroundColor('#1E1A17')
            .borderRadius(16)
            .clip(true)
            .gesture(
              PinchGesture()
                .onActionUpdate((event: GestureEvent) => {
                  this.zoom = Math.min(3, Math.max(1, event.scale));
                })
                .onActionEnd(() => {
                  if (this.zoom < 1.05) {
                    this.zoom = 1;
                  }
                })
            )
            .onClick(() => {
              this.zoom = 1;
            })

            Column({ space: 6 }) {
              Text(this.photo.caption.length > 0 ? this.photo.caption : '未命名照片')
                .fontSize(22 * this.readerFactor())
                .fontWeight(FontWeight.Medium)
                .fontColor('#2B2622')
                .width('100%')
              Text(this.photo.story)
                .fontSize(15 * this.readerFactor())
                .fontColor('#4A423B')
                .lineHeight(26 * this.readerFactor())
                .width('100%')
              Text(fmtDate(this.photo.createdAt))
                .fontSize(12)
                .fontColor('#A2958A')
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')

            Row({ space: 10 }) {
              Row({ space: 6 }) {
                Text('▶').fontSize(13).fontColor('#FFFFFF')
                Text(this.audioUri().length > 0 ? '听旁白' : '无旁白')
                  .fontSize(14 * this.readerFactor())
                  .fontColor('#FFFFFF')
              }
              .height(42)
              .padding({ left: 16, right: 16 })
              .backgroundColor(this.audioUri().length > 0 ? '#6B4A29' : '#B7A99A')
              .borderRadius(21)
              .onClick(() => {
                this.playAudio();
              })
              Blank()
            }
            .width('100%')

            if (this.mode === 'editor') {
              Flex({ wrap: FlexWrap.Wrap }) {
                Text('编辑说明')
                  .fontSize(13)
                  .fontColor('#6B4A29')
                  .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                  .backgroundColor('#F2E7D8')
                  .borderRadius(14)
                  .margin({ right: 8, bottom: 8 })
                  .onClick(() => {
                    this.beginEdit();
                  })
                Text('设为章节封面')
                  .fontSize(13)
                  .fontColor('#6B4A29')
                  .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                  .backgroundColor('#F2E7D8')
                  .borderRadius(14)
                  .margin({ right: 8, bottom: 8 })
                  .onClick(() => {
                    this.setAsCover();
                  })
                Text('设为人物封面')
                  .fontSize(13)
                  .fontColor('#6B4A29')
                  .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                  .backgroundColor('#F2E7D8')
                  .borderRadius(14)
                  .margin({ right: 8, bottom: 8 })
                  .onClick(() => {
                    this.setAsPersonCover();
                  })
                Text('上移')
                  .fontSize(13)
                  .fontColor('#6B4A29')
                  .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                  .backgroundColor('#F2E7D8')
                  .borderRadius(14)
                  .margin({ right: 8, bottom: 8 })
                  .onClick(() => {
                    this.move(-1);
                  })
                Text('下移')
                  .fontSize(13)
                  .fontColor('#6B4A29')
                  .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                  .backgroundColor('#F2E7D8')
                  .borderRadius(14)
                  .margin({ right: 8, bottom: 8 })
                  .onClick(() => {
                    this.move(1);
                  })
                Text('删除')
                  .fontSize(13)
                  .fontColor('#B5483A')
                  .padding({ left: 8, right: 8, top: 6, bottom: 6 })
                  .onClick(() => {
                    this.confirmDelete();
                  })
              }
              .width('100%')
            }

            MessageSection({
              personId: this.personId,
              nodeId: '',
              photoId: this.photoId,
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
      Text('照片')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#2B2622')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Text('')
        .width(44)
        .height(44)
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 6, bottom: 6 })
  }

  @Builder
  EditPanel() {
    Column({ space: 10 }) {
      Text('照片说明')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor('#2B2622')
        .width('100%')
      TextInput({ text: this.formCaption, placeholder: '给这张照片起个名字' })
        .height(44)
        .onChange((value: string) => {
          this.formCaption = value;
        })
      AiHint({ scene: 'photo', long: false })
      TextArea({ text: this.formStory, placeholder: '这张照片背后的故事' })
        .height(110)
        .onChange((value: string) => {
          this.formStory = value;
        })
      AiHint({ scene: 'photo', long: true })
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
