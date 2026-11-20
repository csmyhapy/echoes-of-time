# App Store Connect 内购商品配置清单

> 用途：代码侧 PurchaseManager 已就绪（StoreKit 2、三非消耗型商品、档位判定、恢复购买），
> 本文档照单在 App Store Connect 后台逐项填写。商品未配置前，App 内购买按钮安全禁用，不影响使用。
> 代码 ProductID 见 `EchoesOfTime/Services/PurchaseManager.swift` 的 `enum ProductID`，**必须与后台完全一致**。

## 一、三个商品总览（均为「非消耗型 / Non-Consumable」）

| ProductID（后台填写，全小写） | 参考名称 | 美国价 | 说明 |
| --- | --- | --- | --- |
| `life.lifememory.echosoftime.basic` | 入门版 Starter | $0.99 | 新用户起步：5 章节 / 80 照片 / 语音 3 段 / 留言 3 条；分享导出受限 |
| `life.lifememory.echosoftime.upgrade_full` | 升级到完整版 Upgrade | 当地 full − 当地 basic | 仅已买 basic 者补差价，买后变完整版 |
| `life.lifememory.echosoftime.full` | 完整版买断 Full Version (Lifetime) | $49.9 | 一步到位，全部功能不限量 |

价格闭环：`basic + upgrade_full = full`，任何路径总价相同。
**不做虚高原价**，$49.9 直接定价，未来促销靠限时改价。

## 二、逐个商品元数据

### 1) basic 入门版
- **Product ID**：`life.lifememory.echosoftime.basic`
- **类型**：非消耗型（Non-Consumable）
- **参考名称（Reference Name，仅后台可见）**：Echoes Basic
- **显示名（Display Name，用户可见，建议逐语言填）**：
  - 中：入门版
  - 英：Starter
  - 西：Versión inicial / 法：Version de démarrage / 德：Einstiegsversion / 意：Versione iniziale / 葡：Versão inicial / 日：入門版 / 韩：시작 버전 / 荷：Startversie
- **描述（英文参考）**："Start your family archive: up to 5 chapters, 80 photos, 3 voice notes and 3 messages. Upgrade anytime."
- **价格**：美国 $0.99；各市场跟随最低价格档。
- **审核要点**：说明这是基础功能解锁，非订阅。

### 2) upgrade_full 升级包
- **Product ID**：`life.lifememory.echosoftime.upgrade_full`
- **类型**：非消耗型
- **参考名称**：Echoes Upgrade to Full
- **显示名**：
  - 中：补差价升级完整版 / 英：Upgrade to Full Version
  - 西：Mejorar a la versión completa / 法：Passer à la version complète / 德：Auf Vollversion upgraden / 意：Passa alla versione completa / 葡：Atualizar para a versão completa / 日：フルバージョンへアップグレード / 韩：풀 버전으로 업그레이드 / 荷：Upgraden naar volledige versie
- **描述（英文参考）**："For Starter users: pay the difference and unlock the full, unlimited version."
- **价格**：**始终 = 当地 full 价 − 当地 basic 价**，不可全局统一 $48.9，避免汇率差破坏闭环。
- **注意**：此商品只对已买 basic 的用户显示入口；未买 basic 时 App 不展示。

### 3) full 完整版买断
- **Product ID**：`life.lifememory.echosoftime.full`
- **类型**：非消耗型
- **参考名称**：Echoes Full Lifetime
- **显示名**：
  - 中：完整版（一次买断）/ 英：Full Version (Lifetime)
  - 西：Versión completa (de por vida) / 法：Version complète (à vie) / 德：Vollversion (lebenslang) / 意：Versione completa (a vita) / 葡：Versão completa (vitalícia) / 日：フルバージョン（買い切り）/ 韩：풀 버전 (평생 이용) / 荷：Volledige versie (levenslang)
- **描述（英文参考）**："One-time purchase, a lifetime preserved. Unlimited chapters, photos, voice notes and messages, with sharing and PDF export."
- **价格**：美国 $49.9（见下表分市场锚点）。

## 三、分市场定价锚点（输入美国价后 Apple 自动换算，再手动微调）

| 市场 | full 买断建议 | basic | upgrade_full |
| --- | --- | --- | --- |
| 美国（基准） | $49.9 | $0.99 | $48.91 |
| 西欧（德/法/荷/意） | 约 €49.99 / £44.99 | 跟随最低档 | 当地 full − 当地 basic |
| 日本 | ¥6,800–7,800 | 跟随最低档 | 当地 full − 当地 basic |
| 韩国 | ₩59,000–69,000 | 跟随最低档 | 当地 full − 当地 basic |
| 拉美（墨/巴） | $19.99–29.99 等价 | 跟随最低档 | 当地 full − 当地 basic |
| 中国大陆 | 暂缓，先不设 | — | — |

> upgrade_full 务必按当地实际价差填，不要照搬美国 $48.91。

## 四、后台配置步骤

1. 登录 App Store Connect → 选 App → **App 内购买项目（In-App Purchases）** → **创建（+）**。
2. 类型选 **非消耗型（Non-Consumable）**，逐个创建上述三个商品。
3. 填 ProductID（必须与代码一致）、参考名称、显示名与描述（逐语言本地化）。
4. 配置价格层级（选对应价格档），勾选要上架的地区。
5. 为每个商品上传 **审核截图（Review Screenshot）**（1290×2796 之类，可先用占位图）。
6. 「审核信息」里填写：无账号、无服务端、非订阅；恢复购买向 Apple 校验。
7. 商品状态先设「准备提交」，随 App 版本一起提交审核；审核通过后变为「已批准」才会出现在 App 内。
8. 沙盒测试：用 App Store Connect 建**沙盒测试账号**，在真机设置 → App Store → 沙盒账户登录，即可免费测试购买流程。

## 五、代码侧已就绪对照（无需再改）

- `PurchaseManager.swift`：三商品常量、`unpaid/basic/pro` 档位判定、`purchase()` / `restore()`（AppStore.sync）、后台交易监听。
- 门限：`canAddNode / canAddPhoto / canAddVoice / canAddMessage / canShare / canExport` 已接入各页面。
- `PaywallView.swift`：按档位显示购买按钮、Apple 本地化价格、恢复购买。
- 设置页：显示当前档位、升级入口、恢复购买按钮。
- 多语言购买文案（paywall.*、settings.premium.*）已在 10 个 strings 文件中。

## 六、上架前提醒

- 商品未配置时，App 内按钮显示但购买不可用（安全禁用），不阻塞开发与真机预览。
- 隐私政策已补「内购与支付」段；App Store Connect 的**隐私问卷**需另填（声明不收集数据、支付由 Apple 处理）。
- 促销：Apple 内购无优惠券，靠限时改价；basic $0.99 长期作引流入口。
