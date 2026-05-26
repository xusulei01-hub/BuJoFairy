# TravelJournal 大更新代码审查报告

> 日期：2026-05-25  
> 范围：iOS `TravelJournal/TravelJournal/TravelJournal` 与后端 `server`  
> 审查目标：发现大更新后的回归风险、提交风险、缺失测试与可执行修改建议。

## 验证结果

- `server`: `npm run typecheck` 通过。
- `server`: `npm test` 在非沙箱环境通过，4 个测试文件、19 个测试全部通过。
- `iOS`: `xcodebuild build -project TravelJournal/TravelJournal/TravelJournal.xcodeproj -scheme TravelJournal -destination generic/platform=iOS CODE_SIGNING_ALLOWED=NO` 通过。
- 注意：在沙箱内运行后端测试会因 Supertest 监听临时端口触发 `listen EPERM: operation not permitted 0.0.0.0`，这属于环境限制，不是测试逻辑失败。

## 总体评价

这次更新修复了上一轮建议中的多项核心问题：后端增加了 `.env` 加载、Zod 校验、全局错误处理、Prisma 索引、共享 PrismaClient、Vitest/Supertest 测试；iOS 端修复了 Apple 登录携带 `identityToken`、移除了本地伪 token 登录，并切换到 Gemini API。

当前最需要处理的是：后端 `contentJSON` 的 JSON 解析仍会把用户输入错误变成 500、Prisma schema 改了但没有 migration、`.env` 已被 git 跟踪、工作区存在 `AD` 状态的旧 Swift 文件和未忽略的 Xcode 用户文件。

## Findings

### [P1] 无效 `contentJSON` 会绕过 Zod 并返回 500

**位置**
- `server/src/schemas/index.ts:22-28`
- `server/src/routes/journals.ts:28`
- `server/src/routes/journals.ts:53`

**问题**
`createJournalSchema` 和 `updateJournalSchema` 只校验 `contentJSON` 是非空字符串，随后路由直接 `JSON.parse(body.contentJSON)`。如果客户端传入 `"not-json"` 或损坏 JSON，`JSON.parse` 抛出的 `SyntaxError` 会进入全局错误处理，最终返回 500 `INTERNAL_ERROR`。这属于客户端输入错误，应返回 400，并且当前测试只覆盖了空字符串，没有覆盖 malformed JSON。

**建议**
- 在 schema 层用 `z.string().transform(...)` 或 `superRefine` 校验 JSON。
- 更好：把 `contentJSON` schema 定义为 `z.object({ pages: z.array(...) })`，允许服务端直接接收 JSON 对象，而不是字符串。
- 为 `POST /api/journals` 与 `PUT /api/journals/:id` 增加 malformed JSON 返回 400 的测试。

示例方向：

```ts
const journalContentSchema = z.object({
  pages: z.array(z.object({
    type: z.string(),
    layout: z.string(),
    title: z.string().optional().nullable(),
    text: z.string().optional().nullable(),
    photoIndices: z.array(z.number().int().nonnegative()).optional().nullable(),
    caption: z.string().optional().nullable(),
  })),
});
```

### [P1] Prisma schema 已改为 `Json`，但没有提交 migration

**位置**
- `server/prisma/schema.prisma:45-56`
- `server/prisma/` 当前只有 `dev.db` 和 `schema.prisma`

**问题**
`Journal.contentJSON` 从 `String` 改为 `Json`，并新增了多个 `@@index`。但是仓库里没有 `server/prisma/migrations/`。这意味着其他环境拉代码后，数据库结构不会自动升级，部署或测试时可能出现 Prisma Client 与数据库结构不一致。

**建议**
- 执行并提交 migration：`npm run prisma:migrate -- --name journal-json-and-indexes`。
- 确认 `server/prisma/dev.db` 仍被忽略，不提交本地数据库。
- 在 README 或部署文档中写明启动前需要运行 `prisma migrate deploy`。

### [P1] `server/.env` 已被 git 跟踪，存在配置泄漏风险

**位置**
- `server/.env` 已出现在 `git ls-files server/.env`
- `.gitignore:1-8` 没有忽略 `.env`

**问题**
`.env` 被 Git 跟踪，即便目前内容可能只是开发配置，也容易在后续写入真实 `JWT_SECRET`、数据库地址或第三方凭证后泄漏。当前已经新增了 `server/.env.example`，应只保留 example 入库。

**建议**
- 将 `server/.env` 从版本控制移除但保留本地文件：`git rm --cached server/.env`。
- 在 `.gitignore` 增加：

```gitignore
.env
*.env
!*.env.example
```

### [P1] 当前 Git index 有 `AD` 状态文件，提交可能包含意外旧文件

**位置**
- `TravelJournal/TravelJournal/TravelJournal/ContentView.swift`
- `TravelJournal/TravelJournal/TravelJournal/Item.swift`

**问题**
`git status --short` 显示这两个文件是 `AD`，即“已暂存新增，但工作区已删除”。如果直接提交，可能把本应删除的旧 SwiftUI 模板文件提交进去，或让提交内容与实际工作区不一致。

**建议**
- 明确确认这些文件是否应删除。
- 如果应删除，执行 `git add -u TravelJournal/TravelJournal/TravelJournal/ContentView.swift TravelJournal/TravelJournal/TravelJournal/Item.swift` 更新暂存区。
- 提交前再次确认 `git status --short` 不再有 `AD`。

### [P2] Xcode 用户态文件未被正确忽略

**位置**
- `.gitignore:7-8`
- 当前未跟踪：`TravelJournal/TravelJournal/TravelJournal.xcodeproj/xcuserdata/`
- 当前未跟踪：`TravelJournal/TravelJournal/TravelJournal.xcodeproj/project.xcworkspace/xcuserdata/`

**问题**
`.gitignore` 只忽略根层级的 `TravelJournal.xcodeproj/xcuserdata/`，但当前工程在 `TravelJournal/TravelJournal/TravelJournal.xcodeproj`。因此用户态 Xcode 文件仍显示为未跟踪。

**建议**
改为通配忽略：

```gitignore
*.xcodeproj/xcuserdata/
*.xcworkspace/xcuserdata/
**/*.xcodeproj/xcuserdata/
**/*.xcworkspace/xcuserdata/
```

### [P2] `APPLE_CLIENT_ID` 仍回退到占位 Bundle ID

**位置**
- `server/src/routes/auth.ts:10`
- `server/.env.example`
- Xcode project 中 bundle id 仍是 `com.example.TravelJournal`

**问题**
后端已经验证 Apple `identityToken`，这是好事。但 `APPLE_CLIENT_ID` 缺失时仍回退到 `com.example.TravelJournal`，且示例配置也是占位值。生产环境误用默认值会导致 Apple 登录不可用，或者让问题只在上线后暴露。

**建议**
- 与 `JWT_SECRET` 一样，在生产环境强制要求 `APPLE_CLIENT_ID`。
- 将 iOS Bundle ID 与 Apple Developer 配置中的 Service/App ID 对齐。
- `.env.example` 保留占位可以，但注释应强调“必须替换”。

### [P2] API 错误没有 `LocalizedError`，iOS 登录失败文案不可读

**位置**
- `TravelJournal/TravelJournal/TravelJournal/Services/APIClient.swift:3-8`
- `TravelJournal/TravelJournal/TravelJournal/Services/AuthManager.swift:68-70`

**问题**
`AuthManager` 在登录失败时使用 `error.localizedDescription`。`APIError` 没有实现 `LocalizedError`，用户可能看到系统默认的 “The operation couldn’t be completed...” 而不是后端返回的 Apple 验证失败、网络失败或无 token 信息。

**建议**
- 让 `APIError` 实现 `LocalizedError.errorDescription`。
- 对 `serverError(Int, String)` 尝试解析后端 `{ error, code, details }`，展示 `error` 字段。
- `AuthManager.signOut()` 时也清理 `authError`。

### [P2] 手帐阅读器在 View 计算属性里修改 `@State`

**位置**
- `TravelJournal/TravelJournal/TravelJournal/Views/Journal/JournalReaderView.swift:20-28`
- `TravelJournal/TravelJournal/TravelJournal/Views/Journal/JournalReaderView.swift:41-57`

**问题**
`pages` 是计算属性，但 getter 内会写 `decodeError`。虽然当前 generic iOS build 能通过，但 SwiftUI body 渲染期间修改状态容易触发 “Modifying state during view update” 类运行时警告或重复刷新。并且 body 多次读取 `pages`，会重复 decode JSON。

**建议**
- 改成纯计算返回 `Result<[JournalPage], Error>`，不要在 getter 里写 State。
- 或在 `onAppear` / `task(id: journal.id)` 中 decode 一次，保存到 `@State private var pages: [JournalPage]` 与 `decodeError`。
- body 内避免多次调用 `pages`，先绑定到局部常量或状态。

### [P2] 手帐图片渲染同步读取 Photos，可能卡顿

**位置**
- `TravelJournal/TravelJournal/TravelJournal/Views/Journal/JournalReaderView.swift:396-413`

**问题**
`loadPhotoImage` 使用 `PHImageRequestOptions.isSynchronous = true`，且会在 `JournalPageView.body` 渲染过程中调用。手帐页面、长图导出和滚动模式都可能多次触发同步 Photos 读取，照片多时容易造成主线程卡顿。

**建议**
- 抽出异步 `PhotoThumbnailView`，使用 `.task(id:)` 加载图片并缓存。
- 长图导出可先异步预取所需 `UIImage`，再渲染纯 SwiftUI 内容。
- 至少将同步取图限制到后台导出流程，避免常规 body 渲染中同步 I/O。

### [P2] 后端测试 app 与生产 app 重复装配，容易漂移

**位置**
- `server/src/index.ts:10-28`
- `server/test/app.ts:9-24`

**问题**
测试重新创建了一份 Express app 装配逻辑。现在两者基本一致，但未来增加中间件、CORS、限流、错误格式时，测试 app 可能和生产 app 漂移，导致测试通过但真实服务行为不同。

**建议**
- 新增 `server/src/app.ts` 导出 `createApp()`。
- `server/src/index.ts` 只负责加载 env、调用 `createApp()`、`listen()`。
- `server/test/app.ts` 删除，测试直接使用 `createApp()`。

### [P3] Gemini API Key 放在 URL query 中

**位置**
- `TravelJournal/TravelJournal/TravelJournal/Services/AIService.swift:62`

**问题**
`?key=\(apiKey)` 是 Gemini REST API 支持的方式，但 query 更容易出现在代理、系统诊断或错误日志中。当前本地 App 直接调用第三方 API，本身也意味着用户 API Key 暴露在客户端运行环境中。

**建议**
- 如果继续客户端直连，至少用 `URLComponents` 构造 query，避免特殊字符导致 URL 无效。
- 优先考虑后端代理 AI 请求，由服务端保存 Gemini Key、做限流和审计。
- 如果仍由用户自带 Key，UI 中明确说明 Key 仅在本机使用且请求会直接发送给 Google。

## 建议修改顺序

1. 修复 `contentJSON` schema 与 `JSON.parse` 500 问题，并补 malformed JSON 测试。
2. 生成并提交 Prisma migration。
3. 从 Git 移除 `server/.env`，完善 `.gitignore`。
4. 清理 `AD` 状态 Swift 文件和 Xcode `xcuserdata`。
5. 抽出 `createApp()`，让测试和生产共享 Express 装配。
6. 改善 iOS `APIError` 文案、`JournalReaderView` 状态解码、Photos 异步加载。

## 可交给 IDE 的任务提示

```text
请按 docs/code-review-2026-05-25-large-update.md 的 Findings 修复项目。优先处理 P1：
1. 将 server/src/schemas/index.ts 中 journal contentJSON 从非空字符串校验升级为 JSON 结构校验，确保 malformed JSON 返回 400，并为 POST/PUT journals 添加测试。
2. 为 server/prisma/schema.prisma 当前变更生成并提交 migration。
3. 将 server/.env 从 git 跟踪中移除，更新 .gitignore 保留 .env.example。
4. 清理 git status 中 AD 的 Swift 模板文件和未忽略的 Xcode 用户文件。
完成后运行 npm run typecheck、npm test、xcodebuild generic iOS build。
```

