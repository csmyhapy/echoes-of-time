import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AppStore } from '../services/AppStore';

const DOMAIN: number = 0x0000;
const TAG: string = 'EchoesOfTime';

export default class EntryAbility extends UIAbility {
  private stage: window.WindowStage | undefined = undefined;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.stage = windowStage;
    // 先把全局设置读进 AppStorage，再加载首页，避免页面读到空状态
    AppStore.init(this.context).then(() => {
      windowStage.loadContent('pages/Index', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
      });
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'Failed to init settings: %{public}s', err.message);
      windowStage.loadContent('pages/Index');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onForeground');
    // 每次回到前台累加计数，首页据此重新上锁（对齐 iOS scenePhase 行为）
    const tick: number = AppStorage.get<number>('fgTick') ?? 0;
    AppStorage.setOrCreate<number>('fgTick', tick + 1);

    // 设备锁开启时，回前台直接回到带锁首页，避免在其他页面暴露内容
    const locked: boolean = AppStorage.get<boolean>('lockEnabled') === true;
    const pin: string = AppStorage.get<string>('pin') ?? '';
    if (locked && pin.length > 0 && this.stage !== undefined) {
      this.stage.loadContent('pages/Index');
    }
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');
  }
}
