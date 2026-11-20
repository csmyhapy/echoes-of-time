import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { Person, PersonBundle, Node, Photo, VoiceNote, Message } from '../models/Models';
import { Repository } from './Repository';
import { MediaStore } from './MediaStore';

/**
 * 内置演示档案：王秀兰（长沙纺织厂女工，1936–2022）。
 * 与 iOS 的 insertChinese 完全同源：4 章节 / 17 照片 / 8 留言 / 9 段旁白。
 * 资源在 resources/rawfile/demo 下，首次启动复制到沙箱。
 */

interface SeedPhoto {
  base: string;
  caption: string;
  story: string;
  audio: string;
}

interface SeedMessage {
  userName: string;
  content: string;
  /** 挂在第几个章节；-1 表示挂在照片上 */
  nodeIndex: number;
  /** nodeIndex = -1 时指向 photo.base */
  photoBase: string;
}

interface SeedNode {
  name: string;
  yearRange: string;
  summary: string;
  story: string;
  voice: string;
  voiceDur: number;
  photos: SeedPhoto[];
  messages: SeedMessage[];
}

const SEED_NODES: SeedNode[] = [
  {
    name: '童年时光',
    yearRange: '1936–1949',
    summary: '在湘江边的土砖屋里长大，屋后有稻田，门前有池塘。',
    story: '我生在湘江边的土砖屋，屋后是稻田，门前一口塘。娘在青石台阶上捶衣服，孩子们在塘边玩水。' +
      '村小学就在祠堂旁边，木课桌，土墙上一块木黑板。日子苦，可记得的都是亮的。',
    voice: 'demo_node_childhood',
    voiceDur: 21,
    photos: [
      { base: 'demo_zh_childhood', caption: '老屋门前，八岁那年', story: '这是我八岁，站在老屋门前，身后是土砖墙。', audio: '' },
      { base: 'demo_zh_c1', caption: '塘边玩水', story: '夏天光着脚在塘边，水刚没过小腿，凉丝丝的。', audio: 'demo_photo_c1' },
      { base: 'demo_zh_c2', caption: '村小学的木课桌', story: '教室在祠堂旁，土墙上一块木黑板，我们坐长条板凳。', audio: '' },
      { base: 'demo_zh_c3', caption: '娘在河边捶衣服', story: '娘蹲在青石台阶上捶衣服，一锤子一锤子，声音传得很远。', audio: '' }
    ],
    messages: [
      { userName: '王志强', content: '姐，你总说那口塘，我记着。那年夏天你把我从水里拽上来，自己也吓了一身水。', nodeIndex: 0, photoBase: '' }
    ]
  },
  {
    name: '我们的婚礼',
    yearRange: '1962',
    summary: '一件红棉袄，一屋子的乡亲，和墙上那个大大的双喜。',
    story: '六二年冬天结的婚。红棉袄是跟表姐借的，院子里摆了八桌，墙上贴个大红喜字。' +
      '他穿一件洗得发白的中山装，站得笔直。照相馆的结婚照是第二年补的。',
    voice: 'demo_node_wedding',
    voiceDur: 25,
    photos: [
      { base: 'demo_zh_wedding', caption: '结婚那天，院子里', story: '结婚那天院子里摆酒席，亲戚都来了。', audio: '' },
      { base: 'demo_zh_w1', caption: '院子里摆了八桌', story: '乡亲们围坐在方桌旁，墙上贴着大红喜字。', audio: '' },
      { base: 'demo_zh_w2', caption: '第二年补照的结婚照', story: '照相馆里补的，他嫌自己站得太直，像根电线杆。', audio: 'demo_photo_w2' },
      { base: 'demo_zh_w3', caption: '陪嫁的木箱和被褥', story: '木箱、红被褥、搪瓷脸盆，一样一样摆好。', audio: '' }
    ],
    messages: [
      { userName: '李桂芳', content: '红棉袄是我陪你去借的，你穿上就一直笑，新郎官站得比电线杆还直。', nodeIndex: 1, photoBase: '' },
      { userName: '李桂芳', content: '这张补照的，你俩站得真端正，像年画里的人。', nodeIndex: -1, photoBase: 'demo_zh_w2' }
    ]
  },
  {
    name: '纺织厂的岁月',
    yearRange: '1958–1990',
    summary: '在织布机前站了三十年，听惯了机器响。',
    story: '五八年进的纺织厂，织布机一响就是一整天，三班倒。站久了腿肿，耳朵到现在还嗡嗡的。' +
      '一整班姐妹们在一起，中午拎着铝饭盒去食堂，那是我年轻最有劲的十几年。',
    voice: 'demo_node_factory',
    voiceDur: 23,
    photos: [
      { base: 'demo_zh_worker', caption: '车间里的织布机', story: '我在这台织布机前站了三十年，闭着眼都知道哪根线断了。', audio: 'demo_photo_worker' },
      { base: 'demo_zh_k1', caption: '厂门口的班组合影', story: '一整班姐妹在厂门口合影，蓝工装，工作帽。', audio: '' },
      { base: 'demo_zh_k2', caption: '食堂的铝饭盒', story: '中午拎着饭盒去食堂，姐妹们凑一桌吃饭。', audio: '' },
      { base: 'demo_zh_k3', caption: '下班骑车回家', story: '下班路上一队人骑自行车，沿路的杨树叶子沙沙响。', audio: '' }
    ],
    messages: [
      { userName: '张玉梅', content: '三班的姐妹们还记得你，机器一响，你说话最响。', nodeIndex: 2, photoBase: '' },
      { userName: '张玉梅', content: '这台机器我也熟，我们班当年就是在它旁边下的班。', nodeIndex: -1, photoBase: 'demo_zh_worker' }
    ]
  },
  {
    name: '晚年生活',
    yearRange: '1991–2022',
    summary: '院子里晾着辣椒，孙子孙女围着桌子包饺子。',
    story: '退休以后，我就在院子里种点辣椒，红了就挂在屋檐下。孙子孙女一回来，我就擀皮包饺子。' +
      '日子慢，人也老了，可一大家子坐在一起，我心里就踏实。',
    voice: 'demo_node_later',
    voiceDur: 21,
    photos: [
      { base: 'demo_zh_later', caption: '和孙子孙女一起包饺子', story: '孙女包的歪歪扭扭，她还非要摆在最中间。', audio: 'demo_photo_later' },
      { base: 'demo_zh_l1', caption: '屋檐下挂的辣椒', story: '辣椒红了就挂在屋檐下，一串一串的。', audio: '' },
      { base: 'demo_zh_l2', caption: '公园里晒太阳', story: '午后带孙子在公园长椅上坐坐，晒晒太阳。', audio: '' },
      { base: 'demo_zh_l3', caption: '年夜饭全家福', story: '一大家子围圆桌坐满，桌上有鱼有饺子。', audio: '' }
    ],
    messages: [
      { userName: '王小梅', content: '妈，院子里的辣椒还挂着，我们没舍得摘，等你回来。', nodeIndex: 3, photoBase: '' },
      { userName: '陈小雨', content: '奶奶，我现在也会包了，就是没您包得好看。', nodeIndex: -1, photoBase: 'demo_zh_later' }
    ]
  }
];

const PERSON_MESSAGE_USER: string = '陈小雨';
const PERSON_MESSAGE_TEXT: string = '奶奶，我们把您的照片和话都留着，想您了就翻一翻。';

export class DemoSeeder {

  /**
   * 纯内存构建整份 demo 档案（不写库）。
   * 真机首启与预览器共用同一套数据，保证预览截图与线上内容一致。
   */
  static async buildBundle(context: common.Context, personId: string, now: number): Promise<PersonBundle> {
    const voices: VoiceNote[] = [];
    const nodes: Node[] = [];
    const photos: Photo[] = [];
    const messages: Message[] = [];

    const person: Person = {
      id: personId,
      name: '王秀兰',
      birthYear: '1936–2022',
      summary: '长沙的一位普通女工，在纺织厂干了三十年。她留着每一张工牌、每一张粮票，还有儿女从小到大的成绩单。',
      story: '这是为了体验「岁月回声」而制作的虚构演示档案。王秀兰的人生是编的，但章节的结构是真的：' +
        '一段人生一个章节，配上当时的照片、声音和几句家常话。',
      coverImageFileName: MediaStore.importDemoPhoto(context, personId, 'demo_zh_cover'),
      bgmFileName: MediaStore.importDemoBgm(context, personId),
      bgmTitle: '故乡的晚风',
      createdAt: now,
      isDemo: true
    };

    // 人物级旁白
    voices.push({
      id: util.generateRandomUUID(),
      personId: personId,
      scope: 'person',
      targetID: '',
      audioFileName: MediaStore.importDemoVoice(context, personId, 'demo_person'),
      duration: 37,
      createdAt: now
    });

    for (let nodeIndex = 0; nodeIndex < SEED_NODES.length; nodeIndex++) {
      const seed: SeedNode = SEED_NODES[nodeIndex];
      const nodeId: string = util.generateRandomUUID();

      nodes.push({
        id: nodeId,
        personId: personId,
        name: seed.name,
        yearRange: seed.yearRange,
        summary: seed.summary,
        story: seed.story,
        coverImageFileName: '',
        sortOrder: nodeIndex,
        webOrder: 0,
        isVisible: true,
        createdAt: now + nodeIndex
      });

      if (seed.voice.length > 0) {
        voices.push({
          id: util.generateRandomUUID(),
          personId: personId,
          scope: 'node',
          targetID: nodeId,
          audioFileName: MediaStore.importDemoVoice(context, personId, seed.voice),
          duration: seed.voiceDur,
          createdAt: now + nodeIndex
        });
      }

      // 照片（同时记录 base → photoId 的映射，供照片级留言使用）
      const photoIds: Map<string, string> = new Map<string, string>();
      for (let i = 0; i < seed.photos.length; i++) {
        const seedPhoto: SeedPhoto = seed.photos[i];
        const photoId: string = util.generateRandomUUID();
        photos.push({
          id: photoId,
          personId: personId,
          nodeId: nodeId,
          imageFileName: MediaStore.importDemoPhoto(context, personId, seedPhoto.base),
          audioFileName: seedPhoto.audio.length > 0 ?
            MediaStore.importDemoVoice(context, personId, seedPhoto.audio) : '',
          caption: seedPhoto.caption,
          story: seedPhoto.story,
          tags: '',
          sortOrder: i,
          pairWithNext: false,
          createdAt: now + i
        });
        photoIds.set(seedPhoto.base, photoId);
      }

      // 留言：章节级 / 照片级
      for (let i = 0; i < seed.messages.length; i++) {
        const seedMessage: SeedMessage = seed.messages[i];
        let photoId: string = '';
        if (seedMessage.nodeIndex === -1) {
          const mapped: string | undefined = photoIds.get(seedMessage.photoBase);
          photoId = mapped === undefined ? '' : mapped;
        }
        messages.push({
          id: util.generateRandomUUID(),
          personId: personId,
          nodeId: seedMessage.nodeIndex === -1 ? '' : nodeId,
          photoId: photoId,
          userName: seedMessage.userName,
          content: seedMessage.content,
          role: 'family',
          parentID: '',
          isDeleted: false,
          createdAt: now + 100 + i
        });
      }
    }

    messages.push({
      id: util.generateRandomUUID(),
      personId: personId,
      nodeId: '',
      photoId: '',
      userName: PERSON_MESSAGE_USER,
      content: PERSON_MESSAGE_TEXT,
      role: 'family',
      parentID: '',
      isDeleted: false,
      createdAt: now + 500
    });

    return { person: person, nodes: nodes, photos: photos, voices: voices, messages: messages };
  }

  static async seedIfNeeded(context: common.Context, store: relationalStore.RdbStore): Promise<void> {
    if (await Repository.hasDemo(store)) {
      return;
    }

    const personId: string = util.generateRandomUUID();
    const bundle: PersonBundle = await DemoSeeder.buildBundle(context, personId, Date.now());

    await Repository.insertPerson(store, bundle.person);
    for (let i = 0; i < bundle.voices.length; i++) {
      await Repository.insertVoice(store, bundle.voices[i]);
    }
    for (let i = 0; i < bundle.nodes.length; i++) {
      await Repository.insertNode(store, bundle.nodes[i]);
    }
    for (let i = 0; i < bundle.photos.length; i++) {
      await Repository.insertPhoto(store, bundle.photos[i]);
    }
    for (let i = 0; i < bundle.messages.length; i++) {
      await Repository.insertMessage(store, bundle.messages[i]);
    }
  }
}
