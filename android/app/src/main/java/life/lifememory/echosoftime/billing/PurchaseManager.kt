package life.lifememory.echosoftime.billing

import android.content.Context
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import life.lifememory.echosoftime.BuildConfig

/** 付费档位（与 iOS EntitlementTier 一致） */
enum class EntitlementTier { UNPAID, BASIC, PRO }

object ProductID {
    const val BASIC = "life.lifememory.echosoftime.basic"
    const val UPGRADE_FULL = "life.lifememory.echosoftime.upgrade_full"
    const val FULL = "life.lifememory.echosoftime.full"
    val all = listOf(BASIC, UPGRADE_FULL, FULL)
}

/** 基础用户门限（集中配置，便于后续调整），与 iOS EntitlementLimit 一致 */
object EntitlementLimit {
    const val BASIC_MAX_NODES = 5
    const val BASIC_MAX_PHOTOS = 80
    const val BASIC_MAX_VOICES = 3
    const val BASIC_MAX_MESSAGES = 3
}

/**
 * Google Play 内购（非消耗型）。纯本地、无服务器：购买状态由 Play 校验，
 * 本机只缓存档位，重装/换设备走「恢复购买」。与 iOS PurchaseManager 对应。
 */
class PurchaseManager(context: Context) {

    private val appContext = context.applicationContext

    private val _tier = MutableStateFlow(
        if (BuildConfig.FORCE_PRO) EntitlementTier.PRO else EntitlementTier.UNPAID,
    )
    val tier: StateFlow<EntitlementTier> = _tier

    private val purchased = mutableSetOf<String>()
    private var productDetails: List<ProductDetails> = emptyList()
    private var billing: BillingClient? = null

    fun start() {
        if (BuildConfig.FORCE_PRO) return
        billing = BillingClient.newBuilder(appContext)
            .setListener { _, _ -> refreshPurchases() }
            .build()
        billing?.startConnection(object : com.android.billingclient.api.BillingClientStateListener {
            override fun onBillingSetupFinished(
                billingResult: com.android.billingclient.api.BillingResult,
            ) {
                if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    queryProducts()
                    refreshPurchases()
                }
            }

            override fun onBillingServiceDisconnected() {}
        })
    }

    fun productDetails(id: String): ProductDetails? = productDetails.firstOrNull { it.productId == id }

    private fun queryProducts() {
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(
                ProductID.all.map {
                    QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(it)
                        .build()
                },
            )
            .build()
        billing?.queryProductDetailsAsync(params) { res, details ->
            if (res.responseCode == BillingClient.BillingResponseCode.OK) {
                productDetails = details
            }
        }
    }

    /** 购买指定商品；返回是否成功拉起（用户取消返回 false） */
    fun purchase(activity: android.app.Activity, productId: String): Boolean {
        val detail = productDetails(productId) ?: return false
        val params = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(
                listOf(
                    BillingFlowParams.ProductDetailsParams.newBuilder()
                        .setProductDetails(detail)
                        .build(),
                ),
            )
            .build()
        val res = billing?.launchBillingFlow(activity, params)
        return res?.responseCode == BillingClient.BillingResponseCode.OK
    }

    fun refreshPurchases() {
        if (BuildConfig.FORCE_PRO) {
            recompute(); return
        }
        val params = QueryPurchasesParams.newBuilder().build()
        billing?.queryPurchasesAsync(params) { _, purchases ->
            purchased.clear()
            for (p in purchases) {
                if (p.purchaseState == Purchase.PurchaseState.PURCHASED) {
                    if (p.isAcknowledged) {
                        purchased += p.products.first()
                    } else {
                        acknowledge(p)
                    }
                }
            }
            recompute()
        }
    }

    private fun acknowledge(purchase: Purchase) {
        val params = AcknowledgePurchaseParams.newBuilder()
            .setPurchaseToken(purchase.purchaseToken)
            .build()
        billing?.acknowledgePurchase(params) { _ -> refreshPurchases() }
    }

    /** 恢复购买（向 Play 校验该账号的历史购买） */
    fun restore() = refreshPurchases()

    private fun recompute() {
        if (BuildConfig.FORCE_PRO) {
            _tier.value = EntitlementTier.PRO
            return
        }
        _tier.value = when {
            purchased.contains(ProductID.FULL) ||
                (purchased.contains(ProductID.BASIC) && purchased.contains(ProductID.UPGRADE_FULL)) ->
                EntitlementTier.PRO
            purchased.contains(ProductID.BASIC) -> EntitlementTier.BASIC
            else -> EntitlementTier.UNPAID
        }
    }

    // MARK: 档位便捷属性与门限

    val isPro: Boolean get() = _tier.value == EntitlementTier.PRO
    val isBasic: Boolean get() = _tier.value == EntitlementTier.BASIC
    val isUnpaid: Boolean get() = _tier.value == EntitlementTier.UNPAID

    fun canAddNode(currentCount: Int): Boolean =
        isPro || (isBasic && currentCount < EntitlementLimit.BASIC_MAX_NODES)

    fun canAddPhoto(currentCount: Int): Boolean =
        isPro || (isBasic && currentCount < EntitlementLimit.BASIC_MAX_PHOTOS)

    fun canAddVoice(currentCount: Int): Boolean =
        isPro || (isBasic && currentCount < EntitlementLimit.BASIC_MAX_VOICES)

    fun canAddMessage(currentCount: Int): Boolean =
        isPro || (isBasic && currentCount < EntitlementLimit.BASIC_MAX_MESSAGES)

    /** 分享：仅 pro */
    val canShare: Boolean get() = isPro

    /** 导出（PDF/档案包）：仅 pro */
    val canExport: Boolean get() = isPro
}
