//
//  AppState.swift
//  EchoesOfTime
//
//  全局状态：语言（按地区自动 + 手动切换）、角色模式（编辑 / 长辈浏览）、大字模式
//

import Foundation
import SwiftUI
import Observation

// MARK: - 语言

enum AppLanguage: String, CaseIterable, Identifiable {
    case en = "en"
    case es = "es"
    case fr = "fr"
    case de = "de"
    case ptBR = "pt-BR"
    case it = "it"
    case nl = "nl"
    case ja = "ja"
    case ko = "ko"
    case zhHans = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zhHans: return "中文"
        case .en: return "English"
        case .es: return "Español"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .ptBR: return "Português (Brasil)"
        case .it: return "Italiano"
        case .nl: return "Nederlands"
        case .ja: return "日本語"
        case .ko: return "한국어"
        }
    }

    /// 根据设备语言自动选择；未匹配到已支持语言时回退英文。
    /// 扩展新语言：在 AppLanguage 里新增 case（BCP-47 代码，如 "fr"、"es"），
    /// 并在 Resources/<code>.lproj/ 下放一份 Localizable.strings 即可，无需改这里。
    static var deviceDefault: AppLanguage {
        for preferred in Locale.preferredLanguages {
            let lower = preferred.lowercased()
            // 精确或前缀匹配已支持语言（en-US → en，zh-Hans-CN → zh-Hans）
            if let match = allCases.first(where: {
                lower == $0.rawValue.lowercased()
                || lower.hasPrefix($0.rawValue.lowercased() + "-")
            }) {
                return match
            }
            // 繁体等中文变体暂时统一使用简体资源
            if lower.hasPrefix("zh") { return .zhHans }
        }
        return .en
    }
}

// MARK: - 模式

enum AppMode: String, CaseIterable, Identifiable {
    /// 子女（建档者）模式：可编辑、可增删
    case editor
    /// 长辈浏览模式：超大字号、只读、操作极简
    case reader

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .editor: return "mode.editor"
        case .reader: return "mode.reader"
        }
    }
}

// MARK: - 全局状态

@Observable
final class AppState {
    var language: AppLanguage {
        didSet { applyLanguage() }
    }
    var mode: AppMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "appMode") }
    }
    var largeText: Bool

    /// 开发者模式：解锁「一人一档」限制（仅开发者本人使用，普通用户不可见入口）
    var isDeveloper: Bool {
        didSet { UserDefaults.standard.set(isDeveloper, forKey: "developerMode") }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: "appLanguage")
        let lang = stored.flatMap(AppLanguage.init(rawValue:)) ?? AppLanguage.deviceDefault
        let storedMode = UserDefaults.standard.string(forKey: "appMode")
        self.language = lang
        self.mode = storedMode.flatMap(AppMode.init(rawValue:)) ?? .editor
        self.largeText = UserDefaults.standard.object(forKey: "largeText") as? Bool ?? true
        #if DEBUG
        // 本地开发/自用：Debug 包直接开启开发者模式，解锁「一人一档」，便于建多个档案测试；Release 不编译此段。
        self.isDeveloper = true
        #else
        self.isDeveloper = UserDefaults.standard.bool(forKey: "developerMode")
        #endif

        Bundle.setLanguage(lang.rawValue)
    }

    func applyLanguage() {
        UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
        Bundle.setLanguage(language.rawValue)
    }

    var isReaderMode: Bool { mode == .reader }
}
