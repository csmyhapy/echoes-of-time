import { common } from '@kit.AbilityKit';
import { iap } from '@kit.IAPKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { AppStore } from './AppStore';

/**
 * 华为应用市场 IAP：三档非消耗型商品。
 * 商品 ID 必须与 AppGallery Connect 中配置一致，否则 queryProducts 返回空。
 * 单机应用没有服务器，权益在客户端发放：解码 JWS payload → 置位 → finishPurchase。
 */

export const PRODUCT_BASIC: string = 'basic';
export const PRODUCT_UPGRADE: string = 'upgrade_full';
export const PRODUCT_FULL: string = 'full';

interface PurchaseDataJson {
  jwsPurchaseOrder: string;
}

interface PurchaseOrderPayload {
  productId: string;
  productType: string;
  purchaseToken: string;
  purchaseOrderId: string;
  purchaseOrderRevocationReasonCode: string;
  finishStatus: string;
}

export type PurchaseOutcome = 'ok' | 'cancelled' | 'owned' | 'failed';

export class IapService {
  /** 上次 queryEnvironmentStatus 是否可用；false 时界面隐藏购买入口 */
  static environmentOk: boolean = true;

  static async checkEnvironment(context: common.UIAbilityContext): Promise<boolean> {
    try {
      await iap.queryEnvironmentStatus(context);
      IapService.environmentOk = true;
    } catch (err) {
      IapService.environmentOk = false;
    }
    return IapService.environmentOk;
  }

  static async queryProducts(context: common.UIAbilityContext): Promise<void> {
    const param: iap.QueryProductsParameter = {
      productType: iap.ProductType.NONCONSUMABLE,
      productIds: [PRODUCT_BASIC, PRODUCT_UPGRADE, PRODUCT_FULL]
    };
    try {
      await iap.queryProducts(context, param);
    } catch (err) {
      // 商品未配置 / 环境不可用时静默，价格以收银台为准
    }
  }

  static async purchase(context: common.UIAbilityContext, productId: string): Promise<PurchaseOutcome> {
    const param: iap.PurchaseParameter = {
      productType: iap.ProductType.NONCONSUMABLE,
      productId: productId
    };
    try {
      const result: iap.CreatePurchaseResult = await iap.createPurchase(context, param);
      const payload: PurchaseOrderPayload | undefined = IapService.decodePurchaseData(result.purchaseData);
      if (payload === undefined) {
        return 'failed';
      }
      if (payload.purchaseOrderRevocationReasonCode !== undefined &&
        payload.purchaseOrderRevocationReasonCode.length > 0) {
        return 'failed';
      }
      await IapService.grant(payload.productId);
      await IapService.finish(context, payload);
      return 'ok';
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      if (error.code === iap.IAPErrorCode.PRODUCT_OWNED) {
        await IapService.restore(context);
        return 'owned';
      }
      return 'failed';
    }
  }

  /** 启动 / 恢复购买：查已持有权益，逐个补发货 */
  static async restore(context: common.UIAbilityContext): Promise<boolean> {
    const param: iap.QueryPurchasesParameter = {
      productType: iap.ProductType.NONCONSUMABLE,
      queryType: iap.PurchaseQueryType.CURRENT_ENTITLEMENT
    };
    let ownedAny: boolean = false;
    try {
      const result: iap.QueryPurchaseResult = await iap.queryPurchases(context, param);
      const list: string[] = result.purchaseDataList;
      if (list === undefined || list.length === 0) {
        return false;
      }
      for (const data of list) {
        const payload: PurchaseOrderPayload | undefined = IapService.decodePurchaseData(data);
        if (payload === undefined) {
          continue;
        }
        await IapService.grant(payload.productId);
        await IapService.finish(context, payload);
        ownedAny = true;
      }
    } catch (err) {
      return false;
    }
    return ownedAny;
  }

  private static async finish(context: common.UIAbilityContext, payload: PurchaseOrderPayload): Promise<void> {
    const param: iap.FinishPurchaseParameter = {
      productType: Number(payload.productType),
      purchaseToken: payload.purchaseToken,
      purchaseOrderId: payload.purchaseOrderId
    };
    try {
      await iap.finishPurchase(context, param);
    } catch (err) {
      // 发货已完成，finish 失败下次启动会由 restore 补齐
    }
  }

  /** 置位本地权益：basic / upgrade_full / full 三者可叠加 */
  private static async grant(productId: string): Promise<void> {
    const basic: boolean = AppStorage.get<boolean>('basicOwned') === true;
    const upgrade: boolean = AppStorage.get<boolean>('upgradeOwned') === true;
    const full: boolean = AppStorage.get<boolean>('fullOwned') === true;
    if (productId === PRODUCT_BASIC) {
      await AppStore.setOwned(true, upgrade, full);
    } else if (productId === PRODUCT_UPGRADE) {
      await AppStore.setOwned(basic, true, full);
    } else if (productId === PRODUCT_FULL) {
      await AppStore.setOwned(basic, upgrade, true);
    }
  }

  private static decodePurchaseData(purchaseData: string): PurchaseOrderPayload | undefined {
    try {
      const data: PurchaseDataJson = JSON.parse(purchaseData) as PurchaseDataJson;
      const jws: string = data.jwsPurchaseOrder;
      if (jws === undefined || jws.length === 0) {
        return undefined;
      }
      const parts: string[] = jws.split('.');
      if (parts.length < 2) {
        return undefined;
      }
      const payloadText: string = IapService.base64UrlDecode(parts[1]);
      const payload: PurchaseOrderPayload = JSON.parse(payloadText) as PurchaseOrderPayload;
      return payload;
    } catch (err) {
      return undefined;
    }
  }

  private static base64UrlDecode(input: string): string {
    let standard: string = input.replace(/-/g, '+').replace(/_/g, '/');
    while (standard.length % 4 !== 0) {
      standard += '=';
    }
    const helper: util.Base64Helper = new util.Base64Helper();
    const bytes: Uint8Array = helper.decodeSync(standard);
    const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(bytes);
  }
}
