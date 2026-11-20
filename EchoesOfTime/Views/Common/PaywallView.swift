//
//  PaywallView.swift
//  EchoesOfTime
//
//  升级 / 购买弹窗：展示入门版与完整版，调用 PurchaseManager 购买与恢复购买。
//  商品价格由 StoreKit 按地区本地化显示；未在 App Store Connect 配置时按钮安全禁用。
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @State private var pm = PurchaseManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var busy = false
    @State private var message: String?

    private let brown = Color(red: 0.42, green: 0.29, blue: 0.16)

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
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 26))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(brown, in: Circle())
            Text("paywall.heading")
                .font(.title2.bold())
            Text("paywall.subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: 档位说明

    private var planCards: some View {
        VStack(spacing: 14) {
            planCard(
                title: "paywall.plan.pro.title",
                badge: "paywall.plan.pro.badge",
                features: [
                    "paywall.plan.pro.f1",
                    "paywall.plan.pro.f2",
                    "paywall.plan.pro.f3"
                ],
                highlighted: true
            )
            planCard(
                title: "paywall.plan.basic.title",
                badge: nil,
                features: [
                    "paywall.plan.basic.f1",
                    "paywall.plan.basic.f2",
                    "paywall.plan.basic.f3"
                ],
                highlighted: false
            )
        }
    }

    private func planCard(title: LocalizedStringKey, badge: LocalizedStringKey?,
                          features: [String], highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.headline)
                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(brown, in: Capsule())
                }
                Spacer()
            }
            ForEach(Array(features.enumerated()), id: \.offset) { _, f in
                Label {
                    Text(LocalizedStringKey(f))
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(highlighted ? brown : .secondary)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(highlighted ? brown.opacity(0.08) : Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(highlighted ? brown : Color.clear, lineWidth: 1.5)
        )
    }

    // MARK: 购买按钮

    @ViewBuilder
    private var actions: some View {
        switch pm.tier {
        case .pro:
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(brown)
                Text("paywall.pro.unlocked")
                    .font(.headline)
                    .foregroundStyle(brown)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(brown.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

        case .basic:
            // 已购入门版：补差价升级到完整版
            if let p = pm.product(ProductID.upgradeFull) {
                buyButton(title: "paywall.buy.upgrade", price: p.displayPrice, primary: true) { await buy(p) }
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

    private func buyButton(title: LocalizedStringKey, price: String, primary: Bool,
                           action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            HStack {
                if busy {
                    ProgressView()
                        .tint(primary ? .white : brown)
                } else {
                    Text(title)
                }
                Spacer()
                Text(price)
                    .font(.system(size: 17, weight: .bold))
            }
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .padding(.horizontal, 18)
            .background(primary ? brown : Color(.secondarySystemBackground), in: Capsule())
            .foregroundStyle(primary ? Color.white : Color.primary)
            .overlay(
                Capsule().strokeBorder(primary ? Color.clear : brown.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .opacity(busy ? 0.7 : 1)
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
