# 旅行手帐 App — 代码质量审查报告

> **日期**: 2026-05-25  
> **范围**: iOS (Swift) + 后端 (TypeScript/Node.js)  
> **状态**: 项目已重新初始化，编译通过

---

## 执行摘要

| 维度 | 评分 | 说明 |
|------|------|------|
| **iOS 架构** | B+ | MVVM 分层清晰，但存在错误处理不一致、TODO 未清理 |
| **后端架构** | C+ | 基本功能可用，但存在严重安全和性能隐患 |
| **代码规范** | B | 命名良好，但缺少统一错误处理模式 |
| **安全** | C | 后端存在 IDOR、认证绕过等关键漏洞 |
| **测试覆盖** | F | 零测试 |

---

## iOS 端审查

### 关键问题 (Critical)

#### 1. 静默错误处理 (`try?` 泛滥)

**影响**: 数据操作失败用户无感知，可能导致数据丢失或状态不一致。

**涉及文件**:
- `PhotosViewModel.swift:16` — `try? modelContext.fetch(descriptor)`
- `PhotosViewModel.swift:62` — `try? modelContext.save()`
- `JournalViewModel.swift:22` — `try? modelContext.fetch(descriptor)`
- `JournalViewModel.swift:81` — `try? modelContext.save()`
- `PhotosView.swift:52` — `try? modelContext.save()`
- `JournalListView.swift:39` — `try? modelContext.save()`
- `MapViewModel.swift:20` — `try? modelContext.fetch(descriptor)`

**建议**: 引入统一的错误处理机制，通过 `@Published var errorMessage: String?` 暴露错误给 View 层显示。

```swift
// 推荐模式
@Published var errorMessage: String?

func loadTrips(modelContext: ModelContext) {
    do {
        let descriptor = FetchDescriptor<Trip>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        trips = try modelContext.fetch(descriptor)
    } catch {
        errorMessage = "加载旅行记录失败: \(error.localizedDescription)"
    }
}
```

#### 2. `PhotoThumbnailView` 使用废弃的回调式 API

**文件**: `TripDetailView.swift:131-142`

`PHImageManager.requestImage(for:targetSize:contentMode:options:resultHandler:)` 是旧式回调 API，在 SwiftUI `.task` 中应使用 Swift Concurrency 版本。

**建议**: 使用 `PHImageManager.requestImage(for:targetSize:contentMode:options:)` 的 async 版本（iOS 15+）或包装为 `withCheckedContinuation`。

#### 3. `AuthManager` Apple 登录离线降级逻辑不完整

**文件**: `AuthManager.swift:48-55`

当服务端 API 调用失败时，生成本地 token (`local-xxx`) 并标记为已登录。这会导致后续 API 调用全部失败（因为本地 token 不被服务端认可），但用户界面显示已登录。

**建议**: 离线模式应明确区分，或在登录失败时不标记为已登录。

---

### 中等问题 (Medium)

#### 4. `JournalReaderView` 使用硬编码的 `UIScreen.main.bounds`

**文件**: `JournalReaderView.swift:46`

`UIScreen.main.bounds` 在 iOS 16+ 已被弃用，且不适应多窗口/分屏场景。

**建议**: 使用 `GeometryReader` 获取实际可用空间。

#### 5. `JournalPageView` gallery 页面使用硬编码占位图

**文件**: `JournalReaderView.swift:136-144`

```swift
ForEach(0 ..< 4, id: \.self) { i in
    RoundedRectangle(cornerRadius: 6)
        .fill(Color.gray.opacity(0.15))
        .overlay(Image(systemName: "photo"))
}
```

Gallery 页面固定显示 4 个占位图，没有使用真实的照片数据。应根据 `page.photoIndices` 渲染对应照片。

#### 6. 缺少访问控制修饰符

**文件**: `TripRowView`, `JournalRowView`, `PhotoThumbnailView`, `LocationDetailView`

这些辅助 View 默认 `internal` 访问级别，应从包外不可见。建议添加 `private` 或文件内隔离。

#### 7. `ProfileView` 中的 TODO 未实现

**文件**: `ProfileView.swift:106-108`

```swift
Button("导出所有手帐") {
    // TODO: 实现导出
}
```

#### 8. `GenerateJournalView` 的 `onChange` 在生成成功后自动 dismiss 无用户确认

**文件**: `GenerateJournalView.swift:83-87`

生成成功后直接 dismiss，用户没有机会查看预览。体验上应显示成功提示并允许用户选择是否关闭。

---

### 低优先级 (Low)

#### 9. 硬编码的颜色和字体值

多处使用如 `.blue`, `.gray.opacity(0.15)`, `.system(size: 10)` 等硬编码值。建议引入 `Color` 和 `Font` 扩展统一管理。

#### 10. `APIClient` 的 `AnyEncodable` 实现不完善

**文件**: `APIClient.swift:75-81`

`AnyEncodable` 包装器在编码时若遇到非 `Encodable` 值会静默失败。建议改用类型安全的方式传递请求体。

#### 11. `DeepSeekService` 使用强制解包 `URL(string:)`

**文件**: `DeepSeekService.swift:50`

```swift
var urlRequest = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
```

虽然是常量 URL，但仍应避免强制解包。

---

## 后端审查

### 关键问题 (Critical)

#### 1. 每个路由文件创建独立的 PrismaClient 实例

**影响**: 连接池耗尽、内存泄漏、高负载下数据库挂起。

**涉及文件**: `routes/auth.ts`, `routes/trips.ts`, `routes/journals.ts`

**建议**: 创建单一 `prisma.ts` 模块，所有路由共享同一实例。

```typescript
// prisma/client.ts
import { PrismaClient } from '@prisma/client';
export const prisma = new PrismaClient();
```

#### 2. 资源所有权校验缺失 (IDOR 漏洞)

**影响**: 用户可以读取/修改/删除其他用户的数据。

**涉及文件**:
- `routes/trips.ts:58` — `findUnique` 未过滤 `userId`
- `routes/trips.ts:69` — `deleteMany` 返回 count=0 也返回 success
- `routes/journals.ts:35` — 创建手帐不验证 trip 所有权
- `routes/journals.ts:58-59` — 更新/查询不验证所有权
- `routes/journals.ts:70` — 删除不验证所有权

**建议**: 所有数据操作必须通过 `userId` 过滤，使用 `findFirst` 替代 `findUnique` 并验证返回结果。

#### 3. JWT 密钥硬编码回退值

**文件**: `middleware/auth.ts:4`

```typescript
const JWT_SECRET = process.env.JWT_SECRET || 'travel-journal-dev-secret-2026';
```

生产环境若忘记设置 `JWT_SECRET`，将使用可预测的硬编码密钥，导致任意 token 伪造。

**建议**: 移除回退值，启动时若缺失则抛出错误并终止进程。

#### 4. Apple 登录未验证 identityToken

**文件**: `routes/auth.ts:14-55`

`identityToken` 被接收但从未验证。攻击者可构造任意 `appleUserID` 和 `name` 注册/登录为任意用户。

**建议**: 使用 Apple 的 JWKS 端点验证 JWT 签名。

---

### 中等问题 (Medium)

#### 5. 缺少全局错误处理中间件

**文件**: `index.ts`

未捕获的异常会导致进程崩溃。应添加 Express 错误处理中间件。

#### 6. 数据库缺少索引

**文件**: `prisma/schema.prisma`

外键字段 (`userId`, `tripId`) 缺少 `@index`，导致每次关联查询都全表扫描。

#### 7. `contentJSON` 使用 String 而非 Json 类型

**文件**: `prisma/schema.prisma`

应使用 Prisma 的 `Json` 类型以获得类型安全和查询能力。

#### 8. `Record<string, unknown>` 丢失类型安全

**涉及文件**: `routes/trips.ts:51`, `routes/journals.ts:53`

更新数据使用 `Record<string, unknown>` 替代 Prisma 生成的类型，丧失了 TypeScript 的编译时保护。

#### 9. package.json 缺少实用脚本

缺少 `dev`, `build`, `start`, `db:migrate` 等常用脚本。

---

## 优先级排序

### P0 — 部署前必须修复

| # | 问题 | 端 | 风险 |
|---|------|-----|------|
| 1 | 统一 PrismaClient 实例 | 后端 | 连接池耗尽 |
| 2 | 添加资源所有权校验 | 后端 | 数据泄露/篡改 |
| 3 | 移除 JWT 硬编码回退 | 后端 | 认证绕过 |
| 4 | 实现 Apple Token 验证 | 后端 | 任意用户登录 |
| 5 | 统一错误处理（替换 `try?`） | iOS | 数据丢失/静默失败 |

### P1 — 近期优化

| # | 问题 | 端 |
|---|------|-----|
| 6 | 添加数据库索引 | 后端 |
| 7 | 添加全局错误处理中间件 | 后端 |
| 8 | `PhotoThumbnailView` 改用 async API | iOS |
| 9 | Gallery 页面使用真实照片 | iOS |
| 10 | 添加请求验证 (Zod) | 后端 |

### P2 — 中期改进

| # | 问题 | 端 |
|---|------|-----|
| 11 | 添加单元/集成测试 | 两端 |
| 12 | 引入结构化日志 | 后端 |
| 13 | 统一设计系统（颜色/字体常量） | iOS |
| 14 | `contentJSON` 改为 Json 类型 | 后端 |
| 15 | 添加 rate limiting + helmet | 后端 |

---

## 测试覆盖现状

| 层级 | 状态 |
|------|------|
| iOS 单元测试 | 仅 Xcode 模板生成的空测试 |
| iOS UI 测试 | 仅 Xcode 模板生成的空测试 |
| 后端单元测试 | 无 |
| 后端集成测试 | 无 |
| API 契约测试 | 无 |

---

## 建议的下一步

1. **先修复 P0 安全漏洞**（后端所有权校验 + JWT + Apple 验证）
2. **然后统一 iOS 错误处理模式**
3. **添加最基础的测试**（至少后端 health endpoint + iOS 编译测试）
4. **再逐步推进 P1/P2 项**
