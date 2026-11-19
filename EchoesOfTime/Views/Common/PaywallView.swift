//
//  PaywallView.swift
//  EchoesOfTime
//
//  升级 / 购买弹窗骨架：展示入门版与完整版，调用 PurchaseManager 购买与恢复购买。
//  商品价格由 StoreKit 按地区本地化显示；未在 App Store Connect 配置时按钮安全禁用。
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @State private var pm = PurchaseManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    planCards
                    actions
                    restoreRow
                }
                .padding(20)
            }
            .navigationTitle("paywall.title")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.close") { dismiss() }
                }
            }
            .alert("paywall.error", isPresented: .constant(message != nil)) {
                Button("common.ok") { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
        .task { await pm.loadProducts() }
    }

    // MARK: 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 36))
                .foregroundStyle(.brown)
            Text("paywall.heading")
                .font(.title2.bold())
            Text("paywall.subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: 档位说明

    private var planCards: some View {
        VStack(spacing: 14) {
            planCard(
                title: "paywall.plan.pro.title",
                features: [
                    "paywall.plan.pro.f1",
                    "paywall.plan.pro.f2",
                    "paywall.plan.pro.f3"
                ],
                highlighted: true
            )
            planCard(
                title: "paywall.plan.basic.title",
                features: [
                    "paywall.plan.basic.f1",
                    "paywall.plan.basic.f2",
                    "paywall.plan.basic.f3"
                ],
                highlighted: false
            )
        }
    }

    private func planCard(title: LocalizedStringKey, features: [String], highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(Array(features.enumerated()), id: \.offset) { _, f in
                Label {
                    Text(LocalizedStringKey(f))
                } icon: {
                    Image(systemName: "checkmark")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(highlighted ? Color.brown.opacity(0.08) : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(highlighted ? Color.brown : Color.clear, lineWidth: 1.5)
        )
    }

    // MARK: 购买按钮

    @ViewBuilder
    private var actions: some View {
        switch pm.tier {
        case .pro:
            Label("paywall.pro.unlocked", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.brown)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)

        case .basic:
            // 已购入门版：补差价升级到完整版
            if let p = pm.product(ProductID.upgradeFull) {
                buyButton(title: "paywall.buy.upgrade", price: p.displayPrice) { await buy(p) }
            } else {
                unavailableNote
            }

        case .unpaid:
            VStack(spacing: 12) {
                if let p = pm.product(ProductID.full) {
                    buyButton(title: "paywall.buy.full", price: p.displayPrice, primary: true) { await buy(p) }
                }
                if let p = pm.product(ProductID.basic) {
                    buyButton(title: "paywall.buy.basic", price: p.displayPrice, primary: false) { await buy(p) }
                }
                if pm.products.isEmpty { unavailableNote }
            }
        }
    }

    private func buyButton(title: LocalizedStringKey, price: String, primary: Bool = true, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text(price)
            }
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .padding(.horizontal, 18)
            .background(primary ? Color.brown : Color(.secondarySystemBackground), in: Capsule())
            .foregroundStyle(primary ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .opacity(busy ? 0.6 : 1)
    }

    private var unavailableNote: some View {
        Text("paywall.unavailable")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
    }

    // MARK: 恢复购买

    private var restoreRow: some View {
        HStack {
            Spacer()
            Button("paywall.restore") {
                Task { await pm.restore() }
            }
            .font(.subheadline)
            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: 购买

    private func buy(_ product: Product) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await pm.purchase(product)
        } catch {
            message = error.localizedDescription
        }
    }
}
