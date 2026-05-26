# 任务计划：TravelJournal macOS 版实现

## 目标
将 iOS TravelJournal 移植为原生 macOS App，接入 Gemini 多模态 AI，支持 Finder + Photos 双来源照片导入。

## 当前阶段
阶段 1

## 各阶段

### 阶段 1：项目搭建
- [x] 新建 macOS App Target (SwiftUI + SwiftData)
- [x] 迁移 Models (Trip, PhotoItem含PhotoSource, JournalEntry, JournalContent)
- [x] 迁移 Services (APIClient, AuthManager, KeychainManager)
- [ ] 配置 App Sandbox 和文件访问权限
- **状态：** in_progress

### 阶段 2：核心框架
- [ ] 实现 NavigationSplitView + SidebarView
- [ ] 实现 PhotoImageProvider 协议 + FileURL/PhotosLibrary 双实现
- [ ] 实现 Finder 导入 (NSOpenPanel + EXIF读取)
- [ ] 实现 Photos 导入 (PhotosPicker/PHAsset)
- [ ] 实现照片网格显示 (PhotosLibraryView + PhotoThumbnailView)
- **状态：** pending

### 阶段 3：手帐系统
- [ ] 迁移 JournalListView
- [ ] 重写 JournalReaderView (NSImage渲染 + NSSharingServicePicker分享)
- [ ] 重写 JournalPageView (NSImage)
- [ ] 迁移 GenerateJournalView
- [ ] 实现手帐导出长图
- **状态：** pending

### 阶段 4：多模态 AI
- [ ] 升级 AIService 支持 inlineData (base64图片)
- [ ] 实现照片压缩 (1024px, JPEG 0.8)
- [ ] 升级 JournalPromptBuilder 多模态 prompt
- [ ] 集成到手帐生成流程 (选3-5张代表性照片)
- **状态：** pending

### 阶段 5：功能补齐
- [ ] Sign in with Apple (macOS版本)
- [ ] 菜单栏 + 快捷键 (⌘N新建, ⌘I导入, ⌘⇧E导出)
- [ ] 拖拽导入 (Finder→App)
- [ ] 设置面板 (API Key, 账号, 数据导出)
- **状态：** pending

### 阶段 6：测试与部署
- [ ] 功能测试 (导入/生成/导出/分享)
- [ ] 后端API连通测试
- [ ] Archive + 签名 + 本地安装
- [ ] 推送GitHub
- **状态：** pending

## 关键问题
1. ~~照片来源: Finder + Photos 双支持, 引用模式~~ ✅ 已确认
2. ~~导航: Sidebar + Detail, 单窗口~~ ✅ 已确认
3. ~~AI模型: Gemini + 多模态~~ ✅ 已确认

## 已做决策
| 决策 | 理由 |
|------|------|
| 原生macOS而非Mac Catalyst | 长期使用的原生体验 |
| 引用模式(不复制文件) | 节省磁盘空间，符合Mac习惯 |
| 两种来源都不复制 | 统一策略，用户选择 |
| Sidebar + Detail导航 | 标准macOS设计 |
| 单窗口 | 和iOS体验最接近，实现简单 |
| Phase 1传3-5张压缩照片 | 控制token和请求大小 |

## 遇到的错误
| 错误 | 尝试次数 | 解决方案 |
|------|---------|---------|
| 无 | - | - |

## 备注
- Design spec: docs/superpowers/specs/2026-05-26-travel-journal-macos-design.md
- 总预估时间: 3-4天
