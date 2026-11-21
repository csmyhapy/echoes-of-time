/**
 * 付费等级与配额。
 * 与 iOS PurchaseManager 同一套规则：
 *   full 已购 → 全开
 *   basic + upgrade_full → 全开
 *   仅 basic → 5 章节 / 80 照片 / 3 语音 / 3 留言，导出受限
 *   未付费 → 只能看 demo
 */

export class Entitlements {
  static tier(): string {
    const tier: string = AppStorage.get<string>('tier') ?? 'none';
    return tier;
  }

  static isFull(): boolean {
    return Entitlements.tier() === 'full';
  }

  static isBasic(): boolean {
    return Entitlements.tier() === 'basic';
  }

  static isPaid(): boolean {
    return Entitlements.tier() !== 'none';
  }

  static maxNodes(): number {
    if (Entitlements.isFull()) {
      return 999;
    }
    return Entitlements.isBasic() ? 5 : 0;
  }

  static maxPhotos(): number {
    if (Entitlements.isFull()) {
      return 9999;
    }
    return Entitlements.isBasic() ? 80 : 0;
  }

  static maxVoices(): number {
    if (Entitlements.isFull()) {
      return 999;
    }
    return Entitlements.isBasic() ? 3 : 0;
  }

  static maxMessages(): number {
    if (Entitlements.isFull()) {
      return 999;
    }
    return Entitlements.isBasic() ? 3 : 0;
  }

  static canExport(): boolean {
    return Entitlements.isFull();
  }

  static canCreatePerson(): boolean {
    return Entitlements.isPaid();
  }

  /** 超额时的提示语 */
  static limitHint(kind: string, max: number): string {
    if (max === 0) {
      return `新增${kind}需要先解锁，点「解锁全部功能」查看版本`;
    }
    return `当前版本最多 ${max} ${kind}，升级完整版后不限量`;
  }
}
