import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { util } from '@kit.ArkTS';

/**
 * 媒体文件落盘。
 * 约定：filesDir/media/<personId>/ 下存照片与录音，数据库只记文件名。
 * 不存绝对路径——沙箱目录在升级/迁移后可能变化，存路径必然失效（iOS 也是同样设计）。
 */
export class MediaStore {

  static personDir(context: common.Context, personId: string): string {
    const dir: string = `${context.filesDir}/media/${personId}`;
    if (!fs.accessSync(dir)) {
      fs.mkdirSync(dir, true);
    }
    return dir;
  }

  static filePath(context: common.Context, personId: string, fileName: string): string {
    return `${MediaStore.personDir(context, personId)}/${fileName}`;
  }

  /** UI 显示用：沙箱文件转成 Image 组件可读的 file:// URI */
  static imageUri(context: common.Context, personId: string, fileName: string): string {
    if (fileName.length === 0) {
      return '';
    }
    return `file://${MediaStore.filePath(context, personId, fileName)}`;
  }

  static audioUri(context: common.Context, personId: string, fileName: string): string {
    if (fileName.length === 0) {
      return '';
    }
    return MediaStore.filePath(context, personId, fileName);
  }

  // MARK: - 内置 demo 资源（rawfile → 沙箱）

  static importDemoPhoto(context: common.Context, personId: string, baseName: string): string {
    const fileName: string = `photo_${baseName}.jpg`;
    const dest: string = MediaStore.filePath(context, personId, fileName);
    if (fs.accessSync(dest)) {
      return fileName;
    }
    const bytes: Uint8Array = context.resourceManager.getRawFileContentSync(`demo/photos/${baseName}.jpg`);
    const file = fs.openSync(dest, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(file.fd, bytes.buffer as ArrayBuffer);
    } finally {
      fs.closeSync(file);
    }
    return fileName;
  }

  static importDemoVoice(context: common.Context, personId: string, baseName: string): string {
    const fileName: string = `voice_${baseName}.m4a`;
    const dest: string = MediaStore.filePath(context, personId, fileName);
    if (fs.accessSync(dest)) {
      return fileName;
    }
    const bytes: Uint8Array = context.resourceManager.getRawFileContentSync(`demo/voices/${baseName}.m4a`);
    const file = fs.openSync(dest, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(file.fd, bytes.buffer as ArrayBuffer);
    } finally {
      fs.closeSync(file);
    }
    return fileName;
  }

  static importDemoBgm(context: common.Context, personId: string): string {
    const fileName: string = 'bgm_demo.m4a';
    const dest: string = MediaStore.filePath(context, personId, fileName);
    if (fs.accessSync(dest)) {
      return fileName;
    }
    const bytes: Uint8Array = context.resourceManager.getRawFileContentSync('demo/bgm_demo.m4a');
    const file = fs.openSync(dest, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(file.fd, bytes.buffer as ArrayBuffer);
    } finally {
      fs.closeSync(file);
    }
    return fileName;
  }

  // MARK: - 用户照片（相册选择 → 压缩 → 沙箱）

  /**
   * 从相册 uri 导入一张照片：长边 ≤ 1600，JPEG q=90。
   * 返回落盘后的文件名（不含目录）。
   */
  static async importUserPhoto(context: common.Context, personId: string, srcUri: string): Promise<string> {
    const fileName: string = `photo_${util.generateRandomUUID()}.jpg`;
    const dest: string = MediaStore.filePath(context, personId, fileName);

    const srcFile = fs.openSync(srcUri, fs.OpenMode.READ_ONLY);
    const source: image.ImageSource = image.createImageSource(srcFile.fd);
    try {
      const info: image.ImageInfo = await source.getImageInfo();
      const longest: number = Math.max(info.size.width, info.size.height);
      const ratio: number = longest > 1600 ? 1600 / longest : 1.0;
      const options: image.DecodingOptions = {
        desiredSize: {
          width: Math.round(info.size.width * ratio),
          height: Math.round(info.size.height * ratio)
        }
      };
      const pixelMap: image.PixelMap = await source.createPixelMap(options);
      const packer: image.ImagePacker = image.createImagePacker();
      const packOptions: image.PackingOption = { format: 'image/jpeg', quality: 90 };
      const destFile = fs.openSync(dest, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      try {
        await packer.packToFile(pixelMap, destFile.fd, packOptions);
      } finally {
        fs.closeSync(destFile);
        await packer.release();
        await pixelMap.release();
      }
    } finally {
      await source.release();
      fs.closeSync(srcFile);
    }
    return fileName;
  }

  // MARK: - 删除

  static deletePersonMedia(context: common.Context, personId: string): void {
    const dir: string = `${context.filesDir}/media/${personId}`;
    if (!fs.accessSync(dir)) {
      return;
    }
    // rmdirSync 不能删非空目录，先逐个删文件
    const names: string[] = fs.listFileSync(dir);
    for (const name of names) {
      fs.unlinkSync(`${dir}/${name}`);
    }
    fs.rmdirSync(dir);
  }

  static deleteFile(context: common.Context, personId: string, fileName: string): void {
    if (fileName.length === 0) {
      return;
    }
    const path: string = MediaStore.filePath(context, personId, fileName);
    if (fs.accessSync(path)) {
      fs.unlinkSync(path);
    }
  }
}
