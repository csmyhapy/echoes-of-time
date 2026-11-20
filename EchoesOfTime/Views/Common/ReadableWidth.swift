//
//  ReadableWidth.swift
//  EchoesOfTime
//
//  宽屏（iPad）适配：把单列内容限制在舒适阅读宽度并水平居中，
//  避免在大屏上被全宽拉伸成超长条、正文行过长。
//  iPhone 宽度小于上限，修饰不产生视觉变化。
//

import SwiftUI

extension View {
    /// 将内容限制在 `maxWidth` 内并水平居中。
    /// 先把内容限宽，再用一个撑满宽度的容器把它居中。
    func readableCentered(maxWidth: CGFloat = 680) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}
