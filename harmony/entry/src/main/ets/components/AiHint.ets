import { pasteboard } from '@kit.BasicServicesKit';
import { i18n } from '@kit.LocalizationKit';

/**
 * 文案库：按 AppStorage language（zh / en / system）切换，system 跟随系统语言。
 * 中文环境以外的语种统一给英文模板（与 iOS 一致）。
 */
export class PromptLib {
  static isZh(): boolean {
    const lang: string = AppStorage.get<string>('language') ?? 'system';
    if (lang === 'zh') {
      return true;
    }
    if (lang === 'en') {
      return false;
    }
    try {
      return i18n.getSystemLanguage().toLowerCase().startsWith('zh');
    } catch (e) {
      return true;
    }
  }

  static title(): string {
    return PromptLib.isZh() ? '写不出来？让 AI 帮你' : 'Stuck? Let AI help you';
  }

  static copyLabel(): string {
    return PromptLib.isZh() ? '复制参考提示词' : 'Copy the prompt';
  }

  static copiedLabel(): string {
    return PromptLib.isZh() ? '已复制' : 'Copied';
  }

  static shortGuide(): string {
    return PromptLib.isZh()
      ? '一句话写不好？把要点说给 AI，让它帮你浓缩成一句简介。'
      : 'Can\'t fit it in one line? Tell AI the key points and let it condense them into a short intro.';
  }

  /** scene: person | node | photo */
  static guide(scene: string): string {
    const zh: boolean = PromptLib.isZh();
    if (scene === 'node') {
      return zh
        ? '不用写成章。把这一阶段记得的几件事零散说给 AI，让它帮你按顺序整理成文、调好语气，你再修改。'
        : 'No need to write a full chapter. Tell AI a few things you remember from this period; it will arrange them in order and set the tone, and you can revise afterward.';
    }
    if (scene === 'photo') {
      return zh
        ? '照片配文不用发愁。把拍摄时间、地点、人物和当时的情境说给 AI，让它帮你写成一小段。'
        : 'Struggling for a caption? Tell AI when, where, who, and what was happening, and it will write a short passage for you.';
    }
    return zh
      ? '不用从头写完整。把记得的大事、时间、人物和感受零散列出来，交给 AI 整理成通顺的人生故事，再由你增删修改。'
      : 'You don\'t have to write the whole thing. Jot down the major events, times, people, and feelings you remember, hand them to AI to organize into a flowing life story, then edit it yourself.';
  }

  /** 可复制提示词：scene 区分三种长文 */
  static prompt(scene: string): string {
    const zh: boolean = PromptLib.isZh();
    if (scene === 'node') {
      return zh
        ? '请帮我把这一段时期的零散回忆整理成一个章节，按时间和事件顺序写得通顺自然，保留具体细节、人物和当时的感受，不要添油加醋，文字朴实有温度。\n\n我的素材：（在这里粘贴这一阶段记得的几件事，几句话即可）'
        : 'Please help me turn these scattered recollections of this period into one chapter, ordered by time and events and written naturally. Keep the concrete details, people, and how I felt; do not embellish; keep the tone plain and warm.\n\nMy notes: (paste a few things you remember from this period — a few sentences are enough)';
    }
    if (scene === 'photo') {
      return zh
        ? '请围绕这张照片，根据我给的零散信息写一段简短生动的说明，交代时间、地点、人物和当时的情境与感受，不虚构。\n\n我的素材：（在这里写这张照片拍于何时何地、有谁、发生了什么）'
        : 'Based on the scattered notes I give you about this photo, write a short, lively caption: when it was taken, where, who is in it, and the situation and feelings at the time; do not make anything up.\n\nMy notes: (write when and where this photo was taken, who is in it, and what was happening)';
    }
    return zh
      ? '请帮我把下面零散的人生经历整理成一篇平实、温暖的回忆录，按时间顺序组织，保留真实细节和我说话的口吻，不要编造我没提到的内容，篇幅适中。\n\n我的素材：（在这里粘贴你想到的人和事、时间、地点、感受，几条短句即可）'
      : 'Please help me organize these scattered memories of my life into a plain, warm memoir in chronological order. Keep the true details and my own voice; do not invent anything I did not mention; keep it a comfortable length.\n\nMy notes: (paste the people, events, times, places, and feelings you remember here — a few short lines are enough)';
  }
}

/**
 * 长文输入框下方的 AI 协助提示；一句话简介用 long=false 只显示轻引导。
 */
@Component
export struct AiHint {
  @Prop scene: string = 'person';
  @Prop long: boolean = true;
  @State copied: boolean = false;
  private timer: number = -1;

  private copyPrompt(): void {
    const text: string = PromptLib.prompt(this.scene);
    pasteboard.getSystemPasteboard()
      .setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text))
      .then(() => {
        this.copied = true;
        if (this.timer >= 0) {
          clearTimeout(this.timer);
        }
        this.timer = setTimeout(() => {
          this.copied = false;
        }, 1500);
      })
      .catch(() => {
        this.copied = false;
      });
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearTimeout(this.timer);
    }
  }

  build() {
    if (!this.long) {
      Text(PromptLib.shortGuide())
        .fontSize(12)
        .fontColor('#9A8C7F')
        .lineHeight(18)
        .width('100%')
        .padding({ left: 2, right: 2 })
    } else {
      Column({ space: 8 }) {
        Text(PromptLib.title())
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#6B4A29')
          .width('100%')
        Text(PromptLib.guide(this.scene))
          .fontSize(12)
          .fontColor('#8A7E73')
          .lineHeight(19)
          .width('100%')
        Text(this.copied ? PromptLib.copiedLabel() : PromptLib.copyLabel())
          .fontSize(12)
          .fontColor(this.copied ? '#7A8B6F' : '#6B4A29')
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(12)
          .backgroundColor('#F2E7D8')
          .onClick(() => {
            if (!this.copied) {
              this.copyPrompt();
            }
          })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(12)
      .backgroundColor('#FBF4EA')
      .borderRadius(12)
      .border({ width: 1, color: '#EFE2D0' })
    }
  }
}
