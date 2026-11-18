//
//  Localization.swift
//  EchoesOfTime
//
//  运行中切换语言的实现：通过替换 Bundle.main 的 localizedString 行为，
//  使 SwiftUI 的 Text("key") 和 String(localized:) 在切换后立即生效。
//

import Foundation
import ObjectiveC

private var languageBundleKey: UInt8 = 0

final class LanguageBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let path = objc_getAssociatedObject(self, &languageBundleKey) as? String,
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    /// 切换 App 语言，例如 "en" / "zh-Hans"
    static func setLanguage(_ language: String) {
        guard Bundle.main.path(forResource: language, ofType: "lproj") != nil else { return }
        object_setClass(Bundle.main, LanguageBundle.self)
        let path = Bundle.main.path(forResource: language, ofType: "lproj")
        objc_setAssociatedObject(Bundle.main, &languageBundleKey, path, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
