//
//  AudioPlayer.swift
//  EchoesOfTime
//
//  本地音频播放服务：播放 / 暂停 / 停止 App 沙盒内的旁白音频。
//  只负责播放，不负责录制；录音在 P3（AudioRecorder）。
//

import Foundation
import AVFoundation
import Observation

@Observable
final class AudioPlayer {

    private var player: AVAudioPlayer?
    private var sessionConfigured = false

    /// 当前音频的完整文件 URL（用于判断是否同一条目）
    var currentURL: URL?
    /// 当前音频总时长（秒）
    var duration: Double = 0

    /// 实时是否在播放（配合 TimelineView 刷新 UI）
    var isPlayingNow: Bool { player?.isPlaying ?? false }
    /// 实时播放位置
    var currentTime: Double { player?.currentTime ?? 0 }
    /// 播放进度 0…1
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, currentTime / duration))
    }

    /// 同一首则切换播放/暂停；不同则从头播放
    func toggle(url: URL) {
        if currentURL == url, let existing = player {
            if existing.isPlaying {
                existing.pause()
            } else {
                existing.play()
            }
            return
        }
        play(url: url)
    }

    func play(url: URL) {
        stop()
        do {
            if !sessionConfigured {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .spokenAudio)
                try session.setActive(true)
                sessionConfigured = true
            }
            let p = try AVAudioPlayer(contentsOf: url)
            p.prepareToPlay()
            p.play()
            player = p
            currentURL = url
            duration = p.duration
        } catch {
            player = nil
            currentURL = nil
            duration = 0
        }
    }

    func stop() {
        player?.stop()
        player = nil
        currentURL = nil
        duration = 0
    }
}
