# 宽窄·Orbit 业务后端 TDL 与完成方案

版本：v1.2  
日期：2026-06-04  
依据：[PRODUCT_PRD.md](./PRODUCT_PRD.md)  
适用范围：业务后端、前后端联调、测试与上线

## 1. 目标

将当前 Express 内存 mock server 升级为能够支撑现有 Flutter 前端的正式业务后端。

完成后应满足：

- 现有前端的 `宽窄之间`、`此刻`、`活动`、`我的`、`消息中心`均有真实后端能力支撑。
- `问一问`相关的会话、卦象结构、额度、记录和解读卡数据容器由业务后端支撑。
- 用户、社区、记录、额度、审核和通知数据以业务后端为权威来源。
- 所有关键写操作可幂等、可审计、可测试、可监控。

### 1.1 明确不在本计划范围内

以下能力由独立项目单独开发，不进入本业务后端 TDL、排期和验收：

- 六爻解读生成。
- 追问回复生成。
- 模型调用、模型路由和提示词管理。
- 解读内容 SSE 流式生成。
- 解读内容的高风险降级、情绪陪伴表达和自动脱敏生成。
- 独立解读服务的认证、评测、监控和上线。

业务后端只预留稳定的数据结构和读取边界。独立项目完成后，再单独制定接入与联调计划。

## 2. 当前后端基线

### 2.1 已有能力

- Node.js 18+ 与 Express。
- `/v1/auth`、`/v1/ceremony`、`/v1/feed`、`/v1/profile`、`/v1/activities`、`/v1/emotion`、`/v1/credits` mock 路由。
- 内存数据模拟。
- 仪式解读与追问 SSE 模拟。
- 当前代码中存在不属于业务后端范围的独立解读服务 HTTP 直连逻辑。
- 手工测试清单。
- 启动脚本仍包含来自旧项目的 MongoDB、Redis 启动残留。

### 2.2 主要缺口

- 没有正式数据库、迁移、索引和数据备份策略。
- 没有幂等控制、限流或异步任务处理机制。
- 没有自动化测试、CI、OpenAPI 或契约测试。
- 认证中间件未真正校验 Token。
- 业务路由仍依赖 `userId` 参数和内存对象。
- 当前业务后端包含不属于本项目范围的独立解读服务直连与硬编码账号密码。
- 部分 mock 数据、注释和响应仍包含 `EN` 占位文本。
- 当前 mock 路由、前端服务路径和模块文档目标契约不一致。
- 社区缺少评论、收藏、关注、举报、屏蔽、搜索、作者主页和审核。
- 缺少通知、同频、订单、媒体、帮助反馈等正式模块。
- 缺少社区内容审核、公开内容校验和审核审计。

## 3. 目标架构

```text
Flutter App
    |
    | HTTPS /v1/*
    v
Business Backend (Express)
    |
    |-- PostgreSQL: 权威业务数据、关系、账本、幂等与任务表
    |-- S3 Compatible Storage: 图片与分享卡媒体
    |-- Push Provider: APNs / FCM / 厂商推送
```

### 3.1 技术选型

| 能力 | 选型 | 原因 |
|---|---|---|
| 业务后端 | Node.js 18+、Express、CommonJS | 延续当前代码，减少迁移成本 |
| 数据库 | PostgreSQL | 用户、关注、评论、互动、报名、订单和额度账本均为强关系数据 |
| ORM 与迁移 | Prisma ORM、Prisma Migrate | 提供清晰 Schema、关系约束、迁移和类型安全的数据访问 |
| 异步任务 | PostgreSQL Jobs / Outbox 表 + 独立 Worker 进程 | 首版避免额外队列基础设施，支持通知与审核任务重试 |
| 对象存储 | S3 兼容对象存储 | 媒体上传与 CDN 地址统一，不绑定特定开发存储实现 |
| 认证 | JWT Access Token + Refresh Token | 支撑移动端会话恢复与注销 |
| 密码与敏感值 | 环境变量或 Secret Manager | 禁止硬编码数据库、短信、推送等凭证 |
| 测试 | Node test runner、Supertest、独立 PostgreSQL 测试库 | 保持依赖较轻，覆盖 API 行为与关系约束 |
| API 文档 | OpenAPI 3.1 | 冻结前后端契约并支持契约测试 |
| 日志 | Pino 结构化日志 | 支撑 Request ID 和敏感信息脱敏 |

首版明确不使用：

- MongoDB、Mongoose。
- Redis、ioredis。
- BullMQ 或其他独立消息队列。
- 仅为本项目开发而引入的缓存集群。

PostgreSQL 使用原则：

- 用户、帖子、评论、关注、互动、报名、订单和额度账本必须使用关系表与外键约束。
- 卦象结构、解读卡内容等结构灵活但不参与复杂关联的数据可使用 `JSONB`。
- `JSONB`不得替代用户关系、权限关系、订单状态或账本记录。
- 额度消费、订单状态变更、活动容量和关键计数更新必须使用数据库事务。
- 通用 API 限流优先由部署网关处理；验证码、登录失败等敏感接口使用 PostgreSQL 记录进行业务级限流。

### 3.2 公共 API 口径

正式公共 API 统一使用 `/v1` 前缀。

统一响应格式：

```json
{
  "code": 0,
  "message": "success",
  "data": {},
  "requestId": "req_xxx"
}
```

统一错误码：

| 错误码 | 含义 |
|---|---|
| `0` | 成功 |
| `40001` | 请求参数错误 |
| `40101` | 未登录或 Token 失效 |
| `40301` | 无权限或被限制 |
| `40401` | 资源不存在 |
| `40901` | 状态冲突、重复操作或额度不足 |
| `42901` | 请求频率过高 |
| `50000` | 服务内部错误 |

### 3.3 正式模块路由

| 模块 | 正式路由 |
|---|---|
| 认证 | `/v1/auth` |
| 仪式与记录 | `/v1/ritual` |
| 社区 | `/v1/community` |
| 同频 | `/v1/match` |
| 活动 | `/v1/activities` |
| 通知 | `/v1/notifications` |
| 个人中心 | `/v1/profile` |
| 媒体 | `/v1/media` |
| 额度 | `/v1/credits` |
| 订单 | `/v1/billing` |
| 分享 | `/v1/share` |
| 帮助反馈 | `/v1/support` |

旧路由 `/v1/ceremony` 和 `/v1/feed`仅作为过渡兼容层保留一个版本周期，内部转发到 `/v1/ritual` 和 `/v1/community`，不继续增加新能力。

### 3.4 建议目标文件结构

```text
backend/
├── package.json
├── .env.example
├── docker-compose.yml
├── openapi/
│   └── openapi.yaml
├── prisma/
│   ├── schema.prisma
│   ├── migrations/
│   └── seed.js
├── scripts/
│   └── verify-database.js
├── src/
│   ├── app.js
│   ├── server.js
│   ├── config/
│   │   ├── env.js
│   │   └── constants.js
│   ├── db/
│   │   └── prisma.js
│   ├── middleware/
│   │   ├── auth.js
│   │   ├── error-handler.js
│   │   ├── idempotency.js
│   │   ├── rate-limit.js
│   │   ├── request-id.js
│   │   └── validate.js
│   ├── shared/
│   │   ├── api-error.js
│   │   ├── logger.js
│   │   └── response.js
│   ├── modules/
│   │   ├── auth/
│   │   ├── profile/
│   │   ├── media/
│   │   ├── credits/
│   │   ├── billing/
│   │   ├── ritual/
│   │   ├── community/
│   │   ├── moderation/
│   │   ├── notifications/
│   │   ├── match/
│   │   ├── activities/
│   │   ├── share/
│   │   └── support/
│   ├── integrations/
│   │   ├── object-storage/
│   │   ├── sms/
│   │   ├── social-login/
│   │   └── push/
│   └── workers/
│       ├── moderation-worker.js
│       └── notification-worker.js
└── test/
    ├── helpers/
    ├── contract/
    ├── integration/
    └── unit/
```

文件职责要求：

- `routes`只负责 HTTP 输入输出，不承载业务规则。
- `services`负责业务规则与事务边界。
- `repositories`负责 Prisma 数据访问，不向上层暴露 Prisma 查询细节。
- `integrations`负责外部服务适配，短信、对象存储和推送都可替换。
- `workers`轮询 PostgreSQL Jobs / Outbox 表执行异步任务，不阻塞用户主请求。
- 每个模块内部按 `route.js`、`controller.js`、`service.js`、`repository.js`、`schema.js`组织；简单模块可合并文件，但不得跨模块直接访问 Prisma Client。

## 4. 数据模型与索引

### 4.1 用户域

| Table | 关键字段 | 必需约束与索引 |
|---|---|---|
| `users` | phone、username、avatarUrl、coverUrl、bio、status | phone unique、createdAt |
| `auth_sessions` | userId、refreshTokenHash、expiresAt、revokedAt | userId、refreshTokenHash unique、expiresAt |
| `agreement_consents` | userId、agreementVersion、privacyVersion、consentedAt | userId + consentedAt |
| `profile_settings` | userId、pushEnabled、vibrationEnabled、publicProfile | userId unique |

### 4.2 仪式与解读数据域

| Table | 关键字段 | 必需约束与索引 |
|---|---|---|
| `ritual_sessions` | userId、question、tag、pattern、status、riskLevel | userId + createdAt、status |
| `interpretation_cards` | sessionId、privateContent、communitySafeContent、riskLevel | sessionId unique、createdAt |
| `followup_messages` | sessionId、type、content、createdAt | sessionId + createdAt |
| `emotion_calibrations` | userId、sessionId、feedback、customText | userId + createdAt |
| `safety_assessments` | targetType、targetId、riskLevel、categories、decision | targetType + targetId、createdAt |

### 4.3 社区域

| Table | 关键字段 | 必需约束与索引 |
|---|---|---|
| `community_posts` | authorId、cardId、shareText、coverImageUrl、tabTags、status、metrics | status + createdAt、authorId + createdAt、tabTags |
| `comments` | postId、authorId、parentId、text、status | postId + createdAt、parentId |
| `reactions` | userId、postId、type | userId + postId + type unique |
| `follows` | followerId、followingId | followerId + followingId unique |
| `reports` | reporterId、targetType、targetId、reason、status | reporterId + targetType + targetId + reason unique |
| `blocks` | blockerId、blockedUserId | blockerId + blockedUserId unique |
| `moderation_records` | targetType、targetId、decision、reason、operator | targetType + targetId、createdAt |

### 4.4 同频、活动、通知与资产域

| Table | 关键字段 | 必需约束与索引 |
|---|---|---|
| `same_frequency_unlocks` | userId、deviceId、dateKey、signature | userId + dateKey unique、deviceId + dateKey |
| `activities` | title、status、startAt、capacity | status + startAt |
| `activity_joins` | activityId、userId、status | activityId + userId unique |
| `notifications` | userId、type、title、body、data、readAt、dismissedAt | userId + createdAt、userId + readAt |
| `credit_accounts` | userId、castBalance、followupBalance、isVip、lastResetDate | userId unique |
| `credit_ledger` | userId、type、amount、reason、idempotencyKey | userId + createdAt、idempotencyKey unique |
| `billing_orders` | userId、planId、status、amount、providerOrderId | orderId unique、providerOrderId unique |
| `media_assets` | ownerId、purpose、url、mime、size、status | ownerId + createdAt |
| `support_tickets` | userId、category、content、status | userId + createdAt |
| `idempotency_keys` | userId、scope、key、requestHash、responseBody、expiresAt | userId + scope + key unique、expiresAt |
| `outbox_jobs` | type、payload、status、attempts、availableAt、lockedAt | status + availableAt、createdAt |

## 5. 完整 TDL

任务状态建议使用：`未开始`、`进行中`、`阻塞`、`待验收`、`已完成`。

### 5.1 Phase 0：契约冻结与工程基础

目标：先解决接口口径、测试能力和基础设施问题，避免后续模块重复返工。

| ID | 优先级 | 任务 | 依赖 | 交付物 | 完成定义 |
|---|---|---|---|---|---|
| BE-000 | P0 | 冻结正式公共 API 口径 | PRD | OpenAPI 初版、路由命名决议 | `/v1`、响应格式、错误码、分页、认证头统一 |
| BE-001 | P0 | 重构 Express 启动结构 | BE-000 | `app` 工厂与独立 `server` 启动文件 | 测试可导入 app，不会自动监听端口 |
| BE-002 | P0 | 建立环境配置与 Secret 规范 | 无 | `.env.example`、配置校验 | 缺少必需变量时启动失败，仓库无硬编码凭证 |
| BE-003 | P0 | 接入 PostgreSQL 与 Prisma | BE-002 | Prisma Client、数据库连接、健康检查 | `/health`可区分应用与 PostgreSQL 状态 |
| BE-004 | P0 | 建立 Prisma Schema 与迁移基线 | BE-003 | `schema.prisma`、首个迁移、种子脚本 | 新环境可通过迁移创建完整基础表结构 |
| BE-005 | P0 | 建立统一响应与错误处理中间件 | BE-001 | `ApiError`、响应助手、404 和错误处理 | 所有路由使用统一 envelope 和 requestId |
| BE-006 | P0 | 建立认证中间件 | BE-002、BE-005 | JWT 校验、可选认证、权限门禁 | 受保护路由拒绝无效 Token，不信任 body 中 userId |
| BE-007 | P0 | 建立参数校验 | BE-005 | 请求 Schema 与校验中间件 | 非法请求稳定返回 `40001` |
| BE-008 | P0 | 建立结构化日志与敏感信息脱敏 | BE-005 | Pino 日志、Request ID | 日志不记录完整问题、Token、手机号和密码 |
| BE-009 | P0 | 建立自动化测试框架 | BE-001 | Node test runner、Supertest、测试工具 | `npm test`可运行并至少覆盖健康检查与错误格式 |
| BE-010 | P0 | 建立 CI | BE-009 | lint、test、syntax check 流程 | PR 上自动执行并阻止失败合并 |
| BE-011 | P0 | 清理 `EN` 占位与独立解读服务直连耦合 | BE-002 | 清理后的 mock 数据与业务后端代码 | `rg "EN"`无业务占位，业务后端不再包含独立解读服务账号、密码或直连实现 |
| BE-012 | P0 | 建立 PostgreSQL 开发环境并清理旧启动脚本 | BE-003、BE-004 | PostgreSQL Docker Compose、修订后的启动脚本 | 新开发者可一键启动 PostgreSQL，脚本不再启动 MongoDB 或 Redis |
| BE-013 | P0 | 建立数据库幂等与敏感接口限流 | BE-004、BE-007 | idempotency middleware、验证码限流记录 | 相同 Idempotency-Key 可重放，验证码等敏感接口可限制频率 |
| BE-014 | P0 | 建立 PostgreSQL Outbox / Jobs 机制 | BE-004 | jobs repository、worker 基础进程 | 异步任务可锁定、重试、失败记录且不依赖外部队列 |

Phase 0 验收门槛：

- 不允许继续在内存 `storage` 上开发正式功能。
- 不允许新增未进入 OpenAPI 的公共接口。
- 不允许业务后端继续包含独立解读服务账号、密码或直连实现。

### 5.2 Phase 1：认证、用户、媒体与个人中心

目标：建立所有后续模块依赖的用户身份与媒体能力。

| ID | 优先级 | 任务 | 依赖 | 交付物 | 完成定义 |
|---|---|---|---|---|---|
| AUTH-001 | P0 | 手机验证码发送与验证 | BE-003、BE-013 | `/v1/auth/phone/send-code`、登录接口 | 验证码有 TTL、频率限制、错误次数限制 |
| AUTH-002 | P0 | Access Token 与 Refresh Token | BE-006 | 登录、刷新、注销、会话恢复 | Refresh Token 哈希存储，可吊销 |
| AUTH-003 | P0 | 游客身份与游客升级 | AUTH-002 | 游客 Token、升级合并逻辑 | 登录后可合并游客时期记录且不重复 |
| AUTH-004 | P0 | 协议与隐私版本存证 | AUTH-002 | consent 记录接口与模型 | 每次正式登录可追踪版本和时间 |
| AUTH-005 | P1 | 微信、QQ 社交登录适配层 | AUTH-002 | provider adapter | provider 可替换，业务层不直接依赖 SDK 返回结构 |
| PROFILE-001 | P0 | 获取与更新个人资料 | AUTH-002 | `/v1/profile/me` GET/PUT | 用户只能修改自己的资料 |
| PROFILE-002 | P0 | 媒体上传服务 | BE-012、AUTH-002 | `/v1/media/upload`、S3 兼容存储适配器 | 校验 MIME、大小、用途并返回稳定 URL |
| PROFILE-003 | P1 | 头像与封面更新 | PROFILE-001、PROFILE-002 | 头像、封面接口 | 只允许引用用户自己的已完成媒体 |
| PROFILE-004 | P1 | 用户设置 | PROFILE-001 | `/v1/profile/me/settings` | 通知、震动、公开主页等可同步 |
| PROFILE-005 | P1 | 公开主页与分享链接 | PROFILE-001 | 公开主页查询、分享 URL | 非公开用户不会泄露资料 |
| PROFILE-006 | P1 | 互动记录与浏览记录 | PROFILE-001 | interactions、browse 接口 | 支持分页、清空和跨设备同步 |
| PROFILE-007 | P1 | 账号注销与冷静期 | AUTH-002 | 注销申请、撤销、执行任务 | 注销可审计，冷静期后执行数据处理 |
| SUPPORT-001 | P1 | 帮助与反馈 | AUTH-002 | `/v1/support/feedback` | 可提交工单并返回 ticketId |

### 5.3 Phase 2：额度、会员与订单

目标：建立服务端权威额度账本，避免重复扣费和客户端绕过。

| ID | 优先级 | 任务 | 依赖 | 交付物 | 完成定义 |
|---|---|---|---|---|---|
| CREDIT-001 | P0 | 建立额度账户与账本 | AUTH-002、BE-003 | account、ledger 模型与服务 | 余额变化只能通过账本服务发生 |
| CREDIT-002 | P0 | 每日额度结算 | CREDIT-001 | 服务端每日重置逻辑 | 普通用户与 VIP 策略可配置 |
| CREDIT-003 | P0 | 幂等额度消费 | CREDIT-001、BE-013 | `/v1/credits/consume` | 相同 Idempotency-Key 不重复扣除 |
| CREDIT-004 | P1 | 签到与签到日历 | CREDIT-001 | checkin、calendar 接口 | 同一天签到幂等，奖励进入账本 |
| BILLING-001 | P1 | 会员计划列表 | CREDIT-001 | `/v1/billing/plans` | 计划由服务端配置 |
| BILLING-002 | P1 | 订单创建与查询 | BILLING-001 | order create、get | 创建订单幂等 |
| BILLING-003 | P1 | 支付确认与回调 | BILLING-002 | provider adapter、回调验签 | 客户端不能直接将订单改为 paid |
| BILLING-004 | P1 | VIP 权益生效与过期 | BILLING-003、CREDIT-002 | 权益结算 | 订单、VIP 状态和额度策略一致 |

### 5.4 Phase 3：仪式基础业务与存档

目标：完成 `问一问`所需的业务数据能力，但不实现解读生成与追问生成。

| ID | 优先级 | 任务 | 依赖 | 交付物 | 完成定义 |
|---|---|---|---|---|---|
| RITUAL-001 | P0 | 创建仪式会话 | AUTH-003、CREDIT-003、BE-007 | `POST /v1/ritual/perform` | 保存问题、分类、结构、动爻和会话状态 |
| RITUAL-002 | P0 | 卦象结构持久化与校验 | RITUAL-001 | pattern schema、校验规则 | 只接受完整六段结构与合法动爻 |
| RITUAL-003 | P0 | 解读卡数据模型与存储边界 | RITUAL-001 | privateContent、publicContent 数据结构 | 私密内容与社区公开内容分开存储，业务后端不生成内容 |
| RITUAL-004 | P0 | 解读卡读取权限 | RITUAL-003、AUTH-003 | preview、full-read 读取接口 | 游客与登录用户只能读取允许范围内的数据 |
| RITUAL-005 | P0 | 追问消息数据模型 | RITUAL-001 | message schema、history 读取接口 | 可保存和读取会话消息，但不生成回复 |
| RITUAL-006 | P0 | 心绪存档与会话恢复 | RITUAL-003 | session、history 接口 | 可跨设备恢复，用户只看自己的记录 |
| RITUAL-007 | P0 | 仪式状态机与额度一致性 | RITUAL-001、CREDIT-003 | 状态迁移与补偿规则 | 重试不会重复创建会话或重复扣额 |
| RITUAL-008 | P1 | 每日完成状态 | RITUAL-006 | completion-today 接口 | 与前端今日完成状态一致 |
| RITUAL-009 | P1 | 情绪校准与周期回顾 | RITUAL-006 | calibration、periodic-review | 可生成用户可见的周期数据，不输出评分 |

Phase 3 不实现以下接口行为：

- 不生成首轮解读正文。
- 不生成追问回复。
- 不提供内容生成 SSE。
- 不负责解读内容的自动脱敏或高风险降级。

### 5.5 Phase 4：宽窄之间社区与内容安全

目标：让现有社区 UI 从本地模拟切换到真实数据，并建立社群安全底线。

| ID | 优先级 | 任务 | 依赖 | 交付物 | 完成定义 |
|---|---|---|---|---|---|
| COMMUNITY-001 | P0 | 社区帖子模型与发布 | AUTH-003、PROFILE-002、RITUAL-003 | `POST /v1/community/post` | 支持纯文本、图片、解读卡关联，cardId 可为空 |
| COMMUNITY-002 | P0 | 推荐流与深谈流 | COMMUNITY-001 | `/v1/community/feed` | 支持 recommended、deep、稳定分页 |
| COMMUNITY-003 | P0 | 帖子详情与浏览记录 | COMMUNITY-001 | post detail、view | 浏览计数可去重，详情字段足够前端一次渲染 |
| COMMUNITY-004 | P0 | 评论线程 | COMMUNITY-001 | comment list、create | 支持分页与基础回复链 |
| COMMUNITY-005 | P0 | 点赞与收藏 | COMMUNITY-001 | like、favorite 接口 | 幂等，计数与 viewerState 一致 |
| COMMUNITY-006 | P0 | 发布前内容审核 | COMMUNITY-001 | moderation service | 高风险内容不会直接公开 |
| COMMUNITY-007 | P0 | 解读卡公开版校验 | COMMUNITY-001、RITUAL-003 | safe card validation | 社区接口不能读取私密问题正文 |
| COMMUNITY-008 | P1 | 作者主页与关注 | PROFILE-005、COMMUNITY-001 | author、follow 接口 | 关注幂等，屏蔽关系优先 |
| COMMUNITY-009 | P1 | 举报、不感兴趣与屏蔽 | COMMUNITY-001 | report、hide、block | 举报可审计，屏蔽后隐藏相关内容 |
| COMMUNITY-010 | P1 | 社区搜索 | COMMUNITY-001、ACTIVITY-001 | post、user、activity search | 支持类型筛选和分页 |
| COMMUNITY-011 | P1 | 审核后台最小能力 | COMMUNITY-006、COMMUNITY-009 | 审核列表、处理接口、审计记录 | 可处理举报与自动审核命中内容 |
| COMMUNITY-012 | P1 | Feed 指标一致性 | COMMUNITY-003、COMMUNITY-005 | metrics 聚合策略 | 点赞、收藏、浏览、评论数与真实数据一致 |

### 5.6 Phase 5：通知与消息中心

目标：支持现有顶部通知入口与消息中心 UI。

| ID | 优先级 | 任务 | 依赖 | 交付物 | 完成定义 |
|---|---|---|---|---|---|
| NOTIFY-001 | P1 | 通知模型与事件生产器 | COMMUNITY-004、COMMUNITY-005 | notification service | 评论、点赞、收藏、关注可产生通知 |
| NOTIFY-002 | P1 | 通知列表与未读数 | NOTIFY-001 | list、unread-count | 支持分页与筛选 |
| NOTIFY-003 | P1 | 已读、全部已读与删除 | NOTIFY-002 | read、read-all、dismiss | 操作幂等 |
| NOTIFY-004 | P1 | 推送 Token 注册 | AUTH-002 | token register、unregister | Token 与用户、设备、平台绑定 |
| NOTIFY-005 | P1 | 异步推送任务 | BE-014、NOTIFY-004 | notification worker | 推送失败可重试且不阻塞主请求 |
| NOTIFY-006 | P1 | 活动与系统通知 | ACTIVITY-003 | 状态通知 | 报名状态和系统事件可通知 |

### 5.7 Phase 6：此刻、同频与活动

目标：补齐现有 `此刻`和 `活动`页面的真实后端能力。

| ID | 优先级 | 任务 | 依赖 | 交付物 | 完成定义 |
|---|---|---|---|---|---|
| MATCH-001 | P1 | 同频解锁状态 | AUTH-003、BE-013 | `/v1/match/unlock`、status | 按用户或设备与日期幂等 |
| MATCH-002 | P1 | 今日签名与匹配数据 | MATCH-001、RITUAL-006 | same-frequency list | 返回匹配理由，不返回优劣分数 |
| MATCH-003 | P1 | 历史同频内容 | MATCH-002 | history tab | 支持分页与内容审核 |
| ACTIVITY-001 | P1 | 活动列表与详情 | BE-003 | activity list、detail | 支持前端当前状态字段 |
| ACTIVITY-002 | P1 | 活动管理最小能力 | ACTIVITY-001 | 创建、编辑、状态变更 | 仅授权运营角色可操作 |
| ACTIVITY-003 | P1 | 活动报名与状态 | ACTIVITY-001、AUTH-002 | join、join-status | 同一用户重复报名幂等 |
| ACTIVITY-004 | P1 | 活动参与人数与容量 | ACTIVITY-003 | capacity control | 不超卖，候补状态一致 |

### 5.8 Phase 7：分享、运营能力与数据指标

目标：补齐现有分享卡、帮助反馈和产品指标所需能力。

| ID | 优先级 | 任务 | 依赖 | 交付物 | 完成定义 |
|---|---|---|---|---|---|
| SHARE-001 | P1 | 保存分享卡草稿 | RITUAL-003 | `/v1/share/card/save` | 草稿按用户和 cardId 幂等 |
| SHARE-002 | P1 | 服务端分享卡渲染 | PROFILE-002、SHARE-001 | render endpoint | 输出稳定高分辨率图片 |
| SHARE-003 | P1 | 发布分享卡到社区 | SHARE-001、COMMUNITY-001 | share publish | 返回 canonical postId |
| SHARE-004 | P1 | 外部分享载荷 | SHARE-002 | external payload | 返回分享标题、摘要、链接和图片 |
| ANALYTICS-001 | P1 | 核心事件埋点接收 | BE-008 | event ingest | 支持 PRD 核心漏斗事件 |
| ANALYTICS-002 | P1 | 北极星指标计算 | ANALYTICS-001 | WMRU 统计任务 | 可按周生成有效共鸣用户数 |
| ANALYTICS-003 | P1 | 安全与审核指标 | COMMUNITY-006 | 指标看板数据源 | 可查看审核命中率、举报处理时长和内容下架率 |

### 5.9 Phase 8：生产上线与质量加固

目标：在正式发布前完成性能、安全、迁移和回滚准备。

| ID | 优先级 | 任务 | 依赖 | 交付物 | 完成定义 |
|---|---|---|---|---|---|
| OPS-001 | P0 | 数据迁移与种子数据 | 各模型完成 | migration、seed 脚本 | 可重复执行，失败可回滚 |
| OPS-002 | P0 | 自动化备份与恢复演练 | BE-003 | 备份策略、恢复记录 | 在预发布环境完成一次恢复 |
| OPS-003 | P0 | 安全检查 | 全部 P0 | 依赖审计、Secret 扫描、权限检查 | 无高危未处理问题 |
| OPS-004 | P0 | 性能压测 | RITUAL-002、COMMUNITY-002 | 压测报告 | Feed、评论、仪式会话达到目标容量 |
| OPS-005 | P0 | 灰度开关与回滚 | 全部 P0 | feature flags、回滚手册 | 可单独关闭发布、评论、报名等高风险能力 |
| OPS-006 | P0 | 生产监控与告警 | BE-008 | Dashboard、Alert | 关键错误率和延迟可告警 |
| OPS-007 | P0 | 隐私与数据删除验收 | PROFILE-007 | 数据处理清单 | 注销、删除和日志脱敏符合要求 |
| OPS-008 | P0 | 前后端契约回归 | 全部 P0 | 自动契约测试报告 | 当前 Flutter 页面主链路全部通过 |

### 5.10 Phase 9：P2 长期社区价值

目标：主链路稳定后，增强社区内容沉淀与个人长期价值，不改变当前底部主导航。

| ID | 优先级 | 任务 | 依赖 | 交付物 | 完成定义 |
|---|---|---|---|---|---|
| IDENTITY-001 | P2 | 显式匿名身份 | AUTH-003、PROFILE-001 | anonymous profile 模型与接口 | 用户可管理匿名展示身份，真实账号信息不泄露 |
| COMMUNITY-013 | P2 | 匿名发布与匿名互动 | IDENTITY-001、COMMUNITY-001 | 匿名发布参数与展示逻辑 | 后端仍可审计真实用户，前端只见匿名身份 |
| FEEDBACK-001 | P2 | 解读结果反馈 | RITUAL-006、COMMUNITY-001 | feedback 模型与接口 | 用户可在后续时间补充事情发展与个人感受 |
| COMMUNITY-014 | P2 | 反馈帖与阶段性复盘 | FEEDBACK-001 | 反馈内容展示与关联 | 反馈可关联原会话或原帖子，不泄露私密问题 |
| RECOMMEND-001 | P2 | 推荐与深谈分发深化 | COMMUNITY-012、ANALYTICS-001 | 可解释的分发规则 | 不使用吉凶、命运或人格优劣作为推荐信号 |
| CASE-001 | P2 | 结构化案例检索 | RITUAL-003、COMMUNITY-007 | 案例索引与查询接口 | 只检索公开安全版本，支持问题类型与结构筛选 |
| REVIEW-001 | P2 | 周期性情绪与成长报告 | RITUAL-009、FEEDBACK-001 | 周报、月报数据接口 | 报告不输出评分、诊断或预测结论 |

## 6. 完成方案

### 6.1 推荐交付顺序

严格按以下顺序推进：

1. 冻结 API 契约，建立测试、PostgreSQL、Prisma、认证和日志基础。
2. 完成用户身份、媒体和额度账本。
3. 完成仪式会话、卦象结构、解读卡数据容器和心绪存档。
4. 打通 `发布内容 -> 宽窄之间 -> 评论/点赞/收藏`社区主链路。
5. 接入消息中心、同频、活动、个人中心剩余能力。
6. 完成分享、指标、审核后台和生产加固。

不得先做复杂推荐算法、精细画像或高级运营功能。当前首要目标是让已经完成的前端流程拥有稳定的真实后端。

### 6.2 推荐团队分工

| 角色 | 主要职责 |
|---|---|
| 后端负责人 | 契约冻结、架构边界、代码评审、上线决策 |
| 业务后端 A | 工程基础、认证、个人中心、媒体 |
| 业务后端 B | 仪式会话、额度、存档 |
| 业务后端 C | 社区、通知、活动、同频 |
| 测试工程师 | API、契约、主链路、性能与安全回归 |
| 运维或平台工程师 | PostgreSQL、对象存储、CI/CD、监控 |

团队人数不足时，优先保证业务后端负责人、仪式数据链路和社区链路三个职责，不要并行铺开所有 P1 模块。

### 6.3 推荐里程碑

| 里程碑 | 建议周期 | 范围 | 退出条件 |
|---|---|---|---|
| M0：工程可持续 | 第 1 周 | Phase 0 | 自动测试、PostgreSQL、Prisma、认证骨架可用 |
| M1：身份与账本 | 第 2 周 | Phase 1、Phase 2 P0 | 登录、游客升级、资料、额度可用 |
| M2：仪式数据链路 | 第 3 周 | Phase 3 P0 | 会话、卦象结构、解读卡容器、消息记录和存档通过 |
| M3：社区生产链路 | 第 4 至 5 周 | Phase 4 P0 | 发布、Feed、详情、评论、点赞、收藏可用 |
| M4：现有 UI 业务能力接入 | 第 6 至 7 周 | Phase 5、Phase 6、Phase 7 P1 | 消息、同频、活动、个人中心主要功能可用 |
| M5：上线准备 | 第 8 周 | Phase 8 | 安全、压测、监控、回滚、契约回归通过 |

周期以 3 名业务后端、1 名测试工程师为参考。人员减少时应延长周期，不应降低 P0 的测试和安全要求。

### 6.4 每个任务的 Definition of Done

任何任务只有同时满足以下条件才可标记为已完成：

- 实现代码已合并。
- OpenAPI 或模块契约文档已更新。
- 参数校验、权限校验和错误码已定义。
- 单元测试与 API 集成测试通过。
- 关键写操作已验证幂等性。
- 日志不包含敏感信息。
- 对应前端页面已完成联调或提供可验证的 API 示例。
- 监控指标或至少结构化日志已覆盖。
- 无未解释的占位注释、`EN` 占位或硬编码凭证。

### 6.5 测试策略

#### 单元测试

覆盖：

- 输入校验。
- 权限判断。
- 额度账本。
- 社区互动幂等。
- 仪式状态迁移。
- 私密内容与公开内容读取边界。
- 社区内容审核规则。

#### API 集成测试

覆盖：

- 登录、刷新、注销和游客升级。
- 仪式创建、卦象结构、解读卡读取、消息历史和存档恢复。
- 社区发布、Feed、详情、评论、点赞、收藏。
- 通知列表、已读和删除。
- 同频解锁与活动报名。
- 媒体上传和资料更新。

#### 契约测试

覆盖：

- Flutter 当前使用字段。
- OpenAPI 响应结构。
- 仪式、社区、通知等业务 API 数据结构。

#### 安全测试

覆盖：

- 无 Token、过期 Token、越权访问。
- 重放 Idempotency-Key。
- 上传非法文件。
- 高频验证码和评论请求。
- 私密解读通过社区接口泄露。
- 未审核或不可公开内容通过社区接口发布。

#### 性能测试

最低目标建议：

| 场景 | 目标 |
|---|---|
| Feed 列表 P95 | 小于 500ms，不含外部 CDN |
| 帖子详情 P95 | 小于 400ms |
| 评论创建 P95 | 小于 500ms |
| 仪式会话创建 P95 | 小于 500ms |
| 非媒体业务 API 错误率 | 小于 0.5% |

### 6.6 联调方案

每个模块按以下方式联调：

1. 后端先提供 OpenAPI、示例请求和测试账号。
2. 后端在预发布环境部署真实 API。
3. 前端通过环境变量切换到预发布后端。
4. 按现有页面逐项验证正常、空、错误、超时和重试状态。
5. 发现字段不一致时修改正式契约，不在客户端临时增加长期兼容分支。
6. 模块验收后关闭对应本地 mock 默认路径，但保留开发降级开关。

### 6.7 数据迁移方案

当前内存 mock 数据不作为生产用户数据迁移。

迁移步骤：

1. 建立 PostgreSQL tables、关系约束与索引。
2. 编写可重复执行的 Prisma migration 与基础种子数据脚本。
3. 只导入用于演示的社区内容、活动和系统配置。
4. 所有种子用户标记为测试账号，不与真实手机号绑定。
5. 上线前执行索引校验和备份。
6. 上线后禁止生产环境自动写入 mock 数据。

### 6.8 灰度与回滚方案

必须具备以下功能开关：

- `community_publish_enabled`
- `community_comment_enabled`
- `match_enabled`
- `activity_join_enabled`
- `billing_enabled`

回滚原则：

- 社区审核故障时关闭发布，不关闭只读 Feed。
- 支付故障时关闭新订单，不修改已有订单状态。
- 数据库迁移必须支持向前修复或回滚脚本。

## 7. 首批执行清单

后端团队拿到本文档后，第一批只执行以下任务：

1. `BE-000`：冻结正式 API 口径。
2. `BE-001`：拆分 Express app 与 server。
3. `BE-002`：建立环境变量与 Secret 规范。
4. `BE-003`：接入 PostgreSQL 与 Prisma。
5. `BE-004`：建立 Prisma Schema 与迁移基线。
6. `BE-005`：统一响应与错误处理。
7. `BE-006`：建立真实认证中间件。
8. `BE-009`：建立自动化测试框架。
9. `BE-011`：清理 `EN` 占位和独立解读服务直连耦合。
10. `BE-012`：建立 PostgreSQL 开发环境并清理旧启动脚本。
11. `BE-013`：建立数据库幂等与敏感接口限流。
12. `BE-014`：建立 PostgreSQL Outbox / Jobs 机制。

第一批完成前，不进入仪式、社区或订单正式功能开发。

## 8. 关键风险与处理

| 风险 | 影响 | 处理方案 |
|---|---|---|
| 三套 API 口径继续并存 | 前后端反复兼容，维护成本上升 | BE-000 必须先冻结正式契约 |
| 私密问题泄露到社区 | 严重隐私风险 | 私密版与公开版分库存储，社区接口只读公开版 |
| 社区内容安全不足 | 引流、恐吓、违规内容扩散 | 发布前审核、举报、屏蔽、审核审计 |
| 仪式数据结构与独立解读项目不兼容 | 后续联调需要返工 | 业务后端只冻结稳定数据容器，接入契约另行评审 |
| 同时开发全部模块 | 主链路长期不可用 | 严格按 M0 至 M5 里程碑推进 |
| 缺少自动化测试 | 回归风险不可控 | Phase 0 建立测试，P0 功能无测试不得合并 |

## 9. 最终验收

后端项目可宣布完成，必须同时满足：

- 当前 Flutter 前端除独立解读生成相关能力外，所有主页面均使用真实后端数据运行。
- `问一问`的会话、卦象结构、额度、消息记录、心绪存档和解读卡数据容器通过。
- `宽窄之间 -> 帖子详情 -> 评论/点赞/收藏 -> 消息中心`完整链路通过。
- `此刻`同频、`活动`报名、`我的`资料与记录链路通过。
- 解读生成、追问生成和内容生成 SSE 不作为本计划验收项。
- 所有 P0 任务完成，P1 任务中与现有 UI 对应的能力完成。
- 自动化测试、契约测试、安全测试和性能测试通过。
- 生产监控、告警、备份、灰度和回滚方案可执行。
- 仓库中不存在业务占位文本、独立解读服务直连实现或依赖内存 mock 的生产路径。
