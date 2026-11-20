//
//  FaqView.swift
//  EchoesOfTime
//
//  常见问题问答：折叠列表，从设置页进入
//

import SwiftUI

struct FaqItem {
    let q: LocalizedStringKey
    let a: LocalizedStringKey
}

struct FaqView: View {

    private let items: [FaqItem] = [
        FaqItem(q: "faq.q1", a: "faq.a1"),
        FaqItem(q: "faq.q2", a: "faq.a2"),
        FaqItem(q: "faq.q3", a: "faq.a3"),
        FaqItem(q: "faq.q4", a: "faq.a4"),
        FaqItem(q: "faq.q5", a: "faq.a5"),
        FaqItem(q: "faq.q6", a: "faq.a6"),
        FaqItem(q: "faq.q7", a: "faq.a7"),
        FaqItem(q: "faq.q8", a: "faq.a8")
    ]

    var body: some View {
        List {
            ForEach(items.indices, id: \.self) { i in
                DisclosureGroup {
                    Text(items[i].a)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 6)
                } label: {
                    Text(items[i].q)
                        .font(.system(size: 16, weight: .medium))
                }
            }
        }
        .navigationTitle("faq.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}
