# 旅行手帐 App 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建旅行手帐 iOS App（iOS 17+），含地图足迹、照片库、手帐生成、个人中心四个 Tab，后端 Node.js 部署阿里云 ECS。

**Architecture:** SwiftUI + MVVM 架构的 iOS 原生 App，SwiftData 本地存储，MapKit 地图，Node.js + Express + Prisma + SQLite 服务端，DeepSeek API（用户自带 Key）驱动 AI 功能。

**Tech Stack:** iOS 17+ / SwiftUI / SwiftData / MapKit / Node.js / TypeScript / Express / Prisma / SQLite / DeepSeek API

---

## Phase 1: 项目脚手架

### Task 1.1: 初始化 iOS 项目

**Files:**
- Create: `TravelJournal/` (Xcode 项目目录)
- Create: `TravelJournal/TravelJournalApp.swift`
- Create: `TravelJournal.xcodeproj/`

- [ ] **Step 1: 通过 Xcode 创建新项目**

```
Product Name: TravelJournal
Interface: SwiftUI
Language: Swift
Minimum Deployment: iOS 17.0
Storage: SwiftData (勾选)
Include Tests: Yes
```

- [ ] **Step 2: 创建基础目录结构**

在 `TravelJournal/` 下创建：
```
Models/        - SwiftData 模型
Views/          - 所有 View
  Map/          - 地图 Tab
  Photos/       - 照片库 Tab
  Journal/      - 手帐库 Tab
  Profile/      - 我的 Tab
  Components/   - 复用组件
ViewModels/     - MVVM ViewModels
Services/       - 网络层、AI 服务
Utils/          - 工具类
Resources/      - Assets、模板 JSON
```

- [ ] **Step 3: 验证项目可编译运行**

在 Xcode 中 `Cmd+R` 运行到模拟器，确认空白 App 正常启动。

---

### Task 1.2: 初始化后端项目

**Files:**
- Create: `server/package.json`
- Create: `server/tsconfig.json`
- Create: `server/src/index.ts`

- [ ] **Step 1: 初始化 Node.js 项目**

```bash
mkdir -p server/src
cd server
npm init -y
```

- [ ] **Step 2: 安装依赖**

```bash
cd server
npm install express cors dotenv
npm install -D typescript @types/express @types/cors @types/node ts-node nodemon
npm install prisma @prisma/client
npm install jsonwebtoken @types/jsonwebtoken
```

- [ ] **Step 3: 配置 tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["src/**/*"]
}
```

- [ ] **Step 4: 创建 Express 入口**

`server/src/index.ts`:
```typescript
import express from 'express';
import cors from 'cors';

const app = express();
app.use(cors());
app.use(express.json());

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok' });
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

- [ ] **Step 5: 验证后端可启动**

```bash
cd server
npx ts-node src/index.ts
# 预期：Server running on port 3001
```

---

## Phase 2: 服务端核心

### Task 2.1: Prisma 数据模型与迁移

**Files:**
- Create: `server/prisma/schema.prisma`
- Create: `server/.env`

- [ ] **Step 1: 初始化 Prisma**

```bash
cd server
npx prisma init --datasource-provider sqlite
```

- [ ] **Step 2: 编写 Schema**

`server/prisma/schema.prisma`:
```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "sqlite"
  url      = env("DATABASE_URL")
}

model User {
  id             String          @id @default(uuid())
  appleUserID    String          @unique
  name           String?
  avatarURL      String?
  createdAt      DateTime        @default(now())
  updatedAt      DateTime        @updatedAt
  trips          Trip[]
  socialAccounts SocialAccount[]
}

model Trip {
  id        String     @id @default(uuid())
  userId    String
  name      String
  startDate DateTime
  endDate   DateTime?
  coverURL  String?
  createdAt DateTime   @default(now())
  updatedAt DateTime   @updatedAt
  user      User       @relation(fields: [userId], references: [id])
  locations Location[]
  journals  Journal[]
}

model Location {
  id         String  @id @default(uuid())
  tripId     String
  name       String
  latitude   Float
  longitude  Float
  photoCount Int     @default(0)
  trip       Trip    @relation(fields: [tripId], references: [id])
}

model Journal {
  id          String   @id @default(uuid())
  tripId      String
  title       String
  templateID  String
  contentJSON String
  coverURL    String?
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
  trip        Trip     @relation(fields: [tripId], references: [id])
}

model SocialAccount {
  id          String    @id @default(uuid())
  userId      String
  platform    String
  accountName String?
  connectedAt DateTime?
  user        User      @relation(fields: [userId], references: [id])
}
```

- [ ] **Step 3: 运行迁移**

```bash
cd server
npx prisma migrate dev --name init
# 预期：创建 SQLite 数据库和表
```

---

### Task 2.2: Apple 登录认证 API

**Files:**
- Create: `server/src/middleware/auth.ts`
- Create: `server/src/routes/auth.ts`

- [ ] **Step 1: 创建 JWT 认证中间件**

`server/src/middleware/auth.ts`:
```typescript
import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-change-in-production';

export interface AuthRequest extends Request {
  userId?: string;
}

export function generateToken(userId: string): string {
  return jwt.sign({ userId }, JWT_SECRET, { expiresIn: '30d' });
}

export function authMiddleware(req: AuthRequest, res: Response, next: NextFunction) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) {
    return res.status(401).json({ error: 'No token provided' });
  }
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as { userId: string };
    req.userId = decoded.userId;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
}
```

- [ ] **Step 2: 创建 Auth 路由**

`server/src/routes/auth.ts`:
```typescript
import { Router, Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { generateToken } from '../middleware/auth';

const router = Router();
const prisma = new PrismaClient();

router.post('/apple', async (req: Request, res: Response) => {
  const { appleUserID, name, identityToken } = req.body;
  
  // TODO: 生产环境验证 Apple identityToken
  // 开发阶段直接创建/查找用户
  
  let user = await prisma.user.findUnique({ where: { appleUserID } });
  if (!user) {
    user = await prisma.user.create({
      data: { appleUserID, name: name || '旅行者' }
    });
  }
  
  const token = generateToken(user.id);
  res.json({ token, user: { id: user.id, name: user.name } });
});

export default router;
```

- [ ] **Step 3: 在 index.ts 注册路由**

```typescript
import authRoutes from './routes/auth';
app.use('/api/auth', authRoutes);
```

---

### Task 2.3: 模板 & 旅行 & 手帐 CRUD API

**Files:**
- Create: `server/src/routes/trips.ts`
- Create: `server/src/routes/journals.ts`
- Create: `server/src/routes/templates.ts`

- [ ] **Step 1: 模板列表 API**

`server/src/routes/templates.ts`:
```typescript
import { Router, Response } from 'express';
import { AuthRequest, authMiddleware } from '../middleware/auth';

const router = Router();

// 内置模板数据
const TEMPLATES = [
  {
    id: 'city_walk',
    name: '城市漫步',
    category: 'city',
    description: '适合城市街拍与建筑主题',
    thumbnailColor: '#2C3E50',
    pages: [
      { type: 'cover', layout: 'full_photo_title_overlay' },
      { type: 'daily', layout: 'photo_left_text_right' },
      { type: 'gallery', layout: 'three_grid' },
      { type: 'highlight', layout: 'full_width_photo_quote' },
      { type: 'daily', layout: 'text_left_photo_right' },
      { type: 'ending', layout: 'summary_stats' }
    ]
  },
  {
    id: 'neon_city',
    name: '霓虹都市',
    category: 'city',
    description: '现代都市夜景风格',
    thumbnailColor: '#1A1A2E',
    pages: [
      { type: 'cover', layout: 'full_photo_title_overlay' },
      { type: 'gallery', layout: 'two_grid' },
      { type: 'daily', layout: 'photo_top_text_bottom' },
      { type: 'highlight', layout: 'full_width_photo_quote' },
      { type: 'daily', layout: 'photo_left_text_right' },
      { type: 'ending', layout: 'summary_stats' }
    ]
  },
  {
    id: 'mountain_sea',
    name: '山海之间',
    category: 'nature',
    description: '自然风光与户外旅行',
    thumbnailColor: '#2D6A4F',
    pages: [
      { type: 'cover', layout: 'full_photo_title_overlay' },
      { type: 'highlight', layout: 'full_width_photo_quote' },
      { type: 'daily', layout: 'text_top_photo_bottom' },
      { type: 'gallery', layout: 'three_grid' },
      { type: 'daily', layout: 'photo_left_text_right' },
      { type: 'ending', layout: 'summary_stats' }
    ]
  },
  {
    id: 'forest_tale',
    name: '森林物语',
    category: 'nature',
    description: '清新自然风格',
    thumbnailColor: '#40916C',
    pages: [
      { type: 'cover', layout: 'full_photo_title_overlay' },
      { type: 'daily', layout: 'photo_left_text_right' },
      { type: 'gallery', layout: 'two_grid' },
      { type: 'daily', layout: 'text_left_photo_right' },
      { type: 'highlight', layout: 'full_width_photo_quote' },
      { type: 'ending', layout: 'summary_stats' }
    ]
  },
  {
    id: 'taste_map',
    name: '味蕾地图',
    category: 'food',
    description: '美食探店记录',
    thumbnailColor: '#E07A5F',
    pages: [
      { type: 'cover', layout: 'full_photo_title_overlay' },
      { type: 'gallery', layout: 'three_grid' },
      { type: 'daily', layout: 'photo_left_text_right' },
      { type: 'gallery', layout: 'two_grid' },
      { type: 'daily', layout: 'text_left_photo_right' },
      { type: 'ending', layout: 'summary_stats' }
    ]
  },
  {
    id: 'night_canteen',
    name: '深夜食堂',
    category: 'food',
    description: '温暖治愈系美食',
    thumbnailColor: '#3D405B',
    pages: [
      { type: 'cover', layout: 'full_photo_title_overlay' },
      { type: 'daily', layout: 'text_top_photo_bottom' },
      { type: 'highlight', layout: 'full_width_photo_quote' },
      { type: 'gallery', layout: 'two_grid' },
      { type: 'daily', layout: 'photo_left_text_right' },
      { type: 'ending', layout: 'summary_stats' }
    ]
  },
  {
    id: 'old_days',
    name: '旧时光',
    category: 'vintage',
    description: '复古胶片风格',
    thumbnailColor: '#8B5E3C',
    pages: [
      { type: 'cover', layout: 'full_photo_title_overlay' },
      { type: 'daily', layout: 'photo_left_text_right' },
      { type: 'daily', layout: 'text_left_photo_right' },
      { type: 'highlight', layout: 'full_width_photo_quote' },
      { type: 'gallery', layout: 'two_grid' },
      { type: 'ending', layout: 'summary_stats' }
    ]
  },
  {
    id: 'film_diary',
    name: '胶片日记',
    category: 'vintage',
    description: '文艺人文游记',
    thumbnailColor: '#6B705C',
    pages: [
      { type: 'cover', layout: 'full_photo_title_overlay' },
      { type: 'daily', layout: 'text_left_photo_right' },
      { type: 'gallery', layout: 'three_grid' },
      { type: 'daily', layout: 'photo_left_text_right' },
      { type: 'highlight', layout: 'full_width_photo_quote' },
      { type: 'ending', layout: 'summary_stats' }
    ]
  }
];

router.get('/', authMiddleware, (req: AuthRequest, res: Response) => {
  res.json({ templates: TEMPLATES });
});

export default router;
```

- [ ] **Step 2: 旅行 CRUD API**

`server/src/routes/trips.ts`:
```typescript
import { Router, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { AuthRequest, authMiddleware } from '../middleware/auth';

const router = Router();
const prisma = new PrismaClient();

router.use(authMiddleware);

router.get('/', async (req: AuthRequest, res: Response) => {
  const trips = await prisma.trip.findMany({
    where: { userId: req.userId },
    orderBy: { startDate: 'desc' },
    include: { locations: true, journals: true }
  });
  res.json({ trips });
});

router.post('/', async (req: AuthRequest, res: Response) => {
  const { name, startDate, endDate, coverURL } = req.body;
  const trip = await prisma.trip.create({
    data: { userId: req.userId!, name, startDate: new Date(startDate), endDate: endDate ? new Date(endDate) : null, coverURL }
  });
  res.json({ trip });
});

router.put('/:id', async (req: AuthRequest, res: Response) => {
  const { id } = req.params;
  const { name, startDate, endDate, coverURL } = req.body;
  const trip = await prisma.trip.update({
    where: { id, userId: req.userId },
    data: { name, startDate: startDate ? new Date(startDate) : undefined, endDate: endDate ? new Date(endDate) : undefined, coverURL }
  });
  res.json({ trip });
});

router.delete('/:id', async (req: AuthRequest, res: Response) => {
  await prisma.trip.delete({ where: { id: req.params.id, userId: req.userId } });
  res.json({ success: true });
});

// 地点
router.post('/:id/locations', async (req: AuthRequest, res: Response) => {
  const { name, latitude, longitude } = req.body;
  const location = await prisma.location.create({
    data: { tripId: req.params.id, name, latitude, longitude }
  });
  res.json({ location });
});

router.delete('/:tripId/locations/:locId', async (req: AuthRequest, res: Response) => {
  await prisma.location.delete({ where: { id: req.params.locId } });
  res.json({ success: true });
});

export default router;
```

- [ ] **Step 3: 手帐 CRUD API**

`server/src/routes/journals.ts`:
```typescript
import { Router, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { AuthRequest, authMiddleware } from '../middleware/auth';

const router = Router();
const prisma = new PrismaClient();

router.use(authMiddleware);

router.get('/', async (req: AuthRequest, res: Response) => {
  const journals = await prisma.journal.findMany({
    where: { trip: { userId: req.userId } },
    orderBy: { createdAt: 'desc' },
    include: { trip: true }
  });
  res.json({ journals });
});

router.post('/', async (req: AuthRequest, res: Response) => {
  const { tripId, title, templateID, contentJSON, coverURL } = req.body;
  const journal = await prisma.journal.create({
    data: { tripId, title, templateID, contentJSON, coverURL }
  });
  res.json({ journal });
});

router.put('/:id', async (req: AuthRequest, res: Response) => {
  const { title, contentJSON, coverURL } = req.body;
  const journal = await prisma.journal.update({
    where: { id: req.params.id },
    data: { title, contentJSON, coverURL }
  });
  res.json({ journal });
});

router.delete('/:id', async (req: AuthRequest, res: Response) => {
  await prisma.journal.delete({ where: { id: req.params.id } });
  res.json({ success: true });
});

export default router;
```

- [ ] **Step 4: 注册所有路由**

在 `server/src/index.ts`:
```typescript
import tripRoutes from './routes/trips';
import journalRoutes from './routes/journals';
import templateRoutes from './routes/templates';

app.use('/api/auth', authRoutes);
app.use('/api/trips', tripRoutes);
app.use('/api/journals', journalRoutes);
app.use('/api/templates', templateRoutes);
```

- [ ] **Step 5: 验证 API**

启动服务器后用 curl 测试：
```bash
curl http://localhost:3001/api/health
curl -X POST http://localhost:3001/api/auth/apple -H "Content-Type: application/json" -d '{"appleUserID":"test-001","name":"测试"}'
```

---

## Phase 3: iOS 基础框架

### Task 3.1: SwiftData 模型定义

**Files:**
- Create: `TravelJournal/Models/Trip.swift`
- Create: `TravelJournal/Models/Photo.swift`
- Create: `TravelJournal/Models/Journal.swift`

- [ ] **Step 1: 定义 Trip 模型**

`TravelJournal/Models/Trip.swift`:
```swift
import Foundation
import SwiftData

@Model
final class Trip {
    var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date?
    var coverPhotoLocalID: String?
    var serverID: String?
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade) var photos: [PhotoItem]?
    @Relationship(deleteRule: .cascade) var journals: [JournalEntry]?
    
    init(name: String, startDate: Date, coverPhotoLocalID: String? = nil) {
        self.id = UUID()
        self.name = name
        self.startDate = startDate
        self.coverPhotoLocalID = coverPhotoLocalID
        self.createdAt = Date()
    }
}
```

- [ ] **Step 2: 定义 Photo 模型**

`TravelJournal/Models/PhotoItem.swift`:
```swift
import Foundation
import SwiftData

@Model
final class PhotoItem {
    var id: UUID
    var localAssetID: String
    var gpsLatitude: Double?
    var gpsLongitude: Double?
    var timestamp: Date
    var locationName: String?
    var trip: Trip?
    var serverID: String?
    
    init(localAssetID: String, timestamp: Date, gpsLatitude: Double? = nil, gpsLongitude: Double? = nil) {
        self.id = UUID()
        self.localAssetID = localAssetID
        self.timestamp = timestamp
        self.gpsLatitude = gpsLatitude
        self.gpsLongitude = gpsLongitude
    }
}
```

- [ ] **Step 3: 定义 Journal 模型**

`TravelJournal/Models/JournalEntry.swift`:
```swift
import Foundation
import SwiftData

@Model
final class JournalEntry {
    var id: UUID
    var title: String
    var templateID: String
    var contentJSON: Data
    var coverImagePath: String?
    var trip: Trip?
    var serverID: String?
    var createdAt: Date
    var updatedAt: Date
    
    init(title: String, templateID: String, contentJSON: Data) {
        self.id = UUID()
        self.title = title
        self.templateID = templateID
        self.contentJSON = contentJSON
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
```

---

### Task 3.2: 网络层与 Keychain

**Files:**
- Create: `TravelJournal/Services/APIClient.swift`
- Create: `TravelJournal/Services/KeychainManager.swift`

- [ ] **Step 1: API Client 基础封装**

`TravelJournal/Services/APIClient.swift`:
```swift
import Foundation

enum APIError: Error {
    case invalidURL
    case noToken
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int)
}

class APIClient {
    static let shared = APIClient()
    private let baseURL = "http://8.136.157.93:8080/api"
    private var token: String?
    
    private init() {}
    
    func setToken(_ token: String?) {
        self.token = token
    }
    
    func request<T: Decodable>(_ endpoint: String, method: String = "GET", body: Data? = nil) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        guard let token = token else {
            throw APIError.noToken
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode >= 400 {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func requestWithoutAuth<T: Decodable>(_ endpoint: String, method: String = "GET", body: Data? = nil) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode >= 400 {
            throw APIError.serverError(httpResponse.statusCode)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
```

- [ ] **Step 2: Keychain 管理器**

`TravelJournal/Services/KeychainManager.swift`:
```swift
import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {}
    
    func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

---

### Task 3.3: TabView 基础结构

**Files:**
- Create: `TravelJournal/Views/ContentView.swift`
- Create: `TravelJournal/Views/Map/MapView.swift`
- Create: `TravelJournal/Views/Photos/PhotosView.swift`
- Create: `TravelJournal/Views/Journal/JournalListView.swift`
- Create: `TravelJournal/Views/Profile/ProfileView.swift`

- [ ] **Step 1: ContentView + TabView**

`TravelJournal/Views/ContentView.swift`:
```swift
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MapView()
                .tabItem {
                    Label("地图", systemImage: "map.fill")
                }
                .tag(0)
            
            PhotosView()
                .tabItem {
                    Label("照片库", systemImage: "photo.on.rectangle.fill")
                }
                .tag(1)
            
            JournalListView()
                .tabItem {
                    Label("手帐库", systemImage: "book.fill")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(3)
        }
        .tint(.blue)
    }
}
```

- [ ] **Step 2: 四个占位 View**

每个 View 最小实现：
```swift
// MapView.swift
import SwiftUI
struct MapView: View {
    var body: some View {
        NavigationStack {
            Text("地图 Tab")
                .navigationTitle("旅行地图")
        }
    }
}

// PhotosView.swift - 同结构，标题"照片库"
// JournalListView.swift - 同结构，标题"手帐库"
// ProfileView.swift - 同结构，标题"我的"
```

- [ ] **Step 3: 更新 App 入口**

`TravelJournal/TravelJournalApp.swift`:
```swift
import SwiftUI
import SwiftData

@main
struct TravelJournalApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Trip.self, PhotoItem.self, JournalEntry.self])
    }
}
```

- [ ] **Step 4: 编译运行验证**

在 Xcode 中 `Cmd+R`，确认四个 Tab 可切换。

---

## Phase 4: 地图 Tab

### Task 4.1: 地图标注与交互

**Files:**
- Create: `TravelJournal/ViewModels/MapViewModel.swift`
- Modify: `TravelJournal/Views/Map/MapView.swift`

- [ ] **Step 1: MapViewModel**

`TravelJournal/ViewModels/MapViewModel.swift`:
```swift
import Foundation
import MapKit
import SwiftData

@MainActor
class MapViewModel: ObservableObject {
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.0, longitude: 105.0),
        span: MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 40)
    )
    @Published var locations: [MapLocation] = []
    
    struct MapLocation: Identifiable {
        let id: String
        let name: String
        let coordinate: CLLocationCoordinate2D
        let photoCount: Int
        let tripName: String
    }
    
    func loadLocations(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Trip>()
        guard let trips = try? modelContext.fetch(descriptor) else { return }
        
        var mapLocations: [MapLocation] = []
        for trip in trips {
            guard let photos = trip.photos else { continue }
            let withGPS = photos.filter { $0.gpsLatitude != nil && $0.gpsLongitude != nil }
            
            // 按地点名聚合
            let grouped = Dictionary(grouping: withGPS) { $0.locationName ?? "未知地点" }
            for (name, group) in grouped {
                let avgLat = group.compactMap { $0.gpsLatitude }.reduce(0, +) / Double(group.count)
                let avgLon = group.compactMap { $0.gpsLongitude }.reduce(0, +) / Double(group.count)
                mapLocations.append(MapLocation(
                    id: "\(trip.id)-\(name)",
                    name: name,
                    coordinate: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                    photoCount: group.count,
                    tripName: trip.name
                ))
            }
        }
        locations = mapLocations
    }
}
```

- [ ] **Step 2: 更新 MapView**

`TravelJournal/Views/Map/MapView.swift`:
```swift
import SwiftUI
import MapKit
import SwiftData

struct MapView: View {
    @StateObject private var viewModel = MapViewModel()
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack {
            Map(position: .constant(.region(viewModel.region))) {
                ForEach(viewModel.locations) { location in
                    Annotation(location.name, coordinate: location.coordinate) {
                        VStack {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundStyle(.red)
                            Text(location.name)
                                .font(.caption)
                                .fixedSize()
                        }
                        .onTapGesture {
                            // TODO: 弹出地点详情
                        }
                    }
                }
            }
            .mapStyle(.standard)
            .navigationTitle("旅行地图")
            .onAppear {
                viewModel.loadLocations(modelContext: modelContext)
            }
        }
    }
}
```

- [ ] **Step 3: 编译运行验证地图显示**

---

## Phase 5: 照片库 Tab

### Task 5.1: 照片选择与旅行创建

**Files:**
- Create: `TravelJournal/Views/Photos/PhotosPickerView.swift`
- Create: `TravelJournal/Views/Photos/CreateTripView.swift`
- Modify: `TravelJournal/Views/Photos/PhotosView.swift`
- Create: `TravelJournal/ViewModels/PhotosViewModel.swift`

- [ ] **Step 1: PhotosViewModel**

`TravelJournal/ViewModels/PhotosViewModel.swift`:
```swift
import Foundation
import PhotosUI
import SwiftData
import CoreLocation

@MainActor
class PhotosViewModel: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var selectedPhotos: [PhotosPickerItem] = []
    @Published var isCreatingTrip = false
    @Published var selectedTrip: Trip?
    
    func loadTrips(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Trip>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        trips = (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func importPhotos(_ items: [PhotosPickerItem], to trip: Trip, modelContext: ModelContext) async {
        for item in items {
            guard let assetID = item.itemIdentifier,
                  let contentType = item.supportedContentTypes.first else { continue }
            
            // 提取创建时间
            var timestamp = Date()
            if let creationDate = try? await item.loadTransferable(type: Data.self) {
                // 通过 PHAsset 获取元数据
            }
            
            // 通过 PHAsset 获取 GPS
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
            var lat: Double?, lon: Double?
            if let asset = fetchResult.firstObject, let location = asset.location {
                lat = location.coordinate.latitude
                lon = location.coordinate.longitude
                timestamp = asset.creationDate ?? Date()
            }
            
            let photo = PhotoItem(
                localAssetID: assetID,
                timestamp: timestamp,
                gpsLatitude: lat,
                gpsLongitude: lon
            )
            
            // 反向地理编码
            if let lat = lat, let lon = lon {
                let geocoder = CLGeocoder()
                if let placemarks = try? await geocoder.reverseGeocodeLocation(
                    CLLocation(latitude: lat, longitude: lon)
                ), let placemark = placemarks.first {
                    photo.locationName = [placemark.locality, placemark.country]
                        .compactMap { $0 }
                        .joined(separator: ", ")
                }
            }
            
            photo.trip = trip
            modelContext.insert(photo)
        }
        try? modelContext.save()
    }
}
```

- [ ] **Step 2: PhotosView 主界面**

`TravelJournal/Views/Photos/PhotosView.swift`:
```swift
import SwiftUI
import SwiftData

struct PhotosView: View {
    @StateObject private var viewModel = PhotosViewModel()
    @Environment(\.modelContext) private var modelContext
    @State private var showCreateTrip = false
    
    var body: some View {
        NavigationStack {
            List {
                if viewModel.trips.isEmpty {
                    ContentUnavailableView(
                        "还没有旅行记录",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("创建你的第一次旅行吧")
                    )
                }
                ForEach(viewModel.trips) { trip in
                    NavigationLink(destination: TripDetailView(trip: trip)) {
                        TripRowView(trip: trip)
                    }
                }
                .onDelete(perform: deleteTrips)
            }
            .navigationTitle("照片库")
            .toolbar {
                Button(action: { showCreateTrip = true }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showCreateTrip) {
                CreateTripView { name, startDate in
                    let trip = Trip(name: name, startDate: startDate)
                    modelContext.insert(trip)
                    try? modelContext.save()
                    viewModel.loadTrips(modelContext: modelContext)
                }
            }
            .onAppear {
                viewModel.loadTrips(modelContext: modelContext)
            }
        }
    }
    
    func deleteTrips(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(viewModel.trips[index])
        }
    }
}

struct TripRowView: View {
    let trip: Trip
    
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(Image(systemName: "photo"))
            VStack(alignment: .leading) {
                Text(trip.name).font(.headline)
                Text(trip.startDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption).foregroundStyle(.secondary)
                Text("\(trip.photos?.count ?? 0) 张照片")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
```

- [ ] **Step 3: CreateTripView**

`TravelJournal/Views/Photos/CreateTripView.swift`:
```swift
import SwiftUI

struct CreateTripView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tripName = ""
    @State private var startDate = Date()
    let onCreate: (String, Date) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("旅行名称", text: $tripName)
                DatePicker("出发日期", selection: $startDate, displayedComponents: .date)
            }
            .navigationTitle("新建旅行")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        guard !tripName.isEmpty else { return }
                        onCreate(tripName, startDate)
                        dismiss()
                    }
                    .disabled(tripName.isEmpty)
                }
            }
        }
    }
}
```

- [ ] **Step 4: TripDetailView (照片详情 + 添加照片)**

`TravelJournal/Views/Photos/TripDetailView.swift`:
```swift
import SwiftUI
import PhotosUI
import SwiftData

struct TripDetailView: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isImporting = false
    
    var sortedPhotos: [PhotoItem] {
        (trip.photos ?? []).sorted { ($0.timestamp) > ($1.timestamp) }
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 4) {
                ForEach(sortedPhotos) { photo in
                    PhotoThumbnailView(assetID: photo.localAssetID)
                        .frame(height: 100)
                        .clipped()
                        .overlay(alignment: .bottomLeading) {
                            if let loc = photo.locationName {
                                Text(loc)
                                    .font(.caption2)
                                    .padding(4)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .padding(4)
                            }
                        }
                }
            }
            .padding(4)
        }
        .navigationTitle(trip.name)
        .toolbar {
            PhotosPicker(selection: $selectedItems, matching: .images) {
                Image(systemName: "plus")
            }
        }
        .onChange(of: selectedItems) { _, newItems in
            Task {
                isImporting = true
                let vm = PhotosViewModel()
                await vm.importPhotos(newItems, to: trip, modelContext: modelContext)
                selectedItems = []
                isImporting = false
            }
        }
    }
}

struct PhotoThumbnailView: View {
    let assetID: String
    @State private var image: Image?
    
    var body: some View {
        Group {
            if let image = image {
                image.resizable().scaledToFill()
            } else {
                Color.gray.opacity(0.2)
                    .overlay(ProgressView())
            }
        }
        .task {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
            guard let asset = fetchResult.firstObject else { return }
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isSynchronous = false
            // Use async request
            manager.requestImage(for: asset, targetSize: CGSize(width: 200, height: 200),
                                 contentMode: .aspectFill, options: options) { result, _ in
                if let result = result {
                    image = Image(uiImage: result)
                }
            }
        }
    }
}
```

- [ ] **Step 5: 编译运行验证照片库功能**

---

## Phase 6: 手帐 Tab

### Task 6.1: DeepSeek AI 服务

**Files:**
- Create: `TravelJournal/Services/DeepSeekService.swift`

- [ ] **Step 1: DeepSeek API 封装**

`TravelJournal/Services/DeepSeekService.swift`:
```swift
import Foundation

struct DeepSeekMessage: Codable {
    let role: String
    let content: String
}

struct DeepSeekRequest: Codable {
    let model: String
    let messages: [DeepSeekMessage]
    let max_tokens: Int
}

struct DeepSeekResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

class DeepSeekService {
    static let shared = DeepSeekService()
    private let baseURL = "https://api.deepseek.com/v1"
    
    func getAPIKey() -> String? {
        KeychainManager.shared.get(key: "deepseek_api_key")
    }
    
    func chat(messages: [DeepSeekMessage], maxTokens: Int = 4096) async throws -> String {
        guard let apiKey = getAPIKey() else {
            throw NSError(domain: "DeepSeek", code: -1, userInfo: [NSLocalizedDescriptionKey: "未设置 API Key"])
        }
        
        let request = DeepSeekRequest(model: "deepseek-chat", messages: messages, max_tokens: maxTokens)
        let body = try JSONEncoder().encode(request)
        
        var urlRequest = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = body
        
        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        let response = try JSONDecoder().decode(DeepSeekResponse.self, from: data)
        return response.choices.first?.message.content ?? ""
    }
}
```

- [ ] **Step 2: 手帐生成 Prompt Builder**

`TravelJournal/Services/JournalPromptBuilder.swift`:
```swift
import Foundation

struct JournalPage: Codable {
    let type: String         // cover, daily, gallery, highlight, ending
    let layout: String
    let title: String?
    let text: String?
    let photoIndices: [Int]?
    let caption: String?
}

struct JournalContent: Codable {
    let pages: [JournalPage]
}

class JournalPromptBuilder {
    static func buildGenerationPrompt(
        tripName: String,
        startDate: Date,
        locations: [String],
        templateName: String,
        enableWebSearch: Bool
    ) -> [DeepSeekMessage] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy年MM月dd日"
        
        let locationsText = locations.isEmpty ? "未知地点" : locations.joined(separator: "、")
        
        // 构建模板页面结构描述
        let templatePages = getTemplatePageDescriptions()
        
        let systemPrompt = """
        你是一个旅行手帐创作助手。用户会提供旅行信息，请按照指定的模板结构生成手帐内容。

        手帐模板页面结构：\(templatePages)
        
        要求：
        1. 按指定模板结构生成每个页面的内容
        2. 文字风格温暖、有旅行感，每个 daily 页面 80-150 字
        3. 封面标题要吸引人
        4. gallery 页面填充照片索引（数字 0 开始）
        5. 返回严格 JSON，格式为 { "pages": [...] }
        \(enableWebSearch ? "6. 请在内容中融入地点的背景知识、历史故事、旅行小贴士" : "")
        """
        
        let userPrompt = """
        旅行名称：\(tripName)
        出发日期：\(dateFormatter.string(from: startDate))
        访问地点：\(locationsText)
        模板名称：\(templateName)
        """
        
        return [
            DeepSeekMessage(role: "system", content: systemPrompt),
            DeepSeekMessage(role: "user", content: userPrompt)
        ]
    }
    
    static func getTemplatePageDescriptions() -> String {
        """
        - cover: 封面页，布局 full_photo_title_overlay
        - daily: 日记页，布局 photo_left_text_right 或 text_left_photo_right 或 photo_top_text_bottom 或 text_top_photo_bottom
        - gallery: 照片集，布局 two_grid 或 three_grid
        - highlight: 亮点页，布局 full_width_photo_quote
        - ending: 尾页，布局 summary_stats
        """
    }
}
```

---

### Task 6.2: 手帐生成界面

**Files:**
- Create: `TravelJournal/Views/Journal/GenerateJournalView.swift`
- Create: `TravelJournal/ViewModels/JournalViewModel.swift`
- Modify: `TravelJournal/Views/Journal/JournalListView.swift`

- [ ] **Step 1: JournalViewModel**

`TravelJournal/ViewModels/JournalViewModel.swift`:
```swift
import Foundation
import SwiftData

@MainActor
class JournalViewModel: ObservableObject {
    @Published var journals: [JournalEntry] = []
    @Published var isGenerating = false
    @Published var generatedContent: JournalContent?
    @Published var selectedTemplateID = "auto"
    
    struct TemplateInfo: Identifiable {
        let id: String
        let name: String
        let category: String
        let description: String
    }
    
    func loadJournals(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<JournalEntry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        journals = (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func getBuiltInTemplates() -> [TemplateInfo] {
        [
            TemplateInfo(id: "auto", name: "自动匹配", category: "", description: "AI 自动选择最适合的模板"),
            TemplateInfo(id: "city_walk", name: "城市漫步", category: "city", description: "适合城市街拍与建筑主题"),
            TemplateInfo(id: "neon_city", name: "霓虹都市", category: "city", description: "现代都市夜景风格"),
            TemplateInfo(id: "mountain_sea", name: "山海之间", category: "nature", description: "自然风光与户外旅行"),
            TemplateInfo(id: "forest_tale", name: "森林物语", category: "nature", description: "清新自然风格"),
            TemplateInfo(id: "taste_map", name: "味蕾地图", category: "food", description: "美食探店记录"),
            TemplateInfo(id: "night_canteen", name: "深夜食堂", category: "food", description: "温暖治愈系美食"),
            TemplateInfo(id: "old_days", name: "旧时光", category: "vintage", description: "复古胶片风格"),
            TemplateInfo(id: "film_diary", name: "胶片日记", category: "vintage", description: "文艺人文游记")
        ]
    }
    
    func generateJournal(for trip: Trip, enableWebSearch: Bool = false, modelContext: ModelContext) async {
        isGenerating = true
        defer { isGenerating = false }
        
        let photos = trip.photos ?? []
        let locationNames = Array(Set(photos.compactMap { $0.locationName }))
        
        let templateName = selectedTemplateID == "auto"
            ? getTemplates()[0].name  // 第一个作为默认，实际由 AI 匹配
            : getBuiltInTemplates().first { $0.id == selectedTemplateID }?.name ?? "城市漫步"
        
        let messages = JournalPromptBuilder.buildGenerationPrompt(
            tripName: trip.name,
            startDate: trip.startDate,
            locations: locationNames,
            templateName: templateName,
            enableWebSearch: enableWebSearch
        )
        
        do {
            let rawContent = try await DeepSeekService.shared.chat(messages: messages)
            // 提取 JSON
            if let jsonData = extractJSON(from: rawContent),
               let content = try? JSONDecoder().decode(JournalContent.self, from: jsonData) {
                generatedContent = content
                
                // 保存手帐
                let journal = JournalEntry(
                    title: trip.name + " · 旅行手帐",
                    templateID: selectedTemplateID,
                    contentJSON: jsonData
                )
                journal.trip = trip
                modelContext.insert(journal)
                try? modelContext.save()
                loadJournals(modelContext: modelContext)
            }
        } catch {
            print("生成手帐失败: \(error)")
        }
    }
    
    private func extractJSON(from text: String) -> Data? {
        // 尝试从 markdown 代码块中提取
        if let range = text.range(of: "```json\n") {
            let start = text.index(range.upperBound, offsetBy: 0)
            if let endRange = text.range(of: "\n```", range: start..<text.endIndex) {
                let json = String(text[start..<endRange.lowerBound])
                return json.data(using: .utf8)
            }
        }
        // 直接尝试解析
        return text.data(using: .utf8)
    }
}
```

- [ ] **Step 2: GenerateJournalView**

`TravelJournal/Views/Journal/GenerateJournalView.swift`:
```swift
import SwiftUI
import SwiftData

struct GenerateJournalView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = JournalViewModel()
    @State private var enableWebSearch = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("选择模板") {
                    Picker("模板", selection: $viewModel.selectedTemplateID) {
                        ForEach(viewModel.getBuiltInTemplates()) { template in
                            HStack {
                                Text(template.name)
                                if !template.category.isEmpty {
                                    Text("· \(template.category)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tag(template.id)
                        }
                    }
                }
                
                Section("生成选项") {
                    Toggle("联网搜索补充知识", isOn: $enableWebSearch)
                    Text("开启后 DeepSeek 将搜索网络上的地点背景知识，丰富手帐内容")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section {
                    Button(action: {
                        Task {
                            await viewModel.generateJournal(
                                for: trip,
                                enableWebSearch: enableWebSearch,
                                modelContext: modelContext
                            )
                        }
                    }) {
                        if viewModel.isGenerating {
                            HStack {
                                ProgressView()
                                Text("AI 正在为你生成手帐...")
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text("一键生成手帐")
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(viewModel.isGenerating)
                    .tint(.blue)
                }
            }
            .navigationTitle("生成手帐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
```

- [ ] **Step 3: 更新 JournalListView**

```swift
// JournalListView.swift  - 在列表项上添加生成手帐按钮
// 在 TripRowView 或工具栏中增加 NavigationLink 到 GenerateJournalView
```

---

### Task 6.3: 手帐渲染引擎

**Files:**
- Create: `TravelJournal/Views/Journal/JournalReaderView.swift`
- Create: `TravelJournal/Views/Journal/JournalPageRenderer.swift`

- [ ] **Step 1: JournalReaderView (杂志翻页模式)**

`TravelJournal/Views/Journal/JournalReaderView.swift`:
```swift
import SwiftUI

struct JournalReaderView: View {
    let journal: JournalEntry
    @State private var currentPage = 0
    @State private var viewMode: ViewMode = .magazine
    
    enum ViewMode {
        case magazine  // 翻页模式
        case scroll    // 长图模式
    }
    
    var pages: [JournalPage] {
        guard let content = try? JSONDecoder().decode(JournalContent.self, from: journal.contentJSON) else {
            return []
        }
        return content.pages
    }
    
    var body: some View {
        VStack {
            // 模式切换
            Picker("显示模式", selection: $viewMode) {
                Text("翻页").tag(ViewMode.magazine)
                Text("长图").tag(ViewMode.scroll)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            switch viewMode {
            case .magazine:
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        JournalPageView(page: page, trip: journal.trip)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                
            case .scroll:
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                            JournalPageView(page: page, trip: journal.trip)
                                .frame(height: UIScreen.main.bounds.height)
                        }
                    }
                }
            }
        }
        .navigationTitle(journal.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct JournalPageView: View {
    let page: JournalPage
    let trip: Trip?
    
    var body: some View {
        GeometryReader { geo in
            switch page.type {
            case "cover":
                coverPage(size: geo.size)
            case "daily":
                dailyPage(size: geo.size)
            case "gallery":
                galleryPage(size: geo.size)
            case "highlight":
                highlightPage(size: geo.size)
            case "ending":
                endingPage(size: geo.size)
            default:
                dailyPage(size: geo.size)
            }
        }
    }
    
    @ViewBuilder
    func coverPage(size: CGSize) -> some View {
        ZStack {
            Color.black.opacity(0.1)
            VStack(spacing: 16) {
                Text(page.title ?? "")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                if let subtitle = page.text {
                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    func dailyPage(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(page.title ?? "")
                .font(.title2)
                .fontWeight(.semibold)
            Text(page.text ?? "")
                .font(.body)
                .lineSpacing(6)
            Spacer()
        }
        .padding(24)
    }
    
    @ViewBuilder
    func galleryPage(size: CGSize) -> some View {
        VStack(spacing: 4) {
            if let caption = page.caption {
                Text(caption)
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 2), spacing: 4) {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(1, contentMode: .fill)
                        .overlay(Image(systemName: "photo"))
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    @ViewBuilder
    func highlightPage(size: CGSize) -> some View {
        ZStack {
            Color.gray.opacity(0.15)
            VStack(spacing: 8) {
                Text("\"")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text(page.text ?? "")
                    .font(.title3)
                    .italic()
                    .multilineTextAlignment(.center)
            }
            .padding(32)
        }
    }
    
    @ViewBuilder
    func endingPage(size: CGSize) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text(page.title ?? "旅途未完待续")
                .font(.title)
                .fontWeight(.bold)
            Text(page.text ?? "")
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.05))
    }
}
```

- [ ] **Step 2: 编译并验证手帐渲染**

---

## Phase 7: 个人中心

### Task 7.1: Apple 登录与 API Key 设置

**Files:**
- Create: `TravelJournal/Services/AuthManager.swift`
- Modify: `TravelJournal/Views/Profile/ProfileView.swift`

- [ ] **Step 1: AuthManager**

`TravelJournal/Services/AuthManager.swift`:
```swift
import AuthenticationServices
import Foundation

class AuthManager: NSObject, ObservableObject {
    static let shared = AuthManager()
    
    @Published var isLoggedIn = false
    @Published var userName: String?
    
    override private init() {
        super.init()
        isLoggedIn = KeychainManager.shared.get(key: "auth_token") != nil
    }
    
    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userID = appleIDCredential.user
                let fullName = appleIDCredential.fullName
                let name = [fullName?.givenName, fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                
                // TODO: 调服务端 /api/auth/apple 获取 JWT Token
                // 这里先用简化版本
                let token = "jwt-placeholder-\(userID)"
                KeychainManager.shared.save(key: "auth_token", value: token)
                
                DispatchQueue.main.async {
                    self.isLoggedIn = true
                    self.userName = name.isEmpty ? "旅行者" : name
                }
            }
        case .failure(let error):
            print("Apple Sign In failed: \(error)")
        }
    }
    
    func signOut() {
        KeychainManager.shared.delete(key: "auth_token")
        DispatchQueue.main.async {
            self.isLoggedIn = false
            self.userName = nil
        }
    }
}
```

- [ ] **Step 2: ProfileView**

`TravelJournal/Views/Profile/ProfileView.swift`:
```swift
import SwiftUI
import AuthenticationServices

struct ProfileView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var apiKey: String = ""
    @State private var showAPIKeySaved = false
    
    var body: some View {
        NavigationStack {
            List {
                // 登录区域
                Section {
                    if authManager.isLoggedIn {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading) {
                                Text(authManager.userName ?? "旅行者")
                                    .font(.headline)
                                Text("已通过 Apple 登录")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Button("退出登录", role: .destructive) {
                            authManager.signOut()
                        }
                    } else {
                        SignInWithAppleButton { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            authManager.handleAppleSignIn(result)
                        }
                        .frame(height: 44)
                    }
                }
                
                // API 设置
                Section {
                    HStack {
                        TextField("DeepSeek API Key", text: $apiKey)
                            .font(.caption)
                        Button("保存") {
                            if !apiKey.isEmpty {
                                KeychainManager.shared.save(key: "deepseek_api_key", value: apiKey)
                                showAPIKeySaved = true
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    if showAPIKeySaved {
                        Text("✅ API Key 已保存")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                } header: {
                    Text("AI 设置")
                } footer: {
                    Text("在 platform.deepseek.com 获取你的 API Key")
                }
                
                // 关联账号 (预留)
                Section {
                    HStack {
                        Image(systemName: "book.closed")
                            .foregroundStyle(.red)
                        Text("小红书")
                        Spacer()
                        Text("即将上线")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Image(systemName: "ellipsis.bubble")
                            .foregroundStyle(.orange)
                        Text("微博")
                        Spacer()
                        Text("即将上线")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("关联账号")
                }
                
                // 数据管理
                Section {
                    Button("导出所有手帐") {
                        // TODO
                    }
                }
                
                // 关于
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("我的")
            .onAppear {
                apiKey = KeychainManager.shared.get(key: "deepseek_api_key") ?? ""
            }
        }
    }
}
```

- [ ] **Step 3: 编译运行，验证登录和 API Key 设置**

---

## Phase 8: 集成与同步

### Task 8.1: 服务端部署

- [ ] **Step 1: 在服务器上创建项目目录**

参考 `deploy-workbench.md` 的服务器信息：
```bash
ssh -i ~/Downloads/alang-key.pem root@8.136.157.93 "mkdir -p /var/www/travel-journal/server"
```

- [ ] **Step 2: 上传服务端代码并部署**

```bash
# 在本地 server/ 目录
scp -i ~/Downloads/alang-key.pem -r server/src server/prisma server/package.json server/tsconfig.json root@8.136.157.93:/var/www/travel-journal/server/
ssh -i ~/Downloads/alang-key.pem root@8.136.157.93 "cd /var/www/travel-journal/server && npm install && npx prisma migrate deploy && npx tsc"
```

- [ ] **Step 3: PM2 配置与 Nginx 代理**

在服务器上创建 PM2 进程：
```bash
ssh -i ~/Downloads/alang-key.pem root@8.136.157.93 "cd /var/www/travel-journal/server && pm2 start dist/index.js --name travel-journal && pm2 save"
```

Nginx 添加 `/api/v2/` → `localhost:3001` 代理（避免与现有 App 的 `/api/` 冲突）。

- [ ] **Step 4: 验证 API 可访问**

```bash
curl http://8.136.157.93:8080/api/v2/health
# 预期: {"status":"ok"}
```

---

### Task 8.2: iOS 同步功能

- [ ] **Step 1: 在 ViewModel 中添加同步方法**

在需要同步的地方（保存 Trip、Journal 后），调用 APIClient 同步到服务端。

- [ ] **Step 2: 端到端测试**

完整流程：创建旅行 → 添加照片 → 生成手帐 → 查看手帐 → 验证服务端数据。

---

## 实施顺序建议

```
Phase 1 (脚手架) → Phase 2 (后端核心) → Phase 3 (iOS 基础) → 
Phase 4 (地图) + Phase 5 (照片库) → Phase 6 (手帐 + AI) → 
Phase 7 (个人中心) → Phase 8 (部署同步)
```
