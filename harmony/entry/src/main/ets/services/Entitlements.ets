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

  /** 免费体验：1 章；入门版 5 章；完整版不限 */
  static maxNodes(): number {
    if (Entitlements.isFull()) {
      return 999;
    }
    return Entitlements.isBasic() ? 5 : 1;
  }

  static maxPhotos(): number {
    if (Entitlements.isFull()) {
      return 9999;
    }
    return Entitlements.isBasic() ? 80 : 10;
  }

  static maxVoices(): number {
    if (Entitlements.isFull()) {
      return 999;
    }
    return Entitlements.isBasic() ? 3 : 1;
  }

  static maxMessages(): number {
    if (Entitlements.isFull()) {
      return 999;
    }
    return Entitlements.isBasic() ? 3 : 1;
  }

  static canExport(): boolean {
    return Entitlements.isFull();
  }

  /**
   * 一人一档：正式版普通用户只能建 1 个非示例档案（示例 demo 不计数）。
   * 免费用户也能建自己的第一档，但内容额度受限（1 章/10 图/1 旁白/1 留言）。
   * 自用调试包若要建多档，把 maxPersons 临时调大即可（正式版不暴露开发者入口）。
   */
  static maxPersons(): number {
    return 1;
  }

  static canCreateAnother(nonDemoCount: number): boolean {
    return nonDemoCount < Entitlements.maxPersons();
  }

  static canCreatePerson(): boolean {
    return true;
  }

  /** 超额时的提示语 */
  static limitHint(kind: string, max: number): string {
    if (max === 0) {
      return `新增${kind}需要先解锁，点「解锁全部功能」查看版本`;
    }
    return `当前版本最多 ${max} ${kind}，升级完整版后不限量`;
  }
}
