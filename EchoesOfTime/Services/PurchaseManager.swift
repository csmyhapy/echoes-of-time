//
//  PurchaseManager.swift
//  EchoesOfTime
//
//  内购骨架（StoreKit 2，非消耗型产品）。
//  纯本地、无服务器：购买状态由 Apple 校验，本机只缓存档位，重装/换设备走「恢复购买」。
//
//  三个非消耗型商品（ID 需与 App Store Connect 保持一致）：
//   - basic        入门版（$0.99）：基础用户，受门限限制
//   - upgrade_full 升级包（basic 补差价到完整版）
//   - full         完整版买断（$49.9）：付费用户，全部功能
//
//  档位判定：
//   - 已购 full，或（已购 basic 且已购 upgrade_full）→ pro 付费用户
//   - 仅已购 basic → basic 基础用户
//   - 都没买       → unpaid，仅可看内置 demo
//

import Foundation
import StoreKit
import Observation

// MARK: - 付费档位

enum EntitlementTier: Equatable {
    /// 未付费：仅可看内置 demo，不能新建
    case unpaid
    /// 基础用户：已购 basic，受数量/功能门限限制
    case basic
    /// 付费用户：完全功能
    case pro
}

// MARK: - 商品 ID（待 App Store Connect 配置，务必与后台一致）

enum ProductID {
    static let basic = "life.lifememory.echosoftime.basic"
    static let upgradeFull = "life.lifememory.echosoftime.upgrade_full"
    static let full = "life.lifememory.echosoftime.full"
    static let all = [basic, upgradeFull, full]
}

// MARK: - 基础用户门限（集中配置，便于后续调整）

enum EntitlementLimit {
    /// 基础用户最多章节数
    static let basicMaxNodes = 5
    /// 基础用户最多照片数
    static let basicMaxPhotos = 80
    /// 基础用户最多语音旁白数
    static let basicMaxVoiceNotes = 3
    /// 基础用户最多留言数
    static let basicMaxMessages = 3
}

// MARK: - 内购管理

@Observable
@MainActor
final class PurchaseManager {
    static let shared = PurchaseManager()

    /// 当前档位
    private(set) var tier: EntitlementTier = .unpaid
    /// 从 App Store 拉取到的商品（未配置时为空，不影响使用）
    private(set) var products: [Product] = []
    private(set) var isLoading = false

    /// 本机已生效的商品 ID（由 Apple 当前权益计算）
    private var purchasedIDs: Set<String> = []
    private var transactionListener: Task<Void, Never>?

    private init() {
        #if DEBUG
        tier = .pro
        #endif
        transactionListener = listenForTransactions()
        Task { await loadProducts() }
    }

    // MARK: 商品与档位

    /// 拉取商品并刷新已购权益
    func loadProducts() async {
        isLoading = true
        if let fetched = try? await Product.products(for: ProductID.all) {
            products = fetched
        }
        await refreshPurchased()
        isLoading = false
    }

    /// 根据已购商品重新判定档位
    func recomputeTier() {
        #if DEBUG
        // 本地开发/自用：Debug 包直接解锁 pro，便于完整功能试用；Release 不编译此段。
        tier = .pro
        return
        #endif
        if purchasedIDs.contains(ProductID.full)
            || (purchasedIDs.contains(ProductID.basic)
                && purchasedIDs.contains(ProductID.upgradeFull)) {
            tier = .pro
        } else if purchasedIDs.contains(ProductID.basic) {
            tier = .basic
        } else {
            tier = .unpaid
        }
    }

    /// 从 Apple 当前权益刷新已购清单
    func refreshPurchased() async {
        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if let tx = try? result.payloadValue, tx.revocationDate == nil {
                ids.insert(tx.productID)
            }
        }
        purchasedIDs = ids
        recomputeTier()
    }

    // MARK: 购买与恢复

    /// 购买指定商品，返回是否购买成功（用户取消返回 false）
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard let tx = try? verification.payloadValue else { return false }
            await finish(transaction: tx)
            return true
        case .userCancelled:
            return false
        case .pending:
            return false
        @unknown default:
            return false
        }
    }

    /// 恢复购买（向 Apple 校验该 Apple ID 的历史购买）
    func restore() async {
        try? await AppStore.sync()
        await refreshPurchased()
    }

    private func finish(transaction: Transaction) async {
        await transaction.finish()
        await refreshPurchased()
    }

    /// 持续监听后台交易更新（购买完成、续订、撤销等）
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            guard let self else { return }
            for await result in Transaction.updates {
                guard let tx = try? result.payloadValue else { continue }
                await self.finish(transaction: tx)
            }
        }
    }

    // MARK: 便捷取商品

    func product(_ id: String) -> Product? {
        products.first { $0.id == id }
    }
}

// MARK: - 功能门限判定

extension PurchaseManager {
    var isPro: Bool { tier == .pro }
    var isBasic: Bool { tier == .basic }
    var isUnpaid: Bool { tier == .unpaid }

    /// 是否还能新增章节（pro 不限；basic 限 5；unpaid 不能新建）
    func canAddNode(currentCount: Int) -> Bool {
        isPro || (isBasic && currentCount < EntitlementLimit.basicMaxNodes)
    }

    /// 是否还能新增照片（pro 不限；basic 限 80；unpaid 不能新建）
    func canAddPhoto(currentCount: Int) -> Bool {
        isPro || (isBasic && currentCount < EntitlementLimit.basicMaxPhotos)
    }

    /// 是否还能新增语音旁白（pro 不限；basic 限 3；unpaid 不能新建）
    func canAddVoice(currentCount: Int) -> Bool {
        isPro || (isBasic && currentCount < EntitlementLimit.basicMaxVoiceNotes)
    }

    /// 是否还能新增留言（pro 不限；basic 限 3；unpaid 不能新建）
    func canAddMessage(currentCount: Int) -> Bool {
        isPro || (isBasic && currentCount < EntitlementLimit.basicMaxMessages)
    }

    /// 分享：仅 pro
    var canShare: Bool { isPro }
    /// 导出（PDF/档案包）：仅 pro
    var canExport: Bool { isPro }
}
