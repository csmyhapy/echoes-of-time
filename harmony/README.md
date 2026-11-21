# 岁月回声 · 鸿蒙版（HarmonyOS）

私人家庭记忆簿的鸿蒙原生实现。纯本地：无账号、无服务器、无云端、不采集数据；唯一联网场景是华为应用市场内购结算与恢复购买。

- BundleName：`life.lifememory.echosoftime`（与 iOS / Android 一致）
- 技术栈：ArkTS + ArkUI 声明式，Stage 模型
- 兼容：HarmonyOS NEXT 5.0（API 12）及以上；编译目标 API 26（HarmonyOS 7）
- 首发：中国大陆、中文 demo（王秀兰 1936–2022）

---

## 一、怎么打开与运行

1. 安装 **DevEco Studio 26.0.0 Release（macOS 版，26.0.0.865）**。
2. `File → Open`，选择本目录 `harmony/`（不是仓库根目录）。
3. 首次 Sync 若弹「SDK 路径」提示：用内置 SDK，`DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk`（注意不是 `.../sdk/default`）。
4. `Project Structure → Signing Configs` 勾选自动签名（需登录已实名认证的华为开发者账号）。
5. 真机或模拟器 Run。首次启动自动建库 → 灌入中文 demo → 首页。

### 已验证的构建结果（2026-11-20）

| 项 | 结果 |
|---|---|
| IDE | DevEco Studio 26.0.0.865（Mac ARM，MD5 目录内 app 已装到 `/Applications/DevEco-Studio.app`） |
| SDK | 内置 HarmonyOS 26.0.0 Release（`compileSdkVersion 26.0.0.105`，API 26） |
| 构建命令 | `./build.sh`（或 `./build.sh release`） |
| debug HAP | `entry/build/default/outputs/default/entry-default-unsigned.hap`（同路径，按需切 debug/release） |
| release HAP | 9.4 MB（9,841,256 B），`minAPIVersion=12`、`targetAPIVersion=26`、`buildMode=release` |
| 校验值 | SHA-256 `26a429a44c010234d9b1f2d40831960982063fb4296333a1d3c8f10ab9229e4e`（9,841,256 B，2026-11-21） |
| 签名 | **未签名**（缺 AGC 证书/Profile，`No signingConfig found for product default`） |

> 命令行构建必须设置 `JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home`，否则 `PackageHap` 会报 `Unable to locate a Java Runtime`。`build.sh` 已封装好这些环境变量。

产物另存一份在仓库根目录：`岁月回声-HarmonyOS-1.0.0-未签名.hap`。

---

## 二、功能实现范围（M0–M6 代码已全部落地）

| 模块 | 文件 | 状态 |
|---|---|---|
| 五实体模型 + 排序/归属规则 | `ets/models/Models.ets` | 完成 |
| RDB 建表 / 加密 / 版本迁移 | `ets/data/Db.ets` | 完成 |
| 数据访问（SQL 收口） | `ets/data/Repository.ets` | 完成 |
| 媒体落盘 / 压缩 / 删除 | `ets/data/MediaStore.ets` | 完成 |
| 中文 demo 种子（4 章/17 图/8 留言/9 旁白） | `ets/data/DemoSeeder.ets` | 完成 |
| 设置持久化 + AppStorage | `ets/services/AppStore.ets` | 完成 |
| 付费配额 / 限制提示 | `ets/services/Entitlements.ets` | 完成 |
| 档案库首页 / 新建档案 / 设备锁 | `ets/pages/Index.ets` | 完成 |
| 人物页（故事/进度看板/章节列表/编辑） | `ets/pages/person/PersonPage.ets` | 完成 |
| 章节页（旁白/故事/2 列照片网格/相册多选导入/删除） | `ets/pages/node/NodePage.ets` | 完成 |
| 照片页（大图缩放/说明/故事/设封面/排序/删除/留言） | `ets/pages/photo/PhotoPage.ets` | 完成 |
| 音频播放 | `ets/services/AudioService.ets` | 完成（fdSrc） |
| 录音 | `ets/services/AudioRecorder.ets` + `components/VoiceRecorder.ets` | 完成（AAC/m4a） |
| BGM 循环 + 后台长时任务 | `ets/services/Bgm.ets` | 完成（AVSession 未接） |
| 家人留言（人物/章节/照片） | `ets/components/MessageSection.ets` | 完成 |
| PDF 回忆册（封面/目录页码/章节扉页/图文同页） | `ets/services/PDFExporter.ets` | 完成（排版引擎自建） |
| 档案包导出/导入 | `ets/services/ArchiveService.ets` | 完成（.echosarchive.zip） |
| 三档 IAP / 恢复购买 | `ets/services/IapService.ets` + `pages/paywall/PaywallPage.ets` | 完成（待 AGC 配置） |
| 设置页 | `ets/pages/settings/SettingsPage.ets` | 完成 |
| 10 语言资源 | —— | 未做（当前中文硬编码，首发可用） |
| 分享卡片 | —— | 未做（iOS 有，鸿蒙留 M7） |

---

## 三、付费与商品配置（AGC 必须同名）

| 商品 ID | 内容 | 建议人民币价 |
|---|---|---|
| `basic` | 5 章节 / 80 照片 / 3 旁白 / 3 留言，导出受限 | ¥6 |
| `upgrade_full` | 补差价升级（full − basic） | ¥322 |
| `full` | 全部不限量 + PDF/档案包 | ¥328 |

三者均为**非消耗型**；`basic + upgrade_full = full`。恢复购买走 `queryPurchases(CURRENT_ENTITLEMENT)`，首次启动首页会静默恢复一次。

---

## 四、数据约定（与 iOS/Android 一致）

- 五张表：`persons / nodes / photos / voice_notes / messages`。
- 媒体只存**文件名**，文件在 `filesDir/media/<personId>/`。
- 章节排序：`sortOrder → webOrder(0 视为最末) → 起始年 → createdAt`。
- 照片归属章节：主 `nodeId` 命中，或 `tags` 里的 UUID 命中。
- 照片旁白只写在 `photos.audioFileName`；人物/章节旁白才建 `voice_notes`。
- 备份包 `.echosarchive.zip`：`data.json`（version/exportedAt/person/nodes/photos/voices/messages）+ `media/`，日期 ISO8601。

---

## 五、编译已通过，真机仍需验证的 6 处

> ArkTS 编译 0 error（Release 全量重建通过），下面 6 项属于「能编译但必须真机看效果」的行为风险。

0. **后台播放**：API 26 的 `module.json5` 已不再接受模块级 `backgroundModes: ["audioPlayback"]`（schema 直接报错），该字段已移除；`Bgm.requestBackground()` 运行时会调 `startBackgroundRunning(AUDIO_PLAYBACK)`，需真机确认能否授予，失败时代码会静默退化为前台播放。
1. **`Image()` 读沙箱图片**：当前 `file://` + 绝对路径（`MediaStore.imageUri`）。若封面空白，改成 `image.createImageSource(path)` → PixelMap。
2. **PDF Kit 字体/坐标**：`fontInfo.fontPath` 取 `Font.getFontByName('HarmonyOS Sans')`；取不到时文字可能不显示。`addTextObject` 的 y 基准需真机微调。
3. **`zlib.compressFile(目录, zip, {})` 与 `decompressFile(..., {})`**：API 26 起 options 为必传参数（已补 `{}`）；仍需确认目录能被压缩，且生成的 zip 在 iOS 端可导入。
4. **`picker.DocumentViewPicker.save()`** 返回的 uri 用 `fs.openSync` 写入是否可写。
5. **`AVPlayer.fdSrc`** 播沙箱 m4a、`AVRecorder` 的 `fd://` 输出是否成立。
6. **378 条 ArkTS 告警**：主要是 `promptAction.showToast`/`router.back` 已废弃、以及「Function may throw exceptions」，不影响构建，真机回归时再逐条替换为 `UIContext.getPromptAction()` 等新接口。

---

## 六、demo 素材来源

- 照片：`../EchoesOfTime/Resources/DemoPhotos/demo_zh_*.jpg`（17 张）
- 旁白：`../EchoesOfTime/Resources/DemoVoices/`（9 段 m4a）
- BGM：`../EchoesOfTime/Resources/BGM/bgm_demo.m4a`
- 文案：`../EchoesOfTime/Services/DemoData.swift` 的 `insertChinese`

已复制进 `entry/src/main/resources/rawfile/demo/`，运行时复制到沙箱再使用。
