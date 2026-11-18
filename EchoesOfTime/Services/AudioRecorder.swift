//
//  AudioRecorder.swift
//  EchoesOfTime
//
//  本地录音服务：AVAudioRecorder 输出 m4a(AAC)，用于照片旁白 / 章节旁白 / 人物旁白。
//  录音文件写入 App 沙盒 Media/<personID>/voice_xxxx.m4a。
//

import Foundation
import AVFoundation
import Observation

@Observable
final class AudioRecorder {

    private var recorder: AVAudioRecorder?

    var isRecording = false
    var startDate: Date?
    var errorMessage: String?

    /// 本次录音产物
    private(set) var lastFileName: String?
    private(set) var lastDuration: Double = 0

    /// 已录时长（秒），供界面计时显示
    var elapsed: TimeInterval {
        guard let startDate, isRecording else { return lastDuration }
        return Date().timeIntervalSince(startDate)
    }

    // MARK: - 权限

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - 录制

    @discardableResult
    func start(personID: UUID) async -> Bool {
        guard !isRecording else { return true }
        guard await requestPermission() else {
            errorMessage = String(localized: "recorder.permission.denied")
            return false
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let fileName = "voice_\(UUID().uuidString).m4a"
            let url = MediaStore.url(fileName: fileName, personID: personID)
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let r = try AVAudioRecorder(url: url, settings: settings)
            r.prepareToRecord()
            r.record()

            recorder = r
            lastFileName = fileName
            lastDuration = 0
            startDate = Date()
            isRecording = true
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func stop() {
        guard let r = recorder else { return }
        lastDuration = r.currentTime
        r.stop()
        recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// 取消并删除已录文件
    func cancel(personID: UUID) {
        if isRecording { stop() }
        if let name = lastFileName {
            MediaStore.deleteFile(fileName: name, personID: personID)
        }
        lastFileName = nil
        lastDuration = 0
        startDate = nil
    }
}
