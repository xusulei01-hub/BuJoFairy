# 旅行手帐 App 设计方案

> 版本：v1.0 | 日期：2026-05-25 | 状态：待审核

## 1. 产品概述

一款面向旅行爱好者的 iOS 手帐应用。核心功能：通过照片 GPS 元数据自动识别旅行地点，在地图上标注足迹，一键生成精美手帐。

## 2. 目标用户

- 旅行爱好者
- 喜欢记录和分享旅行经历的人
- 对 AI 辅助创作感兴趣的用户

## 3. 技术选型

| 层面 | 选择 | 理由 |
|------|------|------|
| **iOS 最低版本** | iOS 17+ | 利用最新 SwiftUI API |
| **UI 框架** | SwiftUI | 声明式 UI，与 iOS 17 新特性契合 |
| **架构模式** | MVVM | 轻量，适合当前单一功能阶段 |
| **本地存储** | SwiftData | Apple 原生方案，与 SwiftUI 深度集成 |
| **地图** | MapKit (iOS 17+) | 原生地图，标注与交互体验最佳 |
| **照片访问** | PhotosUI / PhotosPicker | 系统原生照片选择器 |
| **API 密钥存储** | Keychain | 安全存储用户 DeepSeek API Key |
| **后端框架** | Node.js + Express + TypeScript | 复用现有阿里云 ECS 技术栈 |
| **数据库 (服务端)** | SQLite + Prisma | 与现有部署保持一致，轻量无额外依赖 |
| **AI 服务** | DeepSeek API (Vision + Chat) | 用户自带 API Key，iOS 端直连 |
| **登录** | Sign in with Apple | iOS 原生体验，隐私友好 |

## 4. 整体架构

```
┌──────────────────────────────────────────────┐
│                  iOS App                      │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ │
│  │  地图   │ │ 照片库  │ │ 手帐库  │ │  我的   │ │
│  └────────┘ └────────┘ └────────┘ └────────┘ │
│           SwiftUI + MVVM + SwiftData          │
│     MapKit / PhotosUI / PencilKit            │
│                                               │
│  DeepSeek API ← 直连 (用户 Key → Keychain)     │
└──────────────────────┬───────────────────────┘
                       │ REST API
┌──────────────────────▼───────────────────────┐
│            阿里云 ECS (8.136.157.93)           │
│        Node.js + Express + Prisma + SQLite    │
│                                                │
│  功能：用户认证 / 手帐同步 / 模板库 / 社交预留   │
│  不涉及：AI 调用 / 照片存储                     │
└──────────────────────────────────────────────┘
```

## 5. 四个 Tab 详细设计

### 5.1 🗺️ 地图 Tab

| 功能 | 说明 |
|------|------|
| 足迹标注 | 在地图上用标注点展示所有去过的地方 |
| 聚合显示 | 同一区域多个标注点自动聚合，缩放后展开 |
| 标注交互 | 点击标注 → 弹出该地点的照片缩略图 + 手帐卡片预览 |
| 筛选 | 按旅行 / 时间段筛选显示 |
| 当前旅行 | 正在进行中的旅行高亮路径 |

### 5.2 📷 照片库 Tab

| 功能 | 说明 |
|------|------|
| 旅行相册 | 按旅行分组显示，封面 + 名称 + 日期范围 |
| 时间线浏览 | 按照片拍摄时间排列 |
| 选择模式 | 长按进入多选，用于生成手帐或批量编辑 |
| 照片详情 | 查看大图、GPS 位置、拍摄时间 |
| AI 识别入口 | 单张或批量照片触发 DeepSeek 识别地点 |
| 创建旅行 | 将一组照片创建为新旅行 |

### 5.3 📖 手帐库 Tab

| 功能 | 说明 |
|------|------|
| 手帐列表 | 按时间倒序展示所有生成的手帐，缩略图 + 标题 + 日期 |
| 手帐详情 | 翻页阅读完整手帐，图文混排展示 |
| 编辑手帐 | 修改文字、调整照片位置、更换模板 |
| 分享 | 导出为长图 / PDF，分享到社交平台 |
| 一键生成 | 选旅行 → 选模板偏好 → DeepSeek 生成 → 预览 → 保存 |
| 生成选项 | ① 模板自动匹配 / 手动选择 ② 联网搜索补充知识 开/关 |

### 5.4 👤 我的 Tab

| 功能 | 说明 |
|------|------|
| Apple 登录 | 原生 Sign in with Apple，获取用户标识 |
| API 设置 | 填入 DeepSeek API Key，显示余额/用量估算 |
| 关联账号 | 预留小红书 / 微博关联入口（显示「即将上线」） |
| 数据管理 | 手帐导出 / 本地数据清理 / 同步状态 |
| 关于 | 版本号、隐私政策、用户协议 |

## 6. 数据模型

### 6.1 iOS 本地 (SwiftData)

```
Trip (旅行)
├── id: UUID
├── name: String
├── startDate: Date
├── endDate: Date?
├── coverPhotoLocalID: String
├── serverID: String? (同步用)
├── photos: [Photo]
└── journals: [Journal]

Photo (照片)
├── id: UUID
├── localAssetID: String (PHAsset.localIdentifier)
├── gpsLatitude: Double?
├── gpsLongitude: Double?
├── timestamp: Date
├── locationName: String? (用户编辑或 AI 识别)
├── trip: Trip?
└── serverID: String?

Journal (手帐)
├── id: UUID
├── title: String
├── tripID: UUID
├── templateID: String
├── contentJSON: Data (富文本/排版数据)
├── coverImagePath: String
├── createdAt: Date
├── updatedAt: Date
└── serverID: String?
```

### 6.2 服务端 (Prisma)

```prisma
model User {
  id            String    @id
  appleUserID   String    @unique
  name          String?
  avatarURL     String?
  createdAt     DateTime  @default(now())
  trips         Trip[]
  socialAccounts SocialAccount[]
}

model Trip {
  id          String    @id
  userId      String
  name        String
  startDate   DateTime
  endDate     DateTime?
  coverURL    String?
  createdAt   DateTime  @default(now())
  user        User      @relation(fields: [userId], references: [id])
  journals    Journal[]
  locations   Location[]
}

model Location {
  id          String    @id
  tripId      String
  name        String
  latitude    Float
  longitude   Float
  photoCount  Int       @default(0)
  trip        Trip      @relation(fields: [tripId], references: [id])
}

model Journal {
  id          String    @id
  tripId      String
  title       String
  templateID  String
  contentJSON String
  coverURL    String?
  createdAt   DateTime  @default(now())
  updatedAt   DateTime  @updatedAt
  trip        Trip      @relation(fields: [tripId], references: [id])
}

model SocialAccount {
  id          String    @id
  userId      String
  platform    String    // "xiaohongshu" | "weibo"
  accountName String?
  connectedAt DateTime?
  user        User      @relation(fields: [userId], references: [id])
}
```

## 7. 核心流程

### 7.1 照片地点识别流程

```
用户选照片
    │
    ▼
提取 EXIF GPS + 时间戳
    │
    ├── 有 GPS? ──是──→ 本地反地理编码 (CLGeocoder) → 自动标注 ✓
    │
    └── 无 GPS? ──→ 用户手动输入地点 ✓
         │
         └── [可选] 用户手动触发 AI 识别
              │
              ▼
         压缩缩略图 → DeepSeek Vision API (用户自己的 Key)
              │
              ▼
         返回：地点名 + 坐标 + 简短描述 → 标注 ✓
```

### 7.2 一键生成手帐流程

```
用户选择旅行 → 选择选项
                  │
                  ├── 模板：自动匹配 / 手动选择
                  └── 联网搜索：开 / 关
                  │
                  ▼
           iOS 端整理数据：
           - 旅行时间范围
           - 所有照片的 GPS 地点 + 时间线
           - 用户备注的文字
                  │
                  ▼
           构建 Prompt → DeepSeek Chat API (用户 Key)
           - 联网搜索开启时：调用 DeepSeek 联网能力
                  │
                  ▼
           DeepSeek 返回结构化 JSON：
           {
             pages: [
               { type: "cover", title, subtitle, photoIndex },
               { type: "daily", date, text, photoIndex, layout },
               { type: "gallery", photos, caption },
               ...
             ]
           }
                  │
                  ▼
           iOS 端渲染手帐预览
                  │
                  ▼
           用户确认 / 编辑调整 → 保存 ✓
```

## 8. 手帐模板系统

### 8.1 模板分类（内置 8-10 套）

| 分类 | 适用场景 | 模板名 |
|------|---------|--------|
| 🏙️ 城市漫游 | 城市街拍、建筑 | 「城市漫步」「霓虹都市」 |
| 🏔️ 自然风光 | 山川湖海 | 「山海之间」「森林物语」 |
| 🍜 美食之旅 | 美食打卡 | 「味蕾地图」「深夜食堂」 |
| 🎨 文艺复古 | 人文、博物馆 | 「旧时光」「胶片日记」 |

### 8.2 模板结构定义

```json
{
  "id": "city_walk",
  "name": "城市漫步",
  "category": "city",
  "thumbnailColor": "#2C3E50",
  "pages": [
    { "type": "cover",     "layout": "full_photo_title_overlay" },
    { "type": "daily",     "layout": "photo_left_text_right" },
    { "type": "gallery",   "layout": "three_grid" },
    { "type": "highlight", "layout": "full_width_photo_quote" },
    { "type": "daily",     "layout": "text_left_photo_right" },
    { "type": "ending",    "layout": "summary_stats" }
  ]
}
```

### 8.3 AI 模板匹配

DeepSeek 收到手帐生成请求时，先分析旅行数据中的场景标签（城市/自然/美食比例），然后匹配模板库中最适合的模板。用户也可以手动覆盖选择。

## 9. 手帐渲染

### 9.1 输出形态（支持切换）

- **图文长图**：单张可滚动长图，适合分享朋友圈/小红书
- **杂志翻页**：多页式，左右翻页浏览，像一本迷你杂志

### 9.2 页面类型

| 类型 | 说明 | 示例布局 |
|------|------|---------|
| cover | 封面页 | 满屏照片 + 标题叠加 |
| daily | 日记页 | 照片 + 文字（左右 / 上下 / 对角） |
| gallery | 照片集 | 2/3/4 宫格 |
| highlight | 亮点页 | 单张大图 + 引语 |
| ending | 尾页 | 旅行统计 + 结语 |

### 9.3 渲染方式

优先使用 SwiftUI 原生实现模板渲染（ViewBuilder），备选方案为 WebView 渲染 HTML 模板。最终输出长图通过 ImageRenderer 导出。

## 10. 服务端 API 设计 (概览)

| 端点 | 方法 | 说明 |
|------|------|------|
| `/api/auth/apple` | POST | Apple 登录验证 |
| `/api/trips` | CRUD | 旅行记录同步 |
| `/api/trips/:id/locations` | CRUD | 地点数据同步 |
| `/api/journals` | CRUD | 手帐同步 |
| `/api/templates` | GET | 获取模板列表及配置 |
| `/api/user/social` | CRUD | 社交账号关联（预留） |

所有 API 需要 Bearer Token 认证。

## 11. 待定 / 后续版本

- 小红书 / 微博账号关联与一键分享
- 手帐模板市场（用户自定义模板）
- 协作手帐（多人旅行共用）
- 打印邮寄服务对接
- iPad 适配
- Widget 桌面小组件

## 12. 非功能需求

- **隐私**：照片不离开设备，AI 调用使用用户自己的 API Key
- **离线**：核心功能（地图查看、照片浏览、手帐阅读）离线可用
- **同步**：手帐和元数据在登录后自动同步到服务端
- **性能**：地图标注在 1000+ 点时保持流畅（使用聚合）

## 13. 版本管理策略

- **版本号规则**：采用语义化版本 `主版本.次版本.修订版` (Semantic Versioning)
  - 主版本：重大功能变更或架构调整
  - 次版本：新增功能（新模板、新 Tab、新集成）
  - 修订版：Bug 修复、体验优化
- **起始版本**：`0.1.0`（开发阶段），MVP 发布时为 `1.0.0`
- **CHANGELOG**：每次功能合入记录版本变更，文件位于 `CHANGELOG.md`
