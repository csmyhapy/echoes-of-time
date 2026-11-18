//
//  PrivacyLock.swift
//  EchoesOfTime
//
//  Face ID / 设备密码 隐私锁。
//  开启后 App 冷启动或从后台返回时要求验证；未设置密码的设备直接放行，避免把用户锁在门外。
//

import SwiftUI
import Foundation
import LocalAuthentication
import Observation

@Observable
final class PrivacyLock {

    var isLocked = false
    var errorMessage: String?
    private var lastUnlockAt: Date?

    var enabled: Bool {
        UserDefaults.standard.bool(forKey: "requireFaceID")
    }

    func lockIfNeeded() {
        guard enabled else {
            isLocked = false
            return
        }
        // 30 秒内刚解锁过就不重复弹窗（避免回前台频繁验证）
        if let last = lastUnlockAt, Date().timeIntervalSince(last) < 30 {
            return
        }
        isLocked = true
        authenticate()
    }

    func authenticate() {
        let context = LAContext()
        context.localizedCancelTitle = String(localized: "lock.cancel")

        var authError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
            // 设备没有设置面容/密码：不锁，直接进入
            errorMessage = nil
            isLocked = false
            lastUnlockAt = Date()
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: String(localized: "lock.reason")
        ) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if success {
                    self.isLocked = false
                    self.errorMessage = nil
                    self.lastUnlockAt = Date()
                } else {
                    self.isLocked = true
                    self.errorMessage = error?.localizedDescription
                }
            }
        }
    }
}

// MARK: - 锁屏界面

struct LockScreenView: View {
    let lock: PrivacyLock

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 22) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.brown)

                Text("lock.title")
                    .font(.title3.weight(.semibold))

                Button {
                    lock.authenticate()
                } label: {
                    Label("lock.unlock", systemImage: "faceid")
                        .frame(maxWidth: 220)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brown)

                if let err = lock.errorMessage {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
        }
    }
}
