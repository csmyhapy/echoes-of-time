//
//  BGMManager.swift
//  EchoesOfTime
//
//  背景音乐：进入人物页循环播放，离开页面停止。
//  音乐优先取本地媒体目录（用户自定义），否则回落到 App 包内的示例 BGM。
//

import Foundation
import AVFoundation
import Observation

@Observable
@MainActor
final class BGMManager {

    static let shared = BGMManager()

    private var player: AVAudioPlayer?
    private var currentKey: String?

    var isPlaying: Bool { player?.isPlaying ?? false }

    /// 背景音乐音量（0.18 的 60%，约为原始 0.30 的 36%，只作氛围不打扰）
    static let defaultVolume: Float = 0.108

    var isEnabled: Bool {
        (UserDefaults.standard.object(forKey: "bgmEnabled") as? Bool) ?? true
    }

    func play(fileName: String?, personID: UUID) {
        guard isEnabled else { stop(); return }
        guard let fileName, !fileName.isEmpty else { stop(); return }

        let key = "\(personID.uuidString)/\(fileName)"
        if currentKey == key, player?.isPlaying == true { return }
        stop()
        activateSession()

        guard let url = resolveURL(fileName: fileName, personID: personID) else { return }
        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.numberOfLoops = -1      // 循环
            newPlayer.volume = Self.defaultVolume   // 0.108（0.18 的 60%）
            newPlayer.prepareToPlay()
            newPlayer.play()
            player = newPlayer
            currentKey = key
        } catch {
            player = nil
            currentKey = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
        currentKey = nil
    }

    /// 配置并激活音频会话，确保真机（含静音键、与语音会话切换后）能稳定出声
    private func activateSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // 会话激活失败仍继续尝试播放，不阻断
        }
    }

    private func resolveURL(fileName: String, personID: UUID) -> URL? {
        let mediaURL = MediaStore.url(fileName: fileName, personID: personID)
        if FileManager.default.fileExists(atPath: mediaURL.path) { return mediaURL }

        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        let fileExt = ext.isEmpty ? "m4a" : ext
        return Bundle.main.url(forResource: base, withExtension: fileExt)
            ?? Bundle.main.url(forResource: base, withExtension: fileExt, subdirectory: "BGM")
    }
}
