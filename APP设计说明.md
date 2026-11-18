# 《岁月回声 / Echoes of Time》iOS 本地化 APP 设计说明 v1

> 本文档是 APP 的"设计总纲"。UI 文案以**英文**为首发语言，内部设计与文档使用中文，便于管理。
> 工程根目录：`/Users/daizhishen/SynologyDrive/echosoftime`

---

## 0. 一页速览

| 维度 | 结论 |
|---|---|
| 产品形态 | **本地化 iOS APP**（数据只存设备，零服务器依赖） |
| 用户角色 | **子女建档（Editor）** + **长辈浏览（Reader）** 双模式 |
| 技术栈 | SwiftUI + SwiftData（iOS 17+），Xcode 27.2 / Swift 6.4 |
| 数据模型 | 5 个实体：Person / Node / Photo / VoiceNote / Message |
| 媒体存储 | 照片、录音存 App 沙盒 `Application Support/Media/<档案ID>/`，数据库只存文件名 |
| 分享方式 | 导出 PDF 回忆册 / zip 档案包（不依赖服务器） |
| 语言 | 中英双语，默认跟随设备语言，可扩展更多语言 |
| 工程管理 | `project.yml`（xcodegen 源文件）→ 生成 `EchoesOfTime.xcodeproj` |
| 当前进度 | P0 骨架已完成并可编译；P1–P7 待开发 |

---

## 1. 产品定位与用户角色

### 1.1 定位
把原 PHP + MySQL 云端网站，改造成**装在 iPhone / iPad 上的私人记忆档案工具**：

- 网站 = 云端展厅（访客看、需登录、依赖主机）
- APP = 家里的相册 + 录音机 + 记忆管家（离线、私密、随手记录）

### 1.2 两类用户

| 角色 | 谁 | 能力 | 界面 |
|---|---|---|---|
| **Editor 编辑模式** | 子女 / 家人（建档者） | 新建档案、建章节、加照片、录音、写故事、留言、导出、删除 | 常规字号，完整功能 |
| **Reader 长辈模式** | 老人 | 只读浏览：档案 → 时间线 → 照片 → 播放旁白 | 超大字号、大按钮、极少层级、隐藏编辑入口 |

模式由设置页切换，持久化到 `UserDefaults`。

---

## 2. 信息架构与导航

```
启动
└─ RootView（按 AppState.mode 分流）
   ├─ EditorRootView（TabView）
   │   ├─ Tab「Library 档案库」
   │   │   └─ LibraryView
   │   │       └─ PersonDetailView（人物主页 / 人生时间线）
   │   │           └─ NodeDetailView（章节照片页）【待建】
   │   │               └─ PhotoDetailView（照片详情 / 灯箱 / 旁白）【待建】
   │   └─ Tab「Settings 设置」
   │       └─ SettingsView（语言 / 模式 / 大字 / 数据说明 / 隐私锁）
   └─ ReaderRootView
       └─ LibraryView(isReader: true)（只读、大字）
```

层级原则：**Person → Node（章节）→ Photo（照片）**，与网站 `persons / nodes / photos` 完全对应。

---

## 3. 数据模型

### 3.1 实体关系

```
Person（人物档案）
 ├─ Node        章节：标题 / 年代 / 封面 / 简介 / 故事 / 排序
 │   └─ Photo   照片（也允许直挂 Person）
 ├─ Photo       照片：图片 / 标题 / 故事 / 标签 / 排序 / 旁白音频
 ├─ VoiceNote   语音旁白：scope(person|node|photo) + targetID + 时长
 └─ Message     留言：家人名 / 内容 / 时间 / 父留言 / 角色
```

- `Photo` 可同时属于 `Person` 与 `Node`（node 为 nil 表示人物直挂）。
- `Message` 可挂在 `Person` / `Node` / `Photo` 上。
- 删除规则：Person / Node / Photo 级联删除子项。

### 3.2 实体字段（SwiftData）

| 实体 | 关键字段 |
|---|---|
| Person | id、name、birthYear、summary、story、coverImageFileName、bgmFileName、createdAt |
| Node | id、name、yearRange、summary、story、coverImageFileName、sortOrder、isVisible、person |
| Photo | id、imageFileName、audioFileName、caption、story、tags、sortOrder、person、node |
| VoiceNote | id、scopeRaw、targetID、audioFileName、duration、createdAt、person |
| Message | id、userName、content、role、parentID、createdAt、isDeleted、person/node/photo |

### 3.3 与网站表映射

| 网站 MySQL | APP SwiftData | 备注 |
|---|---|---|
| `persons` | `Person` | 直接对应 |
| `nodes` | `Node` | 直接对应 |
| `photos` | `Photo` | 文件路径改为本地文件名 |
| `voice_notes` | `VoiceNote` | scope / target_id 保留 |
| `messages` | `Message` | 本地留言 |
| `app_users` | 不迁移 | APP 无账号体系（本地使用） |

---

## 4. 分层架构

```
┌─────────────────────────────────────────────┐
│ 表现层 Views（SwiftUI）                      │
│  LibraryView / PersonDetailView / Settings… │
├─────────────────────────────────────────────┤
│ 状态层 AppState（@Observable）                │
│  语言 / 模式(Editor|Reader) / 大字 / 隐私锁   │
├─────────────────────────────────────────────┤
│ 数据层 SwiftData（@Model）                    │
│  Person / Node / Photo / VoiceNote / Message │
├─────────────────────────────────────────────┤
│ 服务层 Services                              │
│  MediaStore（图片压缩/落盘/读取/删除）        │
│  Localization（运行时切换语言）               │
│  【待建】AudioRecorder / Exporter / Importer │
│  【待建】BackupService / PrivacyLock         │
├─────────────────────────────────────────────┤
│ 资源层 Resources                             │
│  en.lproj / zh-Hans.lproj / Assets.xcassets  │
└─────────────────────────────────────────────┘
```

设计原则：
1. **View 不直接碰文件系统**，一律走 MediaStore；
2. **状态集中在 AppState**，避免散落 UserDefaults；
3. **服务层可替换**（例如录音器、导出器、备份器单独成文件，便于测试）。

---

## 5. 目录结构

### 5.1 现状（已存在）

```
echosoftime/
├─ project.yml                      # xcodegen 工程描述（源文件）
├─ EchoesOfTime.xcodeproj/          # 生成产物（勿手改）
└─ EchoesOfTime/
   ├─ EchoesOfTimeApp.swift         # App 入口 + RootView 分流
   ├─ Info.plist                    # 权限文案、Bundle 配置
   ├─ Models/
   │  ├─ Models.swift               # 5 个 SwiftData 实体
   │  ├─ AppState.swift             # 语言 / 模式 / 大字状态
   │  ├─ Localization.swift         # 运行时切语言
   │  └─ MediaStore.swift           # 本地媒体文件管理
   ├─ Views/
   │  ├─ LibraryView.swift          # 档案列表
   │  ├─ PersonDetailView.swift     # 人物时间线
   │  └─ SettingsView.swift         # 设置
   └─ Resources/
      ├─ en.lproj/Localizable.strings
      └─ zh-Hans.lproj/Localizable.strings
```

### 5.2 目标结构（开发完成后）

```
EchoesOfTime/
├─ EchoesOfTimeApp.swift
├─ Info.plist
├─ Models/                     # 数据与状态
│  ├─ Models.swift
│  ├─ AppState.swift
│  └─ Localization.swift
├─ Services/                   # 无 UI 的能力
│  ├─ MediaStore.swift         （已有，移至 Services）
│  ├─ AudioRecorder.swift      【P3】
│  ├─ AudioPlayer.swift        【P1】
│  ├─ PDFExporter.swift        【P5】
│  ├─ ArchiveExporter.swift    【P5】
│  ├─ BackupService.swift      【P5】
│  ├─ Importer.swift           【P6】
│  └─ PrivacyLock.swift        【P4】
├─ Views/
│  ├─ Common/                  # 复用组件（封面图、空状态、按钮）
│  ├─ Library/LibraryView.swift
│  ├─ Person/PersonDetailView.swift
│  ├─ Person/PersonEditView.swift        【P2】
│  ├─ Node/NodeDetailView.swift          【P1】
│  ├─ Node/NodeEditView.swift            【P2】
│  ├─ Photo/PhotoDetailView.swift        【P1】
│  ├─ Photo/PhotoEditView.swift          【P2】
│  └─ Settings/SettingsView.swift
└─ Resources/
   ├─ en.lproj/Localizable.strings
   ├─ zh-Hans.lproj/Localizable.strings
   └─ Assets.xcassets            【待补 AppIcon / AccentColor】
```

> 迁移说明：现在 `MediaStore.swift` 放在 `Models/`，后续移到 `Services/`；`project.yml` 的 `sources: EchoesOfTime` 会自动包含新目录，无需改工程配置。

---

## 6. 功能体系

### 6.1 模块清单

| # | 模块 | 职责 | 关键文件 | 状态 |
|---|---|---|---|---|
| 1 | 档案库 | 档案列表、空状态、进入详情 | LibraryView | ✅ 基础可用（新建仅示例） |
| 2 | 人物主页 | 封面 / 生卒年 / 故事 / 时间线 | PersonDetailView | ✅ 基础可用 |
| 3 | 章节照片页 | 章节封面、照片网格、进入灯箱 | NodeDetailView | ✅ 完成 |
| 4 | 照片详情 | 大图、标题、故事、旁白播放 | PhotoLightboxView | ✅ 完成 |
| 5 | 建档 / 编辑人物 | 新建、改名、改年份、换封面、写故事 | PersonEditView | ✅ 完成 |
| 6 | 章节编辑 | 新建章节、排序、可见性 | NodeEditView | ✅ 完成 |
| 7 | 照片管理 | 相册选图、压缩落盘、排序、删除 | NodeDetailView + MediaStore | ✅ 完成 |
| 8 | 录音 | 录制（人物/章节/照片级）、试听、替换 | AudioRecorder + RecorderSheet | ✅ 完成 |
| 9 | 留言 | 家人留言（人物/章节/照片）、删除 | MessageSection | ✅ 完成 |
| 10 | 导出 | PDF 回忆册、zip 档案包、系统分享 | PDFExporter / ArchiveExporter | ✅ 完成 |
| 11 | 备份 / 恢复 | 导出 zip 存文件 App / iCloud Drive | ArchiveExporter + ActivityView | ✅ 完成（手动备份） |
| 12 | 导入迁移 | 读完网站数据一次搬入 APP | Importer | ⬜ P6 |
| 13 | 设置 | 语言、模式、大字、隐私锁、数据说明 | SettingsView | 🟡 语言/模式/大字已有 |
| 14 | 隐私锁 | Face ID / 设备密码解锁 | PrivacyLock | ✅ 完成 |
| 15 | 本地化 | 双语 + 可扩展多语言 | Localization + lproj | ✅ 中英可用 |

### 6.2 功能优先级（MVP 定义）

**MVP 必须**：1、2、3、4、5、6、7、8 —— 即"能建档、能加照片、能录音、能看"。
**上线加分**：9 留言、10 导出、14 隐私锁。
**后续**：11 备份、12 导入、15 多语言扩展。

---

## 7. 关键业务流程

### 7.1 建档流程（Editor）
```
点 + → PersonEditView
  填姓名 / 生卒年 / 简介 → 选封面（PhotosPicker）→ 保存
→ 回到 PersonDetailView（空时间线）
→ 新建章节 NodeEditView（标题/年代/封面）
→ NodeDetailView → 加照片（拍照/选图）→ 写标题与故事
→ 录音按钮 → 生成旁白 → 自动挂到 Photo.audioFileName
```

### 7.2 浏览流程（Reader）
```
Library（大字列表）→ Person → 章节卡片 → 照片网格 → 大图 + 播放键 → 听旁白
```

### 7.3 录音流程
```
点击录音 → 请求麦克风权限（首次）
→ AVAudioRecorder 录 m4a（AAC，单声道 44.1kHz）
→ 停止 → 写文件到 Media/<personID>/voice_xxx.m4a
→ 读时长 → 写入 VoiceNote.duration 或 Photo.audioFileName
```

### 7.4 导出流程
```
选档案 → 生成 PDF（封面 / 时间线 / 每张照片+故事）
→ 生成 zip（data.json + media/）
→ ShareLink / UIActivityViewController 分享
```

### 7.5 迁移流程（一次性）
```
网站上导出的 .echosarchive（zip：data.json + media/）
→ APP 内"导入档案" → 解析 JSON → 建 Person/Node/Photo
→ 媒体文件写入 MediaStore → 保存
```

---

## 8. 本地化体系

| 项 | 设计 |
|---|---|
| 资源 | `Resources/<code>.lproj/Localizable.strings` |
| 默认语言 | 跟随设备语言（`Locale.preferredLanguages` 匹配） |
| 回退 | 匹配不到 → 英文 |
| 手动切换 | 设置页 Picker，`UserDefaults` 记住 → 覆盖设备默认 |
| 运行时生效 | `Bundle.setLanguage` 替换 Bundle 类 + 注入 `\.locale` |
| 扩展新语言 | ① `AppLanguage` 加 `case fr = "fr"`；② 新建 `fr.lproj/Localizable.strings`；**无需改匹配逻辑** |
| 当前语言 | en、zh-Hans（已完整） |

---

## 9. 数据安全与隐私

- **全部本地**：无服务器、无账号、无上传接口；
- **沙盒隔离**：媒体在 `Application Support/Media/`，用户不可见但可备份；
- **隐私锁**：Face ID 进入 App 时校验（P4）；
- **iCloud**：可选（默认关），走用户自己的 iCloud（私有）；
- **Info.plist 声明**：相册、相机、麦克风用途均写明"数据只留本机"；
- **App Store 隐私表**：可填"不收集数据"。

---

## 10. 技术约束与工程配置

| 项 | 值 |
|---|---|
| 最低系统 | iOS 17.0（SwiftData 要求） |
| 设备 | iPhone + iPad（`TARGETED_DEVICE_FAMILY = 1,2`） |
| Bundle ID | `life.lifememory.echosoftime` |
| 工程生成 | `xcodegen generate`（改 `project.yml` 后必须重新生成） |
| 开发语言 | Swift 6.4 / SwiftUI |
| 本地化开发语言 | `developmentLanguage: en` |
| 权限 | 相册读写、相机、麦克风（全英文文案） |
| 加密声明 | `ITSAppUsesNonExemptEncryption = false` |

---

## 11. 开发路线与状态

| 阶段 | 内容 | 状态 |
|---|---|---|
| **P0** | 工程骨架、SwiftData 模型、本地媒体、双模式、双语、编译通过 | ✅ 完成 |
| **P1** | 章节照片页 + 照片详情 + 旁白播放 | ✅ 完成 |
| **P2** | 建档 / 章节编辑 / 照片增删排序 | ✅ 完成 |
| **P3** | 录音（AVFoundation，m4a） | ✅ 完成 |
| **P4** | 留言 + Face ID 隐私锁 | ✅ 完成 |
| **P5** | PDF 导出 / zip 导出 / iCloud 备份 | ✅ 完成 |
| **P6** | 网站数据导入器（.echosarchive） | ⬜ 下一步 |
| **P7** | TestFlight 内测 → App Store 上架（隐私政策 / 截图 / 审核） | ⬜ |

---

## 12. 待决事项与风险

| # | 事项 | 说明 |
|---|---|---|
| 1 | AppIcon / 启动图 | 目前无 Assets.xcassets，上架前必须补 |
| 2 | 录音格式 | 计划 m4a(AAC)；若需兼容网站 wav，导入时转码 |
| 3 | iCloud 同步方案 | CloudKit（结构化）vs iCloud Drive（整包备份），建议后者先做 |
| 4 | 中文版上架 | 先发英文/海外区；中国区上架涉及额外资质 |
| 5 | 网站数据迁移 | 需要网站侧导出 `.echosarchive` 的脚本（P6 时做） |
| 6 | PDF 中文字体 | 导出若含中文，需嵌入字体（英文版无此问题） |
