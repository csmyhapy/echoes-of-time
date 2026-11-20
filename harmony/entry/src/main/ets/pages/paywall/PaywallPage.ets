import { common } from '@kit.AbilityKit';
import { router, promptAction } from '@kit.ArkUI';
import { AppStore } from '../../services/AppStore';
import {
  IapService, PurchaseOutcome, PRODUCT_BASIC, PRODUCT_UPGRADE, PRODUCT_FULL
} from '../../services/IapService';

/**
 * 付费墙：三档非消耗型，价格与 AGC 配置保持同步（此处文案用于商店页一致性展示）。
 * 闭环：basic + upgrade_full = full。
 */
@Entry
@Component
struct PaywallPage {
  @StorageProp('tier') tier: string = 'none';
  @StorageProp('basicOwned') basicOwned: boolean = false;
  @StorageProp('upgradeOwned') upgradeOwned: boolean = false;
  @StorageProp('fullOwned') fullOwned: boolean = false;
  @StorageProp('mode') mode: string = 'editor';

  @State busy: string = '';
  @State envOk: boolean = true;

  private ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    this.checkEnv();
  }

  private async checkEnv(): Promise<void> {
    this.envOk = await IapService.checkEnvironment(this.ctx);
    if (this.envOk) {
      await IapService.queryProducts(this.ctx);
    }
  }

  private async buy(productId: string): Promise<void> {
    if (this.busy.length > 0) {
      return;
    }
    this.busy = productId;
    try {
      const outcome: PurchaseOutcome = await IapService.purchase(this.ctx, productId);
      if (outcome === 'ok') {
        promptAction.showToast({ message: '购买成功，功能已解锁' });
      } else if (outcome === 'owned') {
        promptAction.showToast({ message: '这个商品已经买过了，权益已恢复' });
      } else {
        promptAction.showToast({ message: '购买未完成，可稍后再试' });
      }
    } finally {
      this.busy = '';
    }
  }

  private async restore(): Promise<void> {
    if (this.busy.length > 0) {
      return;
    }
    this.busy = 'restore';
    try {
      const ok: boolean = await IapService.restore(this.ctx);
      promptAction.showToast({ message: ok ? '已恢复你的购买' : '没有查询到已购记录' });
    } finally {
      this.busy = '';
    }
  }

  private priceOf(productId: string): string {
    if (productId === PRODUCT_BASIC) {
      return '¥6';
    }
    if (productId === PRODUCT_UPGRADE) {
      return '¥322';
    }
    return '¥328';
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
        Text('解锁全部功能')
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
        Column({ space: 16 }) {
          Text('这台设备上的所有照片、旁白与留言都只存本机。一次买断，永久可用，无订阅、无账号、无云端。')
            .fontSize(14)
            .fontColor('#6F665D')
            .lineHeight(24)
            .width('100%')

          if (this.tier === 'full') {
            Column({ space: 8 }) {
              Text('已解锁全部功能')
                .fontSize(20)
                .fontWeight(FontWeight.Medium)
                .fontColor('#2B2622')
              Text('章节、照片、旁白、留言都不限量，PDF 回忆册可完整导出。')
                .fontSize(14)
                .fontColor('#6F665D')
            }
            .alignItems(HorizontalAlign.Start)
            .padding(18)
            .width('100%')
            .backgroundColor('#F2E7D8')
            .borderRadius(16)
          } else {
            this.TierCard(PRODUCT_BASIC, '入门版', '5 章节 · 80 张照片 · 3 段旁白 · 3 条留言，可导出分享卡片',
              this.basicOwned)
            if (this.basicOwned && !this.upgradeOwned) {
              this.TierCard(PRODUCT_UPGRADE, '补差价升级', '在入门版基础上补齐差价，升级为完整版',
                this.upgradeOwned)
            }
            this.TierCard(PRODUCT_FULL, '完整版（买断）', '章节/照片/旁白/留言全部不限量，PDF 画册与档案包完整导出',
              this.fullOwned)
          }

          if (!this.envOk) {
            Text('当前华为账号所在地区暂不支持应用内购买，请确认账号服务地为中国大陆。')
              .fontSize(13)
              .fontColor('#B5483A')
              .lineHeight(20)
              .width('100%')
          }

          Text('恢复购买')
            .fontSize(14)
            .fontColor('#6B4A29')
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 8, bottom: 8 })
            .onClick(() => {
              this.restore();
            })

          Text('购买由华为应用市场完成结算。非消耗型商品一经购买不可重复购买；卸载重装后用「恢复购买」找回权益。')
            .fontSize(12)
            .fontColor('#A2958A')
            .lineHeight(19)
            .width('100%')

          Blank().height(24)
        }
        .padding({ left: 20, right: 20, top: 6 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F1E8')
  }

  @Builder
  TierCard(productId: string, title: string, desc: string, owned: boolean) {
    Column({ space: 8 }) {
      Row() {
        Text(title)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#2B2622')
        Blank()
        Text(owned ? '已拥有' : this.priceOf(productId))
          .fontSize(16)
          .fontColor(owned ? '#8A7E73' : '#6B4A29')
      }
      .width('100%')
      Text(desc)
        .fontSize(13)
        .fontColor('#6F665D')
        .lineHeight(21)
        .width('100%')
      Button(owned ? '已拥有' : (this.busy === productId ? '处理中…' : '购买'))
        .width('100%')
        .height(44)
        .backgroundColor(owned ? '#D8CCBD' : '#6B4A29')
        .fontColor(owned ? '#7A6E63' : '#FFFFFF')
        .enabled(!owned && this.busy.length === 0 && this.envOk)
        .onClick(() => {
          this.buy(productId);
        })
    }
    .alignItems(HorizontalAlign.Start)
    .padding(18)
    .width('100%')
    .backgroundColor('#FFFDF9')
    .borderRadius(16)
  }
}
