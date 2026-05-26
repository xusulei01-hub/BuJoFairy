# 发现与决策

## 需求
将 iOS TravelJournal 移植为原生 macOS App，解决中国大陆无法直连 Gemini API 的问题（利用 Mac 代理），同时加入多模态 AI 能力。

## 研究发现

### iOS 专属 API 分布
| 文件 | 专属框架 | 具体使用 |
|------|---------|---------|
| JournalReaderView.swift | UIKit | UIImage, UIScreen, UIGraphicsImageRenderer, UIActivityViewController |
| JournalReaderView.swift | Photos | PHPhotoLibrary, PHAssetChangeRequest |
| TripDetailView.swift | PhotosUI | PhotosPicker, PhotosPickerItem |
| PhotosViewModel.swift | PhotosUI | PhotosPickerItem, loadTransferable, itemIdentifier |
| TripDetailView.swift | Photos | PHAsset, PHImageManager |

### 代码统计
- 总 Swift 代码: 2085 行
- View 文件: 9 个
- ViewModel 文件: 3 个
- Service/Model 文件: 5 个

### macOS 兼容性
| 框架 | macOS 支持 | 备注 |
|------|-----------|------|
| SwiftUI | ✅ 11+ | 完全支持 |
| SwiftData | ✅ 14+ | 完全支持 |
| MapKit | ✅ 10.9+ | API 有差异 |
| Photos | ✅ 10.13+ | API 有差异 |
| PhotosUI | ⚠️ 13+ | 行为可能不同 |
| AuthenticationServices | ✅ 10.15+ | Sign in with Apple 支持 |

## 技术决策
| 决策 | 理由 |
|------|------|
| 原生macOS而非Mac Catalyst | 长期使用值得原生体验 |
| 引用模式(不复制文件) | 节省磁盘空间，符合Mac习惯 |
| Sidebar + Detail导航 | 标准macOS设计 |
| 单窗口 | 和iOS体验最接近，实现简单 |
| Gemini多模态Phase 1传3-5张 | 控制token和请求大小 |

## 资源
- Design spec: docs/superpowers/specs/2026-05-26-travel-journal-macos-design.md
- GitHub: https://github.com/xusulei01-hub/BuJoFairy
