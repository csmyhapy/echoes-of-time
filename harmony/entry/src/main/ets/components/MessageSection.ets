import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { Db } from '../data/Db';
import { Repository } from '../data/Repository';
import { Message } from '../models/Models';
import { fmtDate } from '../utils/Common';
import { Entitlements } from '../services/Entitlements';

/**
 * 家人留言区：挂在人物 / 章节 / 照片上。
 * 与 iOS MessageSection 一致：本地、不联网、可删。
 */
@Component
export struct MessageSection {
  @Prop personId: string = '';
  @Prop nodeId: string = '';
  @Prop photoId: string = '';
  @Prop messages: Message[] = [];
  @Prop editable: boolean = true;
  @Prop fontSize: number = 14;

  @State inputName: string = '';
  @State inputText: string = '';
  @State sending: boolean = false;

  onChanged: () => void = () => {
  };

  private async submit(): Promise<void> {
    if (this.inputText.trim().length === 0) {
      promptAction.showToast({ message: '写点什么再发吧' });
      return;
    }
    const max: number = Entitlements.maxMessages();
    if (this.messages.length >= max) {
      promptAction.showToast({ message: Entitlements.limitHint('条留言', max) });
      return;
    }
    this.sending = true;
    try {
      const store: relationalStore.RdbStore = await Db.get(this.getUIContext().getHostContext() as common.Context);
      const message: Message = {
        id: util.generateRandomUUID(),
        personId: this.personId,
        nodeId: this.nodeId,
        photoId: this.photoId,
        userName: this.inputName.trim().length > 0 ? this.inputName.trim() : '家人',
        content: this.inputText.trim(),
        role: 'family',
        parentID: '',
        isDeleted: false,
        createdAt: Date.now()
      };
      await Repository.insertMessage(store, message);
      this.inputText = '';
      this.onChanged();
    } finally {
      this.sending = false;
    }
  }

  private confirmDelete(message: Message): void {
    AlertDialog.show({
      title: '删除这条留言？',
      message: message.content,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#B5483A',
        action: () => {
          this.deleteMessage(message);
        }
      }
    });
  }

  private async deleteMessage(message: Message): Promise<void> {
    const store: relationalStore.RdbStore =
      await Db.get(this.getUIContext().getHostContext() as common.Context);
    await Repository.deleteMessage(store, message.id);
    this.onChanged();
  }

  build() {
    Column({ space: 10 }) {
      Text(`家人留言 · ${this.messages.length}`)
        .fontSize(this.fontSize + 3)
        .fontWeight(FontWeight.Medium)
        .fontColor('#2B2622')
        .width('100%')

      if (this.messages.length === 0) {
        Text('这里还没有留言。亲戚们想起什么，都可以写在下面。')
          .fontSize(this.fontSize - 1)
          .fontColor('#8A7E73')
          .lineHeight(this.fontSize + 8)
          .width('100%')
      }

      ForEach(this.messages, (message: Message) => {
        Column({ space: 4 }) {
          Row({ space: 8 }) {
            Text(message.userName)
              .fontSize(this.fontSize - 1)
              .fontColor('#8A6A45')
              .fontWeight(FontWeight.Medium)
            Text(fmtDate(message.createdAt))
              .fontSize(this.fontSize - 3)
              .fontColor('#B3A79A')
            Blank()
          }
          .width('100%')
          Text(message.content)
            .fontSize(this.fontSize)
            .fontColor('#4A423B')
            .lineHeight(this.fontSize + 10)
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .padding(12)
        .width('100%')
        .backgroundColor('#FBF6EE')
        .borderRadius(12)
        .gesture(LongPressGesture().onAction(() => {
          if (this.editable) {
            this.confirmDelete(message);
          }
        }))
      }, (message: Message) => message.id)

      if (this.editable) {
        Column({ space: 8 }) {
          TextInput({ text: this.inputName, placeholder: '你的名字（可不填）' })
            .height(40)
            .onChange((value: string) => {
              this.inputName = value;
            })
          TextArea({ text: this.inputText, placeholder: '写下你记得的那件事…' })
            .height(72)
            .onChange((value: string) => {
              this.inputText = value;
            })
          Button(this.sending ? '发送中…' : '留一句话')
            .width('100%')
            .height(42)
            .backgroundColor('#6B4A29')
            .fontColor('#FFFFFF')
            .enabled(!this.sending)
            .onClick(() => {
              this.submit();
            })
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#FFFDF9')
        .borderRadius(12)
      }
    }
    .width('100%')
  }
}
