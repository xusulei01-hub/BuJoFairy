# TravelJournal macOS 版设计文档

**日期**: 2026-05-26
**状态**: 已确认，待实现
**范围**: 将 iOS TravelJournal App 移植为原生 macOS App，同时加入多模态 AI 支持

---

## 1. 背景与目标

### 1.1 问题

当前 iOS 版 TravelJournal 在中国大陆无法直连 Google Gemini API，导致 AI 手帐生成功能不可用。用户 Mac 上已有代理工具，但 iOS 真机/模拟器无法利用 Mac 代理。

### 1.2 目标

1. 在 macOS 上运行原生 App，利用 Mac 系统代理访问 Gemini API
2. 同时支持从 Mac Photos.app 和 Finder 导入照片
3. 加入多模态 AI 能力（让 Gemini 分析真实照片内容生成手帐）
4. 保留后续复用代码到 iOS 的可能

### 1.3 非目标

- 不实现 iOS/macOS 数据实时同步（后续迭代）
- 不切换 AI 模型（继续使用 Gemini）
- 不实现多窗口模式（单窗口）

---

## 2. 架构概览

### 2.1 技术栈

| 层级 | 技术 |
|---|---|
| UI | SwiftUI + AppKit (按需桥接) |
| 数据 | SwiftData (macOS 14+) |
| 网络 | URLSession |
| AI | Google Gemini 2.5 Flash (多模态) |
| 认证 | Sign in with Apple |
| 地图 | MapKit |

### 2.2 数据流

```
用户操作 → SwiftUI View → ViewModel → Service → SwiftData / Network
                              ↓
                        PhotoImageProvider (抽象加载层)
                              ↓
              FileURLImageProvider    PhotosLibraryImageProvider
```

---

## 3. 数据模型

### 3.1 PhotoItem 改造（核心变更）

当前 `PhotoItem` 强依赖 `PHAsset`（`localAssetID` 字段），macOS 上 Finder 来源的照片没有 `PHAsset`，需要抽象来源类型。

```swift
enum PhotoSource: String, Codable {
    case photosLibrary   // Mac Photos.app
    case fileURL         // Finder 文件路径
}

@Model
final class PhotoItem {
    var id: UUID
    var source: PhotoSource
    var sourceIdentifier: String?   // PHAsset localIdentifier 或 file:// URL
    var timestamp: Date
    var gpsLatitude: Double?
    var gpsLongitude: Double?
    var locationName: String?
    var trip: Trip?

    init(source: PhotoSource, sourceIdentifier: String?, timestamp: Date) {
        self.id = UUID()
        self.source = source
        self.sourceIdentifier = sourceIdentifier
        self.timestamp = timestamp
    }
}
```

### 3.2 Trip 扩展

```swift
@Model
final class Trip {
    var id: UUID
    var name: String
    var startDate: Date
    var photos: [PhotoItem]?
    var journals: [JournalEntry]?
    var sourceFolderURL: String?   // 新增：记录 Finder 导入的源文件夹路径

    init(name: String, startDate: Date) {
        self.id = UUID()
        self.name = name
        self.startDate = startDate
    }
}
```

### 3.3 其他模型

`JournalEntry`、`JournalContent`、`JournalPage` 与 iOS 版保持一致，无需改动。

### 3.4 存储位置

SwiftData 存储在 `~/Library/Application Support/TravelJournalMac/` 下，与 iOS 版隔离。

---

## 4. 导航与 UI 布局

### 4.1 整体结构

采用 **Sidebar + Detail** 单窗口布局：

```
┌──────────────────────────────────────────────────────────────┐
│ TravelJournal                           [+] [🔍] [👤]        │
├──────────┬───────────────────────────────────────────────────┤
│          │                                                   │
│  🗺 地图   │              Detail Content Area                  │
│          │                                                   │
│  📷 照片库 │                                                   │
│          │                                                   │
│  📖 手帐库 │                                                   │
│          │                                                   │
│  ⚙ 设置   │                                                   │
│          │                                                   │
└──────────┴───────────────────────────────────────────────────┘
         ↑ Sidebar (可折叠, 默认宽度 200pt)
```

### 4.2 Sidebar 项目

| 图标 | 名称 | Detail 内容 |
|---|---|---|
| 🗺 | 地图 | MapKit 视图 + 旅行足迹标记 |
| 📷 | 照片库 | 旅行列表 → 点击旅行 → 照片网格 + 导入按钮 |
| 📖 | 手帐库 | 手帐列表 → 点击手帐 → 手帐阅读器 |
| ⚙ | 设置 | API Key、账号、数据导出 |

### 4.3 Toolbar（Contextual）

每个 Detail 视图根据当前内容动态显示 Toolbar 按钮：

- **照片库 Detail**: `[新建旅行]` `[从文件夹导入]` `[从 Photos 导入]` `[生成手帐]`
- **手帐库 Detail**: `[导出长图]` `[分享]`
- **设置 Detail**: `[保存]`

### 4.4 窗口规格

| 属性 | 值 |
|---|---|
| 最小尺寸 | 900 × 600 |
| 默认尺寸 | 1200 × 800 |
| 全屏 | 支持 |
| Sidebar 折叠 | ⌃⌘S |

### 4.5 菜单栏

```
File
  ⌘N 新建旅行
  ⌘I 导入照片...
  ⌘⇧E 导出数据...

View
  ⌃⌘S 显示/隐藏 Sidebar

Window
  最小化 / 缩放 / 全屏
```

### 4.6 拖拽交互

- 从 Finder 拖拽图片/文件夹到 Sidebar 旅行项 → 导入到该旅行
- 从 Finder 拖拽到照片网格区域 → 导入到当前旅行
- 拖拽到空白区域 → 创建新旅行并导入

---

## 5. 照片导入系统

### 5.1 核心策略：引用模式

两种来源**都不复制文件到 sandbox**，只存储引用标识，最大限度节省磁盘空间。

| 来源 | 存储内容 | 读取方式 | 失效风险 |
|---|---|---|---|
| Finder | 文件绝对路径 (`file://`) | `Data(contentsOf:)` | 原文件移动/删除 |
| Photos | `PHAsset.localIdentifier` | `PHImageManager` | Photos.app 中删除 |

### 5.2 失效降级

当引用失效时：
1. 显示灰色占位图 + "原文件已移动或删除"
2. 提供 "重新选择文件" 按钮
3. 用户可重新定位文件，更新 `sourceIdentifier`

### 5.3 Finder 文件夹导入流程

1. 点击"从文件夹导入" → `NSOpenPanel` 选文件夹
2. 递归遍历文件夹内所有图片（`.jpg`, `.jpeg`, `.png`, `.heic`, `.webp`）
3. 读取 EXIF/GPS 信息
4. 创建 `PhotoItem(source: .fileURL, sourceIdentifier: fileURL.absoluteString)`
5. 反向地理编码获取地点名称

### 5.4 Photos.app 导入流程
1. 点击"从 Photos 导入" → 系统照片选择对话框
2. 获取选中照片的 `PHAsset.localIdentifier`
3. 读取 EXIF/GPS 信息（通过 `PHAsset` 属性）
4. 创建 `PhotoItem(source: .photosLibrary, sourceIdentifier: assetID)`
5. 反向地理编码获取地点名称

### 5.5 统一加载接口

```swift
protocol PhotoImageProvider {
    func loadImage(for photoItem: PhotoItem) async -> NSImage?
}

struct FileURLImageProvider: PhotoImageProvider {
    func loadImage(for photoItem: PhotoItem) async -> NSImage? {
        guard let identifier = photoItem.sourceIdentifier,
              let url = URL(string: identifier),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        return NSImage(data: data)
    }
}

struct PhotosLibraryImageProvider: PhotoImageProvider {
    func loadImage(for photoItem: PhotoItem) async -> NSImage? {
        guard let identifier = photoItem.sourceIdentifier else { return nil }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = fetchResult.firstObject else { return nil }
        // 使用 PHImageManager 异步请求图片
        // ...
    }
}
```

UI 层通过 `PhotoImageProvider` 统一加载，不区分来源。

---

## 6. AI 服务与多模态

### 6.1 多模态 API 格式

Gemini 支持在请求中内嵌 base64 编码的图片：

```swift
struct GeminiPart: Codable {
    let text: String?
    let inlineData: InlineData?

    struct InlineData: Codable {
        let mimeType: String
        let data: String  // base64
    }
}
```

### 6.2 macOS 多模态优势

- 照片已是文件路径，直接 `Data(contentsOf: url)` 读取，无需异步 PHAsset 请求
- 无照片权限弹窗（访问用户自己选的文件无需额外权限）
- 大照片可直接传原图（内存限制比 iOS 宽松）

### 6.3 Phase 1 实现

1. **照片选择**：从旅行中自动选 3-5 张代表性照片（按时间分布取样）
2. **压缩**：将照片缩放到 1024px 宽以内，JPEG 质量 0.8，控制请求大小
3. **Prompt 改造**：在现有 prompt 基础上增加照片分析指令

```
系统：你是一个旅行手帐创作助手。用户会提供旅行照片，请分析照片实际内容...
要求：
1. 根据照片内容生成描述（不要只根据地点名称编造）
2. 识别地标建筑、自然风光、美食、人物活动
3. 结合照片氛围选择文字风格
4. 每张照片附 1-2 句描述，融入手帐正文
5. 返回严格 JSON，格式为 { "pages": [...] }
```

### 6.4 Phase 2（后续迭代）

- 传全部照片让 AI 自动挑选最佳排版
- AI 识别照片中的人物、地标、情绪
- 根据照片色调推荐手帐模板配色

### 6.5 API Key 管理

设置面板保留 API Key 输入框，Key 存储在 macOS Keychain。未来可扩展支持多模型（预留 `AIProvider` 协议）。

---

## 7. 文件组织

### 7.1 项目目录

```
TravelJournalMac/
├── TravelJournalMac/
│   ├── TravelJournalMacApp.swift       ← App 入口
│   ├── Models/
│   │   ├── Trip.swift                  ← 复用 iOS + sourceFolderURL 扩展
│   │   ├── PhotoItem.swift             ← 增加 PhotoSource 枚举
│   │   ├── JournalEntry.swift          ← 复用 iOS
│   │   └── JournalContent.swift        ← 复用 iOS
│   ├── Views/
│   │   ├── MainView.swift              ← NavigationSplitView 容器
│   │   ├── SidebarView.swift           ← 侧边栏
│   │   ├── Map/
│   │   │   └── MapView.swift           ← 复用 iOS MapKit 逻辑
│   │   ├── Photos/
│   │   │   ├── PhotosLibraryView.swift     ← 旅行列表 + 照片网格
│   │   │   ├── TripDetailView.swift        ← 某旅行照片详情
│   │   │   ├── PhotoThumbnailView.swift    ← 照片缩略图
│   │   │   └── ImportPanelView.swift       ← 导入操作面板
│   │   ├── Journal/
│   │   │   ├── JournalListView.swift       ← 手帐列表
│   │   │   ├── JournalReaderView.swift     ← 手帐阅读器 (NSImage)
│   │   │   ├── JournalPageView.swift       ← 单页渲染 (NSImage)
│   │   │   └── GenerateJournalView.swift   ← 生成手帐面板
│   │   └── Settings/
│   │       └── SettingsView.swift          ← 设置面板
│   ├── ViewModels/
│   │   ├── PhotosViewModel.swift           ← 照片导入逻辑
│   │   ├── JournalViewModel.swift          ← 手帐生成逻辑
│   │   └── MapViewModel.swift              ← 地图逻辑
│   ├── Services/
│   │   ├── AIService.swift                 ← 多模态 Gemini 调用
│   │   ├── APIClient.swift                 ← 复用 iOS
│   │   ├── AuthManager.swift               ← 复用 iOS
│   │   ├── KeychainManager.swift           ← macOS Keychain
│   │   ├── PhotoImageProvider.swift        ← 新增：统一加载接口
│   │   └── JournalPromptBuilder.swift      ← 多模态 prompt 升级
│   └── Assets.xcassets/
└── TravelJournalMac.xcodeproj/
```

### 7.2 复用策略

**直接复用（无需修改）**：
- `JournalEntry`, `JournalContent`, `JournalPage` 数据模型
- `APIClient`, `AuthManager` 服务层
- `JournalPromptBuilder` prompt 模板（需增加多模态版本）

**需要适配**：
- `PhotoItem` — 增加 `PhotoSource` 枚举
- `Trip` — 增加 `sourceFolderURL`
- `JournalReaderView` — `UIImage` → `NSImage`, `UIActivityViewController` → `NSSharingServicePicker`
- `PhotoThumbnailView` — 加载逻辑改用 `PhotoImageProvider`

**完全新建**：
- `MainView` — `NavigationSplitView` 容器
- `SidebarView` — macOS Sidebar
- `PhotoImageProvider` — 抽象加载接口
- `ImportPanelView` — `NSOpenPanel` 封装

### 7.3 与 iOS 代码隔离

macOS 项目完全独立，不共享 Xcode Target。后续如需复用代码，通过创建 `Shared/` 目录逐步抽取共用模块。

---

## 8. 技术风险与应对

| 风险 | 影响 | 应对 |
|---|---|---|
| `PhotosPicker` 在 macOS 上行为不一致 | 高 | 测试 macOS 13+ 的 `PhotosPicker`，如不可用则降级为纯 `NSOpenPanel` |
| `PHAsset` 在 macOS 上 API 差异 | 中 | 使用 `PHImageManager` 通用 API，避免平台特定方法 |
| `NSImage` 渲染长图性能 | 中 | 分页渲染，避免一次性创建超大位图 |
| Gemini 多模态 base64 请求过大 | 中 | 照片压缩到 1024px，JPEG 质量 0.8，单张控制在 500KB 以内 |
| 代理失效导致 AI 不可用 | 中 | 预留 `AIProvider` 协议接口，后续可快速接入 DeepSeek |

---

## 9. 实现阶段

### Phase 1: 项目搭建（2 小时）
1. 新建 macOS App Target
2. 迁移 Models（复用 + 扩展）
3. 迁移 Services（APIClient, AuthManager, KeychainManager）
4. 配置 App Sandbox 和文件访问权限

### Phase 2: 核心框架（1 天）
1. 实现 `NavigationSplitView` + `SidebarView`
2. 实现 `PhotoImageProvider` 协议 + 两个实现
3. 实现 Finder 导入（`NSOpenPanel` + EXIF 读取）
4. 实现 Photos 导入（`PhotosPicker` 或 `PHAsset`）
5. 实现照片网格显示

### Phase 3: 手帐系统（1 天）
1. 迁移 `JournalListView`
2. 重写 `JournalReaderView`（`NSImage` 渲染 + `NSSharingServicePicker` 分享）
3. 迁移 `GenerateJournalView`
4. 实现手帐导出长图

### Phase 4: 多模态 AI（半天）
1. 升级 `AIService` 支持 inlineData
2. 实现照片压缩 + base64 编码
3. 升级 `JournalPromptBuilder` 多模态 prompt
4. 集成到手帐生成流程

### Phase 5: 功能补齐（半天）
1. Sign in with Apple（macOS 版本）
2. 菜单栏 + 快捷键
3. 拖拽导入
4. 设置面板

### Phase 6: 测试 + 部署（半天）
1. 功能测试
2. 后端 API 连通测试
3. Archive + 签名 + 本地安装

**总预估时间：3-4 天**
