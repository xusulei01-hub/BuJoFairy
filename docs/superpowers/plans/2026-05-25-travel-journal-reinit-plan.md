# 旅行手帐 App — 项目重新初始化实施计划

> **日期**: 2026-05-25  
> **目标**: 重新初始化 Xcode 项目，让 iOS App + 本地后端都能编译启动  
> **方案**: 方案 3（重新初始化 Xcode 项目）  
> **验收标准**: 模拟器 4 Tab 正常显示 + 后端 `npx ts-node` 启动无报错

---

## 现状速览

| 项目 | 状态 |
|------|------|
| Swift 源码 | 已完成（15 个文件，代码质量 OK） |
| 后端源码 | 已完成（7 个 TS 文件，编译通过） |
| Xcode 项目 | 结构断裂（源码在根目录，xcodeproj 在子目录，无法编译） |
| 后端运行 | 未启动（`dist/` 为空，未 ts-node 启动过） |
| 端口 3001 | **空闲** ✅ |
| TypeScript 编译 | **无错误** ✅ |

---

## 实施步骤

### Phase 1: 备份与清理

**预计时间**: 5 分钟

- [ ] **1.1 备份现有项目**
  ```bash
  cp -r "TravelJournal" "TravelJournal.backup-$(date +%Y%m%d-%H%M%S)"
  ```

- [ ] **1.2 记录现有文件清单**
  - 列出所有 `.swift` 文件及其当前路径
  - 确认 `Assets.xcassets` 位置

- [ ] **1.3 删除旧的 Xcode 项目**
  - 删除 `TravelJournal/TravelJournal/TravelJournal.xcodeproj`
  - 删除根目录下冗余的 `TravelJournal/TravelJournalApp.swift`、`TravelJournal/ContentView.swift`

---

### Phase 2: 重新初始化 Xcode 项目

**预计时间**: 10 分钟

- [ ] **2.1 创建标准目录结构**
  ```
  TravelJournal/
  ├── TravelJournal.xcodeproj/
  ├── TravelJournal/              ← App Target
  │   ├── TravelJournalApp.swift
  │   ├── Info.plist
  │   ├── Assets.xcassets/
  │   ├── Preview Content/
  │   ├── Models/
  │   ├── Views/
  │   │   ├── Map/
  │   │   ├── Photos/
  │   │   ├── Journal/
  │   │   └── Profile/
  │   ├── ViewModels/
  │   └── Services/
  ├── TravelJournalTests/
  └── TravelJournalUITests/
  ```

- [ ] **2.2 用 xcodebuild/xcodegen 或手动创建项目**
  - 创建新的 iOS App 项目（SwiftUI, iOS 17+, SwiftData）
  - Bundle ID: `com.example.traveljournal`
  - 团队签名: None（模拟器运行无需签名）

- [ ] **2.3 迁移源码文件**
  - 将根目录下的 `Models/*.swift`、`Views/**/*.swift`、`ViewModels/*.swift`、`Services/*.swift` 复制到 `TravelJournal/TravelJournal/` 对应目录
  - 迁移 `Assets.xcassets`
  - 更新 `TravelJournalApp.swift` 中的 `modelContainer` 配置

- [ ] **2.4 调整 ContentView 引用**
  - 根目录原有 `TravelJournal/ContentView.swift` 删除
  - `Views/ContentView.swift` 作为唯一入口

---

### Phase 3: 编译 iOS 项目

**预计时间**: 10 分钟

- [ ] **3.1 xcodebuild 编译**
  ```bash
  cd TravelJournal
  xcodebuild -scheme TravelJournal -destination 'platform=iOS Simulator,name=iPhone 16' clean build
  ```

- [ ] **3.2 修复编译错误**
  - 检查是否有 import 路径问题
  - 检查 SwiftData model 关联是否正确
  - 检查 `@main` 入口是否唯一

- [ ] **3.3 运行到模拟器**
  - 在 Xcode 中 Cmd+R 或命令行启动
  - 验证 4 个 Tab 能正常切换

---

### Phase 4: 启动本地后端

**预计时间**: 5 分钟

- [ ] **4.1 确认环境**
  - 检查 `.env` 文件是否存在
  - 确认 `DATABASE_URL="file:./prisma/dev.db"`

- [ ] **4.2 启动服务**
  ```bash
  cd server
  npx ts-node src/index.ts
  ```

- [ ] **4.3 验证**
  ```bash
  curl http://localhost:3001/api/health
  # 预期: {"status":"ok","timestamp":"..."}
  ```

---

### Phase 5: 端到端联调验证

**预计时间**: 10 分钟

- [ ] **5.1 检查 APIClient 配置**
  - DEBUG 模式下指向 `http://localhost:3001/api` ✅（已正确配置）

- [ ] **5.2 验证登录流程**
  - Apple 登录在模拟器需要配置 Sign In with Apple capability
  - 或直接跳过登录（离线模式），验证后端 health endpoint 可达

- [ ] **5.3 完整跑通清单**
  | 检查项 | 方式 |
  |--------|------|
  | 地图 Tab 打开 | 视觉确认 |
  | 照片库 Tab 打开 | 视觉确认 |
  | 手帐库 Tab 打开 | 视觉确认 |
  | 我的 Tab 打开 | 视觉确认 |
  | 后端健康检查 | `curl localhost:3001/api/health` |

---

## 风险与应对

| 风险 | 概率 | 应对 |
|------|------|------|
| xcodebuild 编译失败 | 中 | 根据错误信息逐个修复 import/依赖 |
| SwiftData model 关联报错 | 低 | 检查 `@Relationship(inverse:)` 语法 |
| 模拟器无法启动 Sign In with Apple | 中 | 暂不验证登录，先保证界面可用 |
| Prisma/dev.db 权限问题 | 低 | 检查 SQLite 文件读写权限 |

---

## 预计总时间

| Phase | 时间 |
|-------|------|
| Phase 1: 备份与清理 | 5 分钟 |
| Phase 2: 重新初始化 Xcode 项目 | 10 分钟 |
| Phase 3: 编译 iOS 项目 | 10 分钟 |
| Phase 4: 启动本地后端 | 5 分钟 |
| Phase 5: 端到端联调 | 10 分钟 |
| **总计** | **~40 分钟** |

---

## 后续可选优化（不在本次范围）

- 目录结构进一步标准化（将 `TravelJournal/` 根目录改名为 `ios/`）
- 添加 SwiftLint / SwiftFormat 代码规范
- 配置 Xcode Cloud CI
- 后端部署到阿里云 ECS
- DeepSeek API 真实联调
