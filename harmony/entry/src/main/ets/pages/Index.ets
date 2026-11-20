import { common } from '@kit.AbilityKit';
import { router, promptAction } from '@kit.ArkUI';
import { relationalStore } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { Db } from '../data/Db';
import { Repository } from '../data/Repository';
import { DemoSeeder } from '../data/DemoSeeder';
import { MediaStore } from '../data/MediaStore';
import { Person } from '../models/Models';
import { goPerson } from '../utils/Common';
import { Entitlements } from '../services/Entitlements';
import { IapService } from '../services/IapService';
import { PreviewMock } from '../preview/PreviewMock';

/**
 * 档案库首页：列表 → 人物详情；右上角进设置。
 * 首次启动灌入中文 demo；有设备锁时先解锁再进。
 */
@Entry
@Component
struct Index {
  @StorageProp('mode') mode: string = 'editor';
  @StorageProp('lockEnabled') lockEnabled: boolean = false;
  @StorageProp('pin') pin: string = '';
  @StorageProp('fgTick') @Watch('onForegroundChanged') fgTick: number = 0;

  @State persons: Person[] = [];
  @State loading: boolean = true;
  @State errorText: string = '';
  @State locked: boolean = false;
  @State pinInput: string = '';
  @State pinError: string = '';
  @State newPanel: boolean = false;
  @State formName: string = '';
  @State formBirth: string = '';
  @State formSummary: string = '';

  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    this.locked = this.lockEnabled && this.pin.length > 0;
    this.load();
  }

  onForegroundChanged(): void {
    this.load();
  }

  async load(): Promise<void> {
    this.loading = true;
    try {
      // 预览器里 relationalStore 是 mock 实现，查不到数据；用内存 demo 档案顶上
      if (PreviewMock.detect(this.context)) {
        const previewBundle = await PreviewMock.bundle(this.context);
        this.persons = [previewBundle.person];
        this.errorText = '';
        return;
      }
      const store: relationalStore.RdbStore = await Db.get(this.context);
      await DemoSeeder.seedIfNeeded(this.context, store);
      this.persons = await Repository.listPersons(store);
      this.errorText = '';
      // 首启/回前台静默恢复购买权益（不弹窗）
      if (!Entitlements.isPaid()) {
        IapService.restore(this.context);
      }
    } catch (err) {
      this.errorText = '打不开记忆簿，请重新打开一次试试。';
    } finally {
      this.loading = false;
    }
  }

  private unlock(): void {
    if (this.pinInput === this.pin) {
      this.locked = false;
      this.pinInput = '';
      this.pinError = '';
    } else {
      this.pinError = '密码不对，再试一次';
      this.pinInput = '';
    }
  }

  private startNewPerson(): void {
    this.formName = '';
    this.formBirth = '';
    this.formSummary = '';
    this.newPanel = true;
  }

  private async createPerson(): Promise<void> {
    const name: string = this.formName.trim();
    if (name.length === 0) {
      promptAction.showToast({ message: '先填个名字' });
      return;
    }
    try {
      const store: relationalStore.RdbStore = await Db.get(this.context);
      const person: Person = {
        id: util.generateRandomUUID(),
        name: name,
        birthYear: this.formBirth.trim(),
        summary: this.formSummary.trim(),
        story: '',
        coverImageFileName: '',
        bgmFileName: '',
        bgmTitle: '',
        createdAt: Date.now(),
        isDemo: false
      };
      await Repository.insertPerson(store, person);
      this.newPanel = false;
      await this.load();
      promptAction.showToast({ message: '建好了，点进去补上故事' });
    } catch (err) {
      promptAction.showToast({ message: '建档失败，请重试' });
    }
  }

  private hasCover(person: Person): boolean {
    return person.coverImageFileName.length > 0;
  }

  private coverOf(person: Person): ResourceStr {
    if (person.coverImageFileName.length === 0) {
      return '';
    }
    if (PreviewMock.detect(this.context)) {
      return PreviewMock.photoSource(person.coverImageFileName);
    }
    return MediaStore.imageUri(this.context, person.id, person.coverImageFileName);
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Column({ space: 6 }) {
            Text('岁月回声')
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor('#2B2622')
            Text('把家人的照片、故事和声音，留成一本可以一直翻的书')
              .fontSize(14)
              .fontColor('#7A6E63')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Text('⚙')
            .fontSize(20)
            .fontColor('#6B4A29')
            .width(44)
            .height(44)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              router.pushUrl({ url: 'pages/settings/SettingsPage' });
            })
        }
        .width('100%')
        .padding({ left: 24, right: 12, top: 24, bottom: 16 })

        if (this.loading) {
          Column() {
            LoadingProgress().width(48).height(48).color('#6B4A29')
            Text('正在打开记忆簿…').fontSize(14).fontColor('#7A6E63').margin({ top: 12 })
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.errorText.length > 0) {
          Column({ space: 10 }) {
            Text('打不开记忆簿').fontSize(20).fontWeight(FontWeight.Medium).fontColor('#2B2622')
            Text(this.errorText).fontSize(13).fontColor('#9A4A3A').textAlign(TextAlign.Center)
          }
          .layoutWeight(1)
          .width('100%')
          .padding(24)
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 14 }) {
            ForEach(this.persons, (person: Person) => {
              ListItem() {
                this.PersonCard(person)
              }
            }, (person: Person) => person.id)

            if (this.mode === 'editor') {
              ListItem() {
                this.NewPersonEntry()
              }
            }
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 20, right: 20 })
          .scrollBar(BarState.Off)

          Text('数据只保存在这台设备 · 不联网 · 不上传')
            .fontSize(12)
            .fontColor('#A2958A')
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 18 })
        }

        if (this.newPanel) {
          this.NewPersonPanel()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F7F1E8')

      if (this.locked) {
        this.LockLayer()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  LockLayer() {
    Column({ space: 14 }) {
      Text('🔒').fontSize(34)
      Text('岁月回声').fontSize(22).fontWeight(FontWeight.Medium).fontColor('#2B2622')
      Text('输入设备密码继续').fontSize(13).fontColor('#8A7E73')
      TextInput({ text: this.pinInput, placeholder: '设备密码' })
        .type(InputType.Password)
        .maxLength(6)
        .height(48)
        .width('76%')
        .onChange((value: string) => {
          this.pinInput = value;
        })
      if (this.pinError.length > 0) {
        Text(this.pinError).fontSize(12).fontColor('#B5483A')
      }
      Button('打开')
        .width('76%')
        .height(46)
        .backgroundColor('#6B4A29')
        .fontColor('#FFFFFF')
        .onClick(() => {
          this.unlock();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F7F1E8')
  }

  @Builder
  PersonCard(person: Person) {
    Row({ space: 16 }) {
      if (this.hasCover(person)) {
        Image(this.coverOf(person))
          .width(88)
          .height(88)
          .borderRadius(10)
          .objectFit(ImageFit.Cover)
          .backgroundColor('#E8DED2')
      } else {
        Text(person.name.substring(0, 1))
          .width(88)
          .height(88)
          .borderRadius(10)
          .backgroundColor('#E8DED2')
          .fontSize(28)
          .fontColor('#6B4A29')
          .textAlign(TextAlign.Center)
      }

      Column({ space: 6 }) {
        Row({ space: 8 }) {
          Text(person.name)
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .fontColor('#2B2622')
          if (person.isDemo) {
            Text('示例')
              .fontSize(11)
              .fontColor('#8A6A45')
              .backgroundColor('#F2E7D8')
              .borderRadius(6)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          }
        }

        Text(person.birthYear)
          .fontSize(14)
          .fontColor('#8A6A45')

        Text(person.summary)
          .fontSize(13)
          .fontColor('#6F665D')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineHeight(19)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .padding(16)
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(18)
    .shadow({ radius: 10, color: '#12000000', offsetY: 3 })
    .onClick(() => {
      goPerson(person.id);
    })
  }

  @Builder
  NewPersonEntry() {
    Row({ space: 10 }) {
      Text('+')
        .fontSize(22)
        .fontColor('#6B4A29')
      Text('为一位家人建档案')
        .fontSize(16)
        .fontColor('#6B4A29')
    }
    .width('100%')
    .height(64)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#FBF7F1')
    .border({ width: 1, color: '#E0D3C3', style: BorderStyle.Dashed })
    .borderRadius(16)
    .onClick(() => {
      this.startNewPerson();
    })
  }

  @Builder
  NewPersonPanel() {
    Column({ space: 10 }) {
      Text('为一位家人建档案')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#2B2622')
        .width('100%')
      TextInput({ text: this.formName, placeholder: '姓名，比如「王秀兰」' })
        .height(44)
        .onChange((value: string) => {
          this.formName = value;
        })
      TextInput({ text: this.formBirth, placeholder: '生卒年，比如「1936–2022」' })
        .height(44)
        .onChange((value: string) => {
          this.formBirth = value;
        })
      TextArea({ text: this.formSummary, placeholder: '一句话介绍（可留空）' })
        .height(80)
        .onChange((value: string) => {
          this.formSummary = value;
        })
      Row({ space: 12 }) {
        Button('取消')
          .backgroundColor('#EFE6D8')
          .fontColor('#6B4A29')
          .layoutWeight(1)
          .onClick(() => {
            this.newPanel = false;
          })
        Button('建档案')
          .backgroundColor('#6B4A29')
          .fontColor('#FFFFFF')
          .layoutWeight(1)
          .onClick(() => {
            this.createPerson();
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
