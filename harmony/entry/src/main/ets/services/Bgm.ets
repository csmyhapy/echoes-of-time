import { common, wantAgent, WantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { AudioService } from './AudioService';

/**
 * 背景音乐：单个曲目循环，跨页不重置。
 * 进后台时需要「长时任务 AUDIO_PLAYBACK」，否则 5 秒后会被系统冻结。
 */
export class Bgm {
  private static enabled: boolean = false;
  private static background: boolean = false;
  private static path: string = '';

  static isEnabled(): boolean {
    return Bgm.enabled;
  }

  /** 打开 BGM 并尝试申请后台播放；申请失败只影响后台，不影响前台播放 */
  static async start(context: common.UIAbilityContext, path: string): Promise<void> {
    Bgm.path = path;
    Bgm.enabled = true;
    await AudioService.play(path, true);
    await Bgm.requestBackground(context);
  }

  private static async requestBackground(context: common.UIAbilityContext): Promise<void> {
    if (Bgm.background) {
      return;
    }
    try {
      const info: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: 'life.lifememory.echosoftime',
            abilityName: 'EntryAbility'
          }
        ],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const agent: WantAgent = await wantAgent.getWantAgent(info);
      await backgroundTaskManager.startBackgroundRunning(context,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, agent);
      Bgm.background = true;
    } catch (e) {
      // 未授予长时任务或设备不支持：退化为前台播放
      Bgm.background = false;
    }
  }

  static async stop(context: common.UIAbilityContext): Promise<void> {
    Bgm.enabled = false;
    await AudioService.stop();
    if (Bgm.background) {
      try {
        await backgroundTaskManager.stopBackgroundRunning(context);
      } catch (e) {
      }
      Bgm.background = false;
    }
  }
}
