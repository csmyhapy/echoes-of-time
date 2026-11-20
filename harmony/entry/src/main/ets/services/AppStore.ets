import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

/**
 * 全局设置：Editor/Reader 模式、长辈字号、语言、设备锁、付费等级。
 * 持久化到 Preferences，同时写入 AppStorage，页面用 @StorageProp 响应变化。
 */

const PREF_NAME: string = 'echosoftime_settings';

export class AppStore {
  private static pref: preferences.Preferences | undefined = undefined;

  static async init(context: common.Context): Promise<void> {
    if (AppStore.pref === undefined) {
      const options: preferences.Options = { name: PREF_NAME };
      AppStore.pref = await preferences.getPreferences(context, options);
    }
    const pref: preferences.Preferences = AppStore.pref;

    const mode: string = pref.getSync('mode', 'editor') as string;
    const largeText: boolean = pref.getSync('largeText', true) as boolean;
    const language: string = pref.getSync('language', 'system') as string;
    const lockEnabled: boolean = pref.getSync('lockEnabled', false) as boolean;
    const pin: string = pref.getSync('pin', '') as string;
    const tier: string = pref.getSync('tier', 'none') as string;
    const basicOwned: boolean = pref.getSync('basicOwned', false) as boolean;
    const upgradeOwned: boolean = pref.getSync('upgradeOwned', false) as boolean;
    const fullOwned: boolean = pref.getSync('fullOwned', false) as boolean;

    AppStorage.setOrCreate<string>('mode', mode);
    AppStorage.setOrCreate<boolean>('largeText', largeText);
    AppStorage.setOrCreate<string>('language', language);
    AppStorage.setOrCreate<boolean>('lockEnabled', lockEnabled);
    AppStorage.setOrCreate<string>('pin', pin);
    AppStorage.setOrCreate<string>('tier', tier);
    AppStorage.setOrCreate<boolean>('basicOwned', basicOwned);
    AppStorage.setOrCreate<boolean>('upgradeOwned', upgradeOwned);
    AppStorage.setOrCreate<boolean>('fullOwned', fullOwned);
  }

  static async set(key: string, value: preferences.ValueType): Promise<void> {
    if (AppStore.pref === undefined) {
      return;
    }
    AppStore.pref.putSync(key, value);
    await AppStore.pref.flush();
  }

  static async setMode(mode: string): Promise<void> {
    AppStorage.setOrCreate<string>('mode', mode);
    await AppStore.set('mode', mode);
  }

  static async setLargeText(enabled: boolean): Promise<void> {
    AppStorage.setOrCreate<boolean>('largeText', enabled);
    await AppStore.set('largeText', enabled);
  }

  static async setLanguage(language: string): Promise<void> {
    AppStorage.setOrCreate<string>('language', language);
    await AppStore.set('language', language);
  }

  static async setLock(enabled: boolean, pin: string): Promise<void> {
    AppStorage.setOrCreate<boolean>('lockEnabled', enabled);
    AppStorage.setOrCreate<string>('pin', pin);
    await AppStore.set('lockEnabled', enabled);
    await AppStore.set('pin', pin);
  }

  static async setTier(tier: string): Promise<void> {
    AppStorage.setOrCreate<string>('tier', tier);
    await AppStore.set('tier', tier);
  }

  static async setOwned(basic: boolean, upgrade: boolean, full: boolean): Promise<void> {
    AppStorage.setOrCreate<boolean>('basicOwned', basic);
    AppStorage.setOrCreate<boolean>('upgradeOwned', upgrade);
    AppStorage.setOrCreate<boolean>('fullOwned', full);
    const tier: string = (full || (basic && upgrade)) ? 'full' : (basic ? 'basic' : 'none');
    AppStorage.setOrCreate<string>('tier', tier);
    await AppStore.set('basicOwned', basic);
    await AppStore.set('upgradeOwned', upgrade);
    await AppStore.set('fullOwned', full);
    await AppStore.set('tier', tier);
  }
}
