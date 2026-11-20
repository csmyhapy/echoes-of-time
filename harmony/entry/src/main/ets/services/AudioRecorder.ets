import { media } from '@kit.MediaKit';
import { fileIo as fs } from '@kit.CoreFileKit';

/**
 * 录音：AAC / m4a 单声道 48k。
 * 录到沙箱后再交给业务层入库，避免录音中断产生半截文件污染数据库。
 */
export class AudioRecorder {
  private static recorder: media.AVRecorder | undefined = undefined;
  private static file: fs.File | undefined = undefined;
  private static recording: boolean = false;

  static isRecording(): boolean {
    return AudioRecorder.recording;
  }

  static async start(outPath: string): Promise<void> {
    if (AudioRecorder.recording) {
      return;
    }
    const recorder: media.AVRecorder = await media.createAVRecorder();
    AudioRecorder.recorder = recorder;

    const file: fs.File = fs.openSync(outPath,
      fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
    AudioRecorder.file = file;

    const config: media.AVRecorderConfig = {
      audioSourceType: media.AudioSourceType.AUDIO_SOURCE_TYPE_MIC,
      profile: {
        audioBitrate: 96000,
        audioChannels: 1,
        audioCodec: media.CodecMimeType.AUDIO_AAC,
        audioSampleRate: 48000,
        fileFormat: media.ContainerFormatType.CFT_MPEG_4A
      },
      url: `fd://${file.fd}`
    };
    await recorder.prepare(config);
    await recorder.start();
    AudioRecorder.recording = true;
  }

  static async stop(): Promise<void> {
    const recorder: media.AVRecorder | undefined = AudioRecorder.recorder;
    AudioRecorder.recorder = undefined;
    if (recorder !== undefined) {
      try {
        await recorder.stop();
      } catch (e) {
        // 太短（<1s）时 stop 会抛错，按正常结束处理
      }
      try {
        await recorder.release();
      } catch (e) {
      }
    }
    const file: fs.File | undefined = AudioRecorder.file;
    AudioRecorder.file = undefined;
    if (file !== undefined) {
      try {
        fs.closeSync(file);
      } catch (e) {
      }
    }
    AudioRecorder.recording = false;
  }
}
