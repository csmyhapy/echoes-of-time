//
//  RecorderSheet.swift
//  EchoesOfTime
//
//  通用录音面板：大按钮录制、计时、停止、保存 / 取消。
//  同一文件里附一个可复用的旁白播放按钮。
//

import SwiftUI
import AVFoundation

struct RecorderSheet: View {
    let personID: UUID
    let titleKey: String
    /// 保存回调：文件名、时长（秒）
    let onSave: (String, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var recorder = AudioRecorder()

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Text(LocalizedStringKey(titleKey))
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Button {
                    if recorder.isRecording {
                        recorder.stop()
                    } else {
                        Task { await recorder.start(personID: personID) }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(recorder.isRecording ? Color.red : Color.brown)
                            .frame(width: 130, height: 130)
                        Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)

                if recorder.isRecording {
                    TimelineView(.periodic(from: .now, by: 0.3)) { _ in
                        Text(timeText(recorder.elapsed))
                            .font(.system(size: 30, weight: .semibold, design: .monospaced))
                    }
                    Text("recorder.hint")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if recorder.lastDuration > 0 {
                    Text("\(Int(recorder.lastDuration))s")
                        .font(.system(size: 22, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                if let err = recorder.errorMessage {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle("recorder.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        recorder.cancel(personID: personID)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        if recorder.isRecording { recorder.stop() }
                        if let name = recorder.lastFileName, recorder.lastDuration > 0 {
                            onSave(name, Int(recorder.lastDuration))
                        }
                        dismiss()
                    }
                    .disabled(recorder.lastFileName == nil || recorder.lastDuration <= 0)
                }
            }
        }
        .onDisappear {
            if recorder.isRecording { recorder.stop() }
        }
    }

    private func timeText(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

// MARK: - 旁白播放按钮（章节级 / 人物级复用）

struct VoiceNotePlayButton: View {
    let fileName: String
    let personID: UUID

    @State private var player = AudioPlayer()
    @State private var total: Double = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { _ in
            HStack(spacing: 10) {
                Button {
                    player.toggle(url: MediaStore.url(fileName: fileName, personID: personID))
                } label: {
                    Label(
                        player.isPlayingNow ? "photo.narration.pause" : "voice.play",
                        systemImage: player.isPlayingNow ? "pause.circle.fill" : "play.circle.fill"
                    )
                }
                .buttonStyle(.borderless)

                Text(timeText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .onAppear {
            total = AudioPlayer.duration(of: MediaStore.url(fileName: fileName, personID: personID))
        }
        .onDisappear { player.stop() }
    }

    private var timeText: String {
        guard total > 0 else { return "" }
        if player.isPlayingNow {
            return "\(AudioPlayer.timeText(player.currentTime)) / \(AudioPlayer.timeText(total))"
        }
        return AudioPlayer.timeText(total)
    }
}
