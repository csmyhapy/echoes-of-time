import { common } from '@kit.AbilityKit';
import { router, promptAction } from '@kit.ArkUI';
import { relationalStore } from '@kit.ArkData';
import { Db } from '../../data/Db';
import { Repository } from '../../data/Repository';
import { MediaStore } from '../../data/MediaStore';
import { PersonBundle } from '../../models/Models';
import { AppStore } from '../../services/AppStore';
import { Bgm } from '../../services/Bgm';
import { ArchiveService } from '../../services/ArchiveService';
import { IapService } from '../../services/IapService';
import { AudioService } from '../../services/AudioService';
import { PreviewMock } from '../../preview/PreviewMock';

const PRIVACY_URL: string = 'https://csmyhapy.github.io/echoes-of-time/privacy.html';

interface SettingsParams {
  personId?: string;
}

@Entry
@Component
struct SettingsPage {
  @StorageProp('mode') mode: string = 'editor';
  @StorageProp('largeText') largeText: boolean = true;
  @StorageProp('lockEnabled') lockEnabled: boolean = false;
  @StorageProp('pin') pin: string = '';
  @StorageProp('tier') tier: string = 'none';
  @StorageProp('basicOwned') basicOwned: boolean = false;
  @StorageProp('upgradeOwned') upgradeOwned: boolean = false;
  @StorageProp('fullOwned') fullOwned: boolean = false;

  @State bgmOn: boolean = false;
  @State pinPanel: boolean = false;
  @State pinDraft: string = '';
  @State pinAgain: string = '';
  @State working: boolean = false;

  private personId: string = '';
  private ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    if (PreviewMock.detect(this.ctx)) {
      this.personId = PreviewMock.PERSON_ID;
      return;
    }
    const params: SettingsParams = router.getParams() as SettingsParams;
    if (params !== undefined && params.personId !== undefined) {
      this.personId = params.personId;
    }
  }

  private tierText(): string {
    if (this.tier === 'full') {
      return '完整版（已解锁全部功能）';
    }
    if (this.tier === 'basic') {
      return '入门版（可补差价升级）';
    }
    return '免费体验';
  }

  private async toggleBgm(enabled: boolean): Promise<void> {
    if (!enabled) {
      await Bgm.stop(this.ctx);
      this.bgmOn = false;
      return;
    }
    const bundle: PersonBundle | undefined = await this.loadBundle();
    if (bundle === undefined || bundle.person.bgmFileName.length === 0) {
      promptAction.showToast({ message: '这份档案还没有背景音乐' });
      this.bgmOn = false;
      return;
    }
    const path: string = MediaStore.audioUri(this.ctx, bundle.person.id, bundle.person.bgmFileName);
    await Bgm.start(this.ctx, path);
    this.bgmOn = true;
  }

  private async loadBundle(): Promise<PersonBundle | undefined> {
    if (PreviewMock.detect(this.ctx)) {
      return await PreviewMock.bundle(this.ctx);
    }
    const store: relationalStore.RdbStore = await Db.get(this.ctx);
    if (this.personId.length > 0) {
      return await Repository.getBundle(store, this.personId);
    }
    const persons = await Repository.listPersons(store);
    if (persons.length === 0) {
      return undefined;
    }
    this.personId = persons[0].id;
    return await Repository.getBundle(store, persons[0].id);
  }

  private async setLock(enabled: boolean): Promise<void> {
    if (enabled) {
      this.pinDraft = '';
      this.pinAgain = '';
      this.pinPanel = true;
      return;
    }
    await AppStore.setLock(false, '');
    promptAction.showToast({ message: '已关闭设备锁' });
  }

  private async confirmPin(): Promise<void> {
    if (this.pinDraft.length < 4) {
      promptAction.showToast({ message: '密码至少 4 位数字' });
      return;
    }
    if (this.pinDraft !== this.pinAgain) {
      promptAction.showToast({ message: '两次输入不一致' });
      return;
    }
    await AppStore.setLock(true, this.pinDraft);
    this.pinPanel = false;
    promptAction.showToast({ message: '设备锁已开启，下次打开需要输入密码' });
  }

  private async exportArchive(): Promise<void> {
    if (this.working) {
      return;
    }
    const bundle: PersonBundle | undefined = await this.loadBundle();
    if (bundle === undefined) {
      promptAction.showToast({ message: '还没有档案可导出' });
      return;
    }
    this.working = true;
    try {
      await AudioService.stop();
      const saved: string = await ArchiveService.exportPerson(this.ctx, bundle);
      promptAction.showToast({ message: saved.length > 0 ? '档案包已保存' : '已取消' });
    } catch (err) {
      promptAction.showToast({ message: '导出失败，请检查存储空间' });
    } finally {
      this.working = false;
    }
  }

  private async importArchive(): Promise<void> {
    if (this.working) {
      return;
    }
    this.working = true;
    try {
      const id: string = await ArchiveService.importArchive(this.ctx);
      if (id.length > 0) {
        promptAction.showToast({ message: '档案已导入' });
      }
    } catch (err) {
      promptAction.showToast({ message: '导入失败，请确认文件是 .echosarchive.zip' });
    } finally {
      this.working = false;
    }
  }

  private async openPrivacy(): Promise<void> {
    try {
      await this.ctx.startAbility({
        bundleName: 'com.huawei.hmos.browser',
        abilityName: 'MainAbility',
        uri: PRIVACY_URL
      });
    } catch (err) {
      promptAction.showToast({ message: `隐私政策：${PRIVACY_URL}` });
    }
  }

  private async restorePurchase(): Promise<void> {
    this.working = true;
    try {
      const ok: boolean = await IapService.restore(this.ctx);
      promptAction.showToast({ message: ok ? '已恢复购买' : '没有查询到已购记录' });
    } finally {
      this.working = false;
    }
  }

  build() {
    Column() {
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
        Text('设置')
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

      Scroll() {
        Column({ space: 14 }) {
          // 显示
          this.SectionTitle('显示')
          Column({ space: 12 }) {
            Row() {
              Column({ space: 3 }) {
                Text('建档模式').fontSize(15).fontColor('#2B2622')
                Text('适合子女整理资料，正常字号、可编辑').fontSize(12).fontColor('#8A7E73')
              }
              .alignItems(HorizontalAlign.Start)
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.mode === 'editor' })
                .selectedColor('#6B4A29')
                .onChange((isOn: boolean) => {
                  AppStore.setMode(isOn ? 'editor' : 'reader');
                })
            }
            .width('100%')
            Row() {
              Column({ space: 3 }) {
                Text('长辈大字').fontSize(15).fontColor('#2B2622')
                Text('阅读模式放大字号，按钮更好按').fontSize(12).fontColor('#8A7E73')
              }
              .alignItems(HorizontalAlign.Start)
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.largeText })
                .selectedColor('#6B4A29')
                .onChange((isOn: boolean) => {
                  AppStore.setLargeText(isOn);
                })
            }
            .width('100%')
          }
          .padding(16)
          .width('100%')
          .backgroundColor('#FFFDF9')
          .borderRadius(16)

          // 声音
          this.SectionTitle('声音')
          Column({ space: 12 }) {
            Row() {
              Column({ space: 3 }) {
                Text('背景音乐').fontSize(15).fontColor('#2B2622')
                Text('翻阅时连续播放，可跨章节保持').fontSize(12).fontColor('#8A7E73')
              }
              .alignItems(HorizontalAlign.Start)
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.bgmOn })
                .selectedColor('#6B4A29')
                .onChange((isOn: boolean) => {
                  this.toggleBgm(isOn);
                })
            }
            .width('100%')
          }
          .padding(16)
          .width('100%')
          .backgroundColor('#FFFDF9')
          .borderRadius(16)

          // 隐私
          this.SectionTitle('隐私与安全')
          Column({ space: 14 }) {
            Row() {
              Column({ space: 3 }) {
                Text('设备锁').fontSize(15).fontColor('#2B2622')
                Text(this.lockEnabled ? '已开启，打开 App 需输入密码' : '未开启').fontSize(12).fontColor('#8A7E73')
              }
              .alignItems(HorizontalAlign.Start)
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.lockEnabled })
                .selectedColor('#6B4A29')
                .onChange((isOn: boolean) => {
                  this.setLock(isOn);
                })
            }
            .width('100%')
            if (this.lockEnabled) {
              Text('重设密码')
                .fontSize(14)
                .fontColor('#6B4A29')
                .onClick(() => {
                  this.pinDraft = '';
                  this.pinAgain = '';
                  this.pinPanel = true;
                })
            }
            Divider().color('#EFE6D8')
            Text('隐私政策').fontSize(15).fontColor('#2B2622')
              .width('100%')
              .onClick(() => {
                this.openPrivacy();
              })
            Text('所有资料只存在这台设备，不上传、不联网、不采集。').fontSize(12)
              .fontColor('#8A7E73')
              .lineHeight(19)
              .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .width('100%')
          .backgroundColor('#FFFDF9')
          .borderRadius(16)

          // 购买
          this.SectionTitle('购买')
          Column({ space: 12 }) {
            Row() {
              Text('当前版本').fontSize(15).fontColor('#2B2622')
              Blank()
              Text(this.tierText()).fontSize(13).fontColor('#8A6A45')
            }
            .width('100%')
            if (this.tier !== 'full') {
              Button('去解锁全部功能')
                .width('100%')
                .height(44)
                .backgroundColor('#6B4A29')
                .fontColor('#FFFFFF')
                .onClick(() => {
                  router.pushUrl({ url: 'pages/paywall/PaywallPage' });
                })
            }
            Text('恢复购买')
              .fontSize(14)
              .fontColor('#6B4A29')
              .width('100%')
              .textAlign(TextAlign.Center)
              .onClick(() => {
                this.restorePurchase();
              })
          }
          .padding(16)
          .width('100%')
          .backgroundColor('#FFFDF9')
          .borderRadius(16)

          // 数据
          this.SectionTitle('档案备份')
          Column({ space: 12 }) {
            Button(this.working ? '处理中…' : '导出档案包')
              .width('100%')
              .height(44)
              .backgroundColor('#F2E7D8')
              .fontColor('#6B4A29')
              .enabled(!this.working)
              .onClick(() => {
                this.exportArchive();
              })
            Button(this.working ? '处理中…' : '导入档案包')
              .width('100%')
              .height(44)
              .backgroundColor('#F2E7D8')
              .fontColor('#6B4A29')
              .enabled(!this.working)
              .onClick(() => {
                this.importArchive();
              })
            Text('档案包是 .echosarchive.zip，含全部照片、旁白与文字，可存到云盘或换机恢复。')
              .fontSize(12)
              .fontColor('#8A7E73')
              .lineHeight(19)
              .width('100%')
          }
          .padding(16)
          .width('100%')
          .backgroundColor('#FFFDF9')
          .borderRadius(16)

          Text('岁月回声 1.0.0 · 只存本机')
            .fontSize(12)
            .fontColor('#A2958A')
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 8, bottom: 30 })
        }
        .padding({ left: 20, right: 20, top: 6 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)

      if (this.pinPanel) {
        this.PinPanel()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F1E8')
  }

  @Builder
  PinPanel() {
    Column({ space: 12 }) {
      Text('设置设备锁密码')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor('#2B2622')
        .width('100%')
      Text('4-6 位数字，只保存在本机。忘记密码只能重装 App，档案会一起丢失，请务必先导出备份。')
        .fontSize(12)
        .fontColor('#B5483A')
        .lineHeight(19)
        .width('100%')
      TextInput({ text: this.pinDraft, placeholder: '输入密码' })
        .type(InputType.Number)
        .maxLength(6)
        .height(44)
        .onChange((value: string) => {
          this.pinDraft = value;
        })
      TextInput({ text: this.pinAgain, placeholder: '再输入一次' })
        .type(InputType.Number)
        .maxLength(6)
        .height(44)
        .onChange((value: string) => {
          this.pinAgain = value;
        })
      Row({ space: 12 }) {
        Button('取消')
          .backgroundColor('#EFE6D8')
          .fontColor('#6B4A29')
          .layoutWeight(1)
          .onClick(() => {
            this.pinPanel = false;
          })
        Button('开启')
          .backgroundColor('#6B4A29')
          .fontColor('#FFFFFF')
          .layoutWeight(1)
          .onClick(() => {
            this.confirmPin();
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

  @Builder
  SectionTitle(text: string) {
    Text(text)
      .fontSize(13)
      .fontColor('#8A7E73')
      .width('100%')
      .padding({ left: 6, top: 6 })
  }
}
