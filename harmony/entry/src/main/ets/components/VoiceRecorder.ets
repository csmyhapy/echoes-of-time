import { common, abilityAccessCtrl, Permissions, PermissionRequestResult } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { relationalStore } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { Db } from '../data/Db';
import { Repository } from '../data/Repository';
import { MediaStore } from '../data/MediaStore';
import { VoiceNote } from '../models/Models';
import { AudioRecorder } from '../services/AudioRecorder';
import { AudioService } from '../services/AudioService';
import { Entitlements } from '../services/Entitlements';

/**
 * 按住说话：长按开始录，松手自动保存并入库。
 * scope = person | node | photo；同一目标重录时旧录音会被替换（先删库再删文件）。
 */
@Component
export struct VoiceRecorder {
  @Prop personId: string = '';
  @Prop scope: string = 'node';
  @Prop targetID: string = '';
  @Prop hasVoice: boolean = false;
  @Prop voiceId: string = '';
  @Prop existingCount: number = 0;
  @Prop fontSize: number = 14;
  @Prop compact: boolean = false;

  @State recording: boolean = false;
  @State seconds: number = 0;
  @State busy: boolean = false;

  private timer: number = -1;
  private currentFileName: string = '';
  private ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  onSaved: () => void = () => {
  };

  aboutToDisappear(): void {
    if (this.recording) {
      this.stopRecording();
    }
  }

  private async ensurePermission(): Promise<boolean> {
    const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    const permissions: Permissions[] = ['ohos.permission.MICROPHONE'];
    try {
      const result: PermissionRequestResult =
        await atManager.requestPermissionsFromUser(this.ctx, permissions);
      return result.authResults.length > 0 &&
        result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (e) {
      return false;
    }
  }

  private async begin(): Promise<void> {
    if (this.busy || this.recording) {
      return;
    }
    const max: number = Entitlements.maxVoices();
    if (this.voiceId.length === 0 && this.existingCount >= max) {
      promptAction.showToast({ message: Entitlements.limitHint('段旁白', max) });
      return;
    }
    const granted: boolean = await this.ensurePermission();
    if (!granted) {
      promptAction.showToast({ message: '需要麦克风权限才能录音' });
      return;
    }
    this.busy = true;
    try {
      await AudioService.stop();
      const fileName: string = `rec_${util.generateRandomUUID()}.m4a`;
      const path: string = MediaStore.filePath(this.ctx, this.personId, fileName);
      await AudioRecorder.start(path);
      this.currentFileName = fileName;
      this.recording = true;
      this.seconds = 0;
      this.timer = setInterval(() => {
        this.seconds = this.seconds + 1;
        if (this.seconds >= 300) {
          this.stopRecording();
        }
      }, 1000);
    } catch (e) {
      promptAction.showToast({ message: '录音启动失败，请检查麦克风是否被占用' });
    } finally {
      this.busy = false;
    }
  }

  private async stopRecording(): Promise<void> {
    if (!this.recording) {
      return;
    }
    this.recording = false;
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    const seconds: number = this.seconds;
    this.busy = true;
    try {
      await AudioRecorder.stop();
      if (seconds < 1) {
        MediaStore.deleteFile(this.ctx, this.personId, this.currentFileName);
        promptAction.showToast({ message: '太短了，按住多录一会儿' });
        return;
      }
      const store: relationalStore.RdbStore = await Db.get(this.ctx);
      if (this.voiceId.length > 0) {
        await Repository.deleteVoice(store, this.voiceId);
      }
      const voice: VoiceNote = {
        id: util.generateRandomUUID(),
        personId: this.personId,
        scope: this.scope,
        targetID: this.targetID,
        audioFileName: this.currentFileName,
        duration: seconds,
        createdAt: Date.now()
      };
      if (voice.audioFileName.length > 0) {
        await Repository.insertVoice(store, voice);
        this.onSaved();
        promptAction.showToast({ message: '录音已保存' });
      }
    } finally {
      this.busy = false;
    }
  }

  build() {
    Row({ space: 8 }) {
      Text(this.recording ? '●' : '🎙')
        .fontSize(this.compact ? 15 : 17)
        .fontColor(this.recording ? '#B5483A' : '#6B4A29')
      Text(this.recording ? `录音中 ${this.seconds}s` : (this.hasVoice ? '按住重录旁白' : '按住录一段旁白'))
        .fontSize(this.fontSize)
        .fontColor(this.recording ? '#B5483A' : '#6B4A29')
      if (this.recording) {
        Text(`最长 5 分钟`)
          .fontSize(this.fontSize - 4)
          .fontColor('#B3A79A')
      }
    }
    .padding({ left: 14, right: 14, top: 9, bottom: 9 })
    .backgroundColor(this.recording ? '#FBEAE5' : '#F2E7D8')
    .borderRadius(18)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.begin();
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.stopRecording();
      }
    })
  }
}
