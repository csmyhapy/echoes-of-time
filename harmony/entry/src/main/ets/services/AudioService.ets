import { media } from '@kit.MediaKit';
import { fileIo as fs } from '@kit.CoreFileKit';

/**
 * 单实例音频播放器。
 * 用 fdSrc 打开沙箱文件（不依赖 file:// 解析），跨页保持同一实例，BGM 才能连续播。
 */
export class AudioService {
  private static player: media.AVPlayer | undefined = undefined;
  private static file: fs.File | undefined = undefined;
  private static playing: boolean = false;
  private static loopMode: boolean = false;
  private static currentPath: string = '';
  private static paused: boolean = false;
  private static onEnd: () => void = () => {
  };

  static isPlaying(): boolean {
    return AudioService.playing;
  }

  static async play(path: string, loop: boolean = false, onEnd?: () => void): Promise<void> {
    AudioService.loopMode = loop;
    AudioService.onEnd = onEnd !== undefined ? onEnd : () => {
    };
    await AudioService.stop();
    AudioService.currentPath = path;
    AudioService.paused = false;

    const player: media.AVPlayer = await media.createAVPlayer();
    AudioService.player = player;
    player.on('stateChange', (state: string) => {
      if (state === 'initialized') {
        player.prepare();
      } else if (state === 'prepared') {
        player.loop = AudioService.loopMode;
        player.play();
        AudioService.playing = true;
      } else if (state === 'completed') {
        AudioService.playing = false;
        AudioService.onEnd();
      }
    });
    player.on('error', () => {
      AudioService.playing = false;
    });

    const file: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
    AudioService.file = file;
    player.fdSrc = { fd: file.fd };
  }

  static pause(): void {
    if (AudioService.player !== undefined && AudioService.playing) {
      AudioService.player.pause();
      AudioService.playing = false;
      AudioService.paused = true;
    }
  }

  static resume(): void {
    if (AudioService.player !== undefined && !AudioService.playing) {
      AudioService.player.play();
      AudioService.playing = true;
      AudioService.paused = false;
    }
  }

  static async stop(): Promise<void> {
    const player: media.AVPlayer | undefined = AudioService.player;
    AudioService.player = undefined;
    AudioService.playing = false;
    AudioService.paused = false;
    if (player !== undefined) {
      try {
        player.off('stateChange');
        player.off('error');
        await player.release();
      } catch (e) {
        // 释放失败不影响后续播放
      }
    }
    const file: fs.File | undefined = AudioService.file;
    AudioService.file = undefined;
    if (file !== undefined) {
      try {
        fs.closeSync(file);
      } catch (e) {
      }
    }
  }

  /** 播放 / 暂停切换，返回切换后是否在播；换文件时自动切歌 */
  static async toggle(path: string, loop: boolean = false): Promise<boolean> {
    if (AudioService.playing && AudioService.currentPath === path) {
      AudioService.pause();
      return false;
    }
    if (!AudioService.playing && AudioService.paused && AudioService.currentPath === path) {
      AudioService.resume();
      return true;
    }
    await AudioService.play(path, loop);
    return true;
  }
}
