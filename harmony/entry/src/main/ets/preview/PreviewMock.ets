import { common } from '@kit.AbilityKit';
import { DemoSeeder } from '../data/DemoSeeder';
import { PersonBundle } from '../models/Models';

/**
 * 预览器专用的数据通道。
 *
 * 背景：ArkUI 预览器把 relationalStore 做成了 mock（写入不落库、查询返回空），
 * 首页只剩一个空列表，没法用来截图验收；沙箱文件也是虚拟的，图片读不到。
 * 做法：用 context.filesDir 是否包含 ".idea/previewer" 判断"这是 IDE 预览器"
 * （真机沙箱是 /data/storage/... 路径，恒不命中）。命中时页面跳过数据库，
 * 直接用 DemoSeeder 在内存里构建出与首启 demo 完全一致的 PersonBundle；
 * 图片改读 rawfile。真机行为不变。
 */
export class PreviewMock {
  /** 预览器里固定使用这个档案 id（首启 demo 在真机上是随机 UUID） */
  static readonly PERSON_ID: string = 'preview-demo-person';

  static enabled: boolean = false;

  private static cache: PersonBundle | undefined = undefined;

  /**
   * 是否处于预览 mock 模式（幂等）。
   * 判据：预览器把沙箱 filesDir 落在工程的 .idea/previewer 下（真机是
   * /data/storage/... 的沙箱路径），因此这个子串只会在 IDE 预览器里出现。
   */
  static detect(context: common.Context): boolean {
    if (PreviewMock.enabled) {
      return true;
    }
    PreviewMock.enabled = context.filesDir.indexOf('.idea/previewer') >= 0;
    return PreviewMock.enabled;
  }

  /** demo 资源文件名（photo_xxx.jpg / voice_xxx.m4a）去掉前后缀 */
  private static baseName(fileName: string): string {
    let base: string = fileName;
    if (base.startsWith('photo_')) {
      base = base.substring(6);
    } else if (base.startsWith('voice_')) {
      base = base.substring(6);
    }
    const dot: number = base.lastIndexOf('.');
    if (dot > 0) {
      base = base.substring(0, dot);
    }
    return base;
  }

  /**
   * 预览器的沙箱文件是虚拟的（fs 写入不落盘），所以图片直接读 rawfile。
   * 真机走 MediaStore.imageUri 的沙箱路径，此方法不会被调用。
   */
  static photoSource(fileName: string): ResourceStr {
    if (fileName.length === 0) {
      return '';
    }
    return $rawfile(`demo/photos/${PreviewMock.baseName(fileName)}.jpg`);
  }

  /** 构建（并缓存）整份 demo 档案 */
  static async bundle(context: common.Context): Promise<PersonBundle> {
    if (PreviewMock.cache !== undefined) {
      return PreviewMock.cache;
    }
    const built: PersonBundle = await DemoSeeder.buildBundle(context, PreviewMock.PERSON_ID, Date.now());
    PreviewMock.cache = built;
    return built;
  }
}
