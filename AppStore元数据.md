# App Store Connect 元数据（美区英文首发）

> 用途：在 App Store Connect 新建 App / 版本信息时逐项粘贴。首发仅美区英文，其余 9 语在 App 内可用，商店页暂不本地化。
> 隐私政策 URL 已通过 GitHub Pages 上线：https://csmyhapy.github.io/echoes-of-time/privacy.html 。
> 字符限制：名称 ≤30，副标题 ≤30，关键词 ≤100（逗号分隔），描述 ≤4000。

## 一、基本信息

| 字段 | 填写内容 |
| --- | --- |
| **App 名称（Name）** | Echoes of Time |
| **副标题（Subtitle）** | Private family memory book |
| **主要分类（Primary Category）** | Lifestyle |
| **次要分类（Secondary）** | Books（可选，留空亦可） |
| **价格** | 免费下载；内购三档（见内购清单） |
| **分级（Age Rating）** | 4+（问卷答案见第四节） |
| **隐私政策 URL（Privacy Policy）** | https://csmyhapy.github.io/echoes-of-time/privacy.html（GitHub Pages，已上线） |
| **营销 URL** | 留空（无官网） |
| **支持 URL** | 留空，或填 `mailto:support@lifememory.life` |
| **iOS 最低版本** | 17.0（工程已设） |
| **Bundle ID** | `life.lifememory.echosoftime` |

> 名称 15 字符；副标题 "Private family memory book" 27 字符（≤30）。

## 二、描述（Description，整段粘贴）

```
Echoes of Time turns your iPhone into a private family memory book — a place to gather a loved one's photos, stories, and voice recordings, and preserve them for your children and grandchildren. Everything stays on your device: no account, no server, no cloud upload, no tracking.

BUILD A LIFE STORY, CHAPTER BY CHAPTER
• Create a person's archive and arrange chapters by era — childhood, youth, career, family, later years.
• Add photos to each chapter and write the story behind them in your own words.
• Record voice narration for the person, a chapter, or a single photo, and listen back anytime.
• Leave family messages next to a chapter or photo so relatives can contribute their own memories.

TWO MODES FOR TWO ROLES
• Editor mode: you (the child or family member) build and edit the archive with normal-size text.
• Reader mode: switch to a large-text, large-button read-only view so older relatives can browse and listen on their own.

KEEP IT PRIVATE
• All photos, audio, and text are stored only on this device. Nothing is uploaded, collected, or analysed.
• Lock the app with Face ID / Touch ID so only you can open it.
• Export a beautifully formatted PDF memory book or a backup archive file, and move or restore it yourself.

MADE FOR FAMILIES
• Works offline, anywhere — no internet needed to record or read.
• Available in English, Chinese, Spanish, French, German, Italian, Dutch, Portuguese (Brazil), Japanese, and Korean.
• Free to explore with a built-in demo; unlock unlimited chapters, photos, voice notes, messages, PDF export, and sharing with the lifetime Full Version.

Echoes of Time is for anyone who wants to save a parent's or grandparent's story before it is lost — quietly, privately, and on your own phone.
```

## 三、关键词（Keywords，97 字符，直接粘贴）

```
memoir,legacy,life story,photo album,voice notes,grandparent,keepsake,journal,biography
```

> 已避开与名称重复的词（Echoes/Time/family/memory/book 不重复堆砌）。如需替换，单条 ≤100 字符。

## 四、年龄分级问卷（结果 4+）

在 App Store Connect → Age Rating 逐项选「无 / None」：

| 问卷项 | 选择 |
| --- | --- |
| 暴力 / 卡通或现实暴力 | None |
| 亵渎 / 低俗幽默 | None |
| 恐惧 / 恐怖主题 | None |
| 成人 / 性暗示主题 | None |
| 烟酒 / 药物使用 | None |
| 赌博（含模拟） | None |
| 未成熟内容 / 露骨 | None |
| 位置数据 | 不收集（App 不获取位置） |
| 社交功能 / 用户生成内容公开 | 无（留言仅本地，不公开、不联网） |
| 未经用户同意的内容访问 | 否 |

→ 综合分级 **4+**。

## 五、隐私问卷（App Privacy，结论：不收集任何数据）

App Store Connect → App Privacy → 选 **"Data Not Collected"（不收集数据）**。

理由（与 privacy.html、App 内隐私页一致）：
- 无账号、无登录、无服务器、无分析 SDK、无广告、无崩溃上报；
- 照片/录音/文字/留言全部写在本机沙盒，不上传；
- 不获取位置、不获取联系人、不获取设备标识；
- 支付由 Apple 处理，App 不接触卡号，不存储交易记录。

> 内购在隐私问卷里不属于"被收集的数据"，无需申报。

## 六、版本 What's New（1.0.0 首发）

```
Welcome to Echoes of Time 1.0 — your private family memory book on this device.
Build a loved one's archive chapter by chapter, add photos and voice narration, record family messages, and export a PDF memory book. No account, no server, everything stays on your iPhone.
```

## 七、审核信息（Review Information）

| 项 | 填写 |
| --- | --- |
| 演示账号 | 不需要（无登录、无账号），选 "Sign-in required: No" |
| 联系人姓名 / 邮箱 | 填开发者本人 / support@lifememory.life |
| 备注（Notes） | "This is an offline, local-only app with no account, no server, and no network calls. All content is stored on the device. In-app purchases are processed by Apple. A built-in demo archive is available on launch; no credentials needed." |
| 联系电话 | 选填 |

## 八、内购商品

按《AppStoreConnect配置清单.md》逐项在后台创建三商品（basic / upgrade_full / full），随本版本一起提交。商品未批准前 App 内按钮安全禁用，不阻塞审核。
