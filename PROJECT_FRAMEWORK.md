# 六爻算卦 Agent 项目框架

> 最后更新：2026-06-05
> 本文档描述项目文件结构及各文件/目录的作用。前端六爻相关文件未纳入。

---

## 项目根目录

```
六爻算卦agent/
├── .github/                          # GitHub 配置
├── .gitignore                        # Git 忽略规则
├── BACKEND_TDL_AND_DELIVERY_PLAN.md  # 后端技术交付计划
├── PRODUCT_PRD.md                    # 产品需求文档
├── README.md                         # 项目说明
├── render.yaml                       # Render 部署配置
├── backend/                          # Python 六爻推理后端（旧版）
├── backend-node/                     # Node.js 业务后端（主后端）
├── docs/                             # 项目文档
├── frontend/                         # Flutter 前端（未纳入）
└── 六爻/                             # 六爻知识资料
```

---

## 根目录文件说明

| 文件 | 作用 |
|------|------|
| `BACKEND_TDL_AND_DELIVERY_PLAN.md` | 后端技术交付计划（TDL），定义 M0~M5 里程碑、功能模块、验收标准 |
| `PRODUCT_PRD.md` | 产品需求文档（PRD），定义产品功能、用户场景、业务规则 |
| `README.md` | 项目总说明，包含项目简介、技术栈、启动方式 |
| `render.yaml` | Render 云平台部署配置文件 |
| `.gitignore` | Git 忽略规则，排除 node_modules、uploads、backups、.env 等 |

---

## .github/

```
.github/
└── workflows/
    └── backend-node-ci.yml           # 后端 CI 流水线
```

| 文件 | 作用 |
|------|------|
| `backend-node-ci.yml` | GitHub Actions CI 配置，执行 install、Prisma generate、lint、test |

---

## docs/ — 项目文档

```
docs/
├── README.md                         # 文档目录索引
├── backend/                          # 后端相关文档
│   ├── HANDOFF_TO_BACKEND.md         # 后端交接文档
│   ├── experiments/                  # 实验性文档
│   │   └── AGENT_SANDBOX_DEMO.md     # Agent 沙箱演示
│   └── modules/                      # 各模块 API 文档
│       ├── README.md                 # 模块文档索引
│       ├── CONTRACT_TEMPLATE.md      # API 契约模板
│       ├── activity_api.md           # 活动模块 API
│       ├── auth_api.md               # 认证模块 API
│       ├── billing_api.md            # 账单模块 API
│       ├── community_api.md          # 社区模块 API
│       ├── credit_api.md             # 额度模块 API
│       ├── match_api.md              # 同频匹配 API
│       ├── message_api.md            # 消息模块 API
│       ├── profile_api.md            # 个人资料 API
│       ├── ritual_api.md             # 仪式模块 API
│       ├── share_api.md              # 分享模块 API
│       └── support_api.md            # 帮助反馈 API
└── project/                          # 项目级文档
    ├── README.md                     # 项目文档索引
    ├── PRD_v0.7.0_tag_identity_growth.md  # PRD 历史版本
    └── VERSIONING_AND_ROLLBACK.md    # 版本管理与回滚策略
```

---

## backend/ — Python 六爻推理后端（旧版）

```
backend/
├── Procfile                          # Heroku/Render 进程声明
├── README.md                         # 后端说明
├── requirements.txt                  # Python 依赖
├── run_backend.bat                   # Windows 启动脚本
├── knowledge.py                      # 六爻知识库（卦象、爻辞、用神）
├── liuyao_engine.py                  # 六爻推理引擎（排卦、断卦）
├── llm.py                            # LLM 调用封装（Agent 推理）
├── server.py                         # Flask API 服务器
├── share_render.py                   # 分享图渲染（SVG/PNG）
├── storage.py                        # 数据存储（本地 JSON）
├── validation.py                     # 输入校验
└── tests/
    └── test_api_contracts.py         # API 契约测试
```

| 文件 | 作用 |
|------|------|
| `knowledge.py` | 六爻知识库，包含 64 卦、384 爻、用神规则、六亲关系 |
| `liuyao_engine.py` | 六爻推理引擎，实现排卦（装卦、纳甲、六亲）、断卦逻辑 |
| `llm.py` | LLM 调用封装，将卦象信息发送给 Agent 进行智能解读 |
| `server.py` | Flask API 服务器，提供起卦、解读、追问等 HTTP 接口 |
| `share_render.py` | 分享图渲染，将卦象和解读生成可分享的 SVG/PNG 图片 |
| `storage.py` | 本地数据存储，使用 JSON 文件保存会话和用户数据 |
| `validation.py` | 输入参数校验，验证问题、卦象、动爻等参数合法性 |
| `test_api_contracts.py` | API 契约测试，验证请求/响应格式一致性 |

---

## backend-node/ — Node.js 业务后端（主后端）

```
backend-node/
├── .env                              # 本地环境变量（不提交）
├── .env.example                      # 环境变量模板
├── PROGRESS.md                       # 开发进度文档（核心）
├── docker-compose.yml                # PostgreSQL 16 容器配置
├── eslint.config.js                  # ESLint 9 配置
├── package.json                      # 依赖与脚本
├── package-lock.json                 # 依赖锁定
├── docs/                             # 后端文档
├── openapi/                          # OpenAPI 契约
├── prisma/                           # 数据库 Schema 与迁移
├── scripts/                          # 运维脚本
├── src/                              # 源代码
└── test/                             # 测试代码
```

### 核心配置文件

| 文件 | 作用 |
|------|------|
| `PROGRESS.md` | **项目进度核心文档**，记录 M0~M5 功能进度（92/92）、上线验收矩阵（5/11）、已创建文件清单、关键风险、更新日志 |
| `.env.example` | 环境变量模板，定义 DATABASE_URL、JWT_SECRET、SMS_PROVIDER 等必需变量 |
| `docker-compose.yml` | PostgreSQL 16 本地开发容器，端口 5432，用户名/密码 zhouyi |
| `eslint.config.js` | ESLint 9 扁平配置，代码风格检查 |
| `package.json` | 项目配置，定义 30+ npm scripts（db:*, ops:*, test:*, worker:*） |

---

### docs/ — 后端文档

```
backend-node/docs/
├── acceptance-traceability.md        # 验收项溯源表
├── adapter-readiness.md              # 外部适配器就绪状态
├── agent-integration-boundary.md     # Agent 接入边界定义
├── api-contract-decision.md          # API 口径决议
├── api-integration-test-report.md    # API 集成测试报告
├── db-migration-baseline.md          # 数据库迁移基线说明
├── ops-runbook.md                    # 运维手册
├── performance-verification.md       # 性能压测验证文档
├── rate-limit-strategy.md            # 限流策略文档
├── release-acceptance-runbook.md     # 发布验收手册
└── security-test-report.md           # 安全测试报告
```

| 文档 | 作用 |
|------|------|
| `acceptance-traceability.md` | 将 11 个验收项映射到 TDL 和 PRD 的来源章节 |
| `adapter-readiness.md` | 外部服务适配器（SMS/微信/QQ/S3/Push/支付/Agent）配置检查与验收要求 |
| `agent-integration-boundary.md` | 业务后端与独立 Agent 的认证、请求/响应、超时重试、降级、SSE relay 边界 |
| `api-contract-decision.md` | API 口径决议：`/api/v1` + `success/data` envelope 为当前实现契约 |
| `api-integration-test-report.md` | API 主链路集成测试覆盖报告（Auth/Profile/Ritual/Community 等） |
| `db-migration-baseline.md` | Prisma migration 基线说明、deploy/seed/回滚步骤 |
| `ops-runbook.md` | 运维手册：备份/恢复、安全检查、压测、监控、Feature Flags、Git 版本管理 |
| `performance-verification.md` | 性能压测场景（16 个）、命令、验收证据格式 |
| `rate-limit-strategy.md` | PostgreSQL-backed 限流策略、敏感接口配置 |
| `release-acceptance-runbook.md` | 发布验收执行手册，含所有验收项的命令、证据格式、完成规则 |
| `security-test-report.md` | 安全主链路测试覆盖报告（认证/越权/幂等/上传/隐私/审核） |

---

### openapi/ — OpenAPI 契约

```
backend-node/openapi/
└── openapi.yaml                      # OpenAPI 3.1 契约
```

| 文件 | 作用 |
|------|------|
| `openapi.yaml` | OpenAPI 3.1 规范，定义 30+ API 路径、请求/响应 Schema、认证方式、错误码 |

---

### prisma/ — 数据库 Schema 与迁移

```
backend-node/prisma/
├── schema.prisma                     # Prisma Schema（41 个模型）
├── seed.js                           # 种子数据脚本
└── migrations/
    ├── migration_lock.toml           # 迁移锁文件
    ├── 202606050001_initial_schema/  # 初始迁移
    │   └── migration.sql
    └── 202606050002_rate_limit_buckets/  # 限流表迁移
        └── migration.sql
```

| 文件 | 作用 |
|------|------|
| `schema.prisma` | Prisma Schema，定义 41 个数据模型（User/RitualSession/CommunityPost/CreditAccount 等）和 24 个枚举 |
| `seed.js` | 种子数据脚本，创建演示用户、额度账户、仪式会话、社区帖子、账单计划等 |
| `migrations/` | Prisma 迁移文件，包含初始 schema 和限流表两个迁移 |

---

### scripts/ — 运维脚本

```
backend-node/scripts/
├── acceptance-evidence.js            # 生成验收证据模板
├── acceptance-evidence-validate.js   # 校验验收证据内容
├── acceptance-gate.js                # 发布门禁（preflight + status + seal）
├── acceptance-package.js             # 打包验收证据
├── acceptance-preflight.js           # 验收前预检查
├── acceptance-seal.js                # 验证证据包 SHA-256 封存
├── acceptance-status.js              # 验收状态汇总
├── adapter-check.js                  # 外部适配器配置检查
├── alert-check.js                    # 监控告警检查
├── data-deletion.js                  # 用户数据导出/删除
├── db-backup.js                      # PostgreSQL 备份
├── db-restore.js                     # PostgreSQL 恢复
├── perf-scenarios.js                 # 性能压测场景 runner
├── perf-smoke.js                     # 性能 smoke test
└── security-check.js                 # 安全配置检查
```

| 脚本 | 作用 |
|------|------|
| `acceptance-*.js` | 验收工具链：生成证据模板、校验内容、预检查、封存、汇总、门禁 |
| `adapter-check.js` | 检查 SMS/微信/QQ/S3/Push/支付/Agent 的生产配置是否就绪 |
| `alert-check.js` | 检查 `/ready` 和 `/metrics` 端点，触发 Webhook 告警 |
| `data-deletion.js` | GDPR 合规：用户数据导出（JSON）和删除（22 个表的级联清理） |
| `db-backup.js` | PostgreSQL 备份（pg_dump custom 格式），生成 manifest |
| `db-restore.js` | PostgreSQL 恢复（pg_restore/psql），支持 .dump 和 .sql 格式 |
| `perf-scenarios.js` | 16 个性能压测场景（community/profile/notifications/match/activities/billing/ritual） |
| `perf-smoke.js` | 单端点负载测试，返回 p50/p95/errorRate |
| `security-check.js` | 安全配置检查：PostgreSQL URL、JWT 强度、生产默认值、.gitignore 覆盖 |

---

### src/ — 源代码

```
backend-node/src/
├── app.js                            # Express app 工厂
├── server.js                         # 服务器启动入口
├── config/
│   └── env.js                        # 环境变量校验（Zod）
├── db/
│   └── prisma.js                     # Prisma Client 单例
├── middleware/
│   ├── auth.js                       # JWT 认证（requireAuth/optionalAuth/requireRole）
│   ├── error-handler.js              # 统一错误处理
│   ├── idempotency.js                # 幂等控制（Idempotency-Key）
│   ├── rate-limit.js                 # 限流（PostgreSQL/memory）
│   ├── request-id.js                 # 请求 ID 生成
│   └── validate.js                   # Zod 参数校验
├── modules/                          # 业务模块（14 个）
│   ├── activities/                   # 活动模块
│   ├── admin/                        # 管理后台
│   ├── analytics/                    # 数据分析
│   ├── auth/                         # 认证与会话
│   ├── billing/                      # 会员与订单
│   ├── community/                    # 社区（帖子/评论/审核/推荐）
│   ├── credits/                      # 额度管理
│   ├── match/                        # 同频匹配
│   ├── media/                        # 媒体上传
│   ├── notifications/                # 通知中心
│   ├── profile/                      # 个人资料
│   ├── ritual/                       # 仪式会话（起卦/解读/追问）
│   ├── share/                        # 分享卡
│   └── support/                      # 帮助反馈
├── shared/
│   ├── api-error.js                  # 统一错误类（9 种 HTTP 错误码）
│   ├── feature-flags.js              # Feature Flags（10 个开关）
│   ├── logger.js                     # Pino 结构化日志（敏感字段脱敏）
│   ├── monitoring.js                 # 运行指标采集
│   └── response.js                   # 统一响应 envelope（ok/fail）
└── workers/
    └── outbox.js                     # PostgreSQL Outbox 异步任务 worker
```

#### 业务模块结构（每个模块）

```
modules/<name>/
├── route.js                          # Express 路由定义
├── schema.js                         # Zod 请求/响应 Schema
└── service.js                        # 业务逻辑层
```

| 模块 | 作用 |
|------|------|
| `auth/` | 手机验证码登录、社交登录（微信/QQ）、Token 管理、游客升级 |
| `profile/` | 个人资料 CRUD、设置、头像/封面、签到、互动记录、匿名身份 |
| `credits/` | 额度账户、每日结算、幂等消费、签到奖励 |
| `billing/` | 会员计划、订单创建、支付确认、VIP 权益生效 |
| `ritual/` | 仪式会话（起卦/解读/追问）、情绪校准、周期回顾、案例检索 |
| `community/` | 帖子发布、推荐流/深谈流、评论、点赞/收藏、审核、搜索、关注/屏蔽 |
| `notifications/` | 通知列表、已读/删除、推送 Token 注册、系统通知 |
| `match/` | 同频解锁、今日签名、历史同频 |
| `activities/` | 活动列表、报名、容量控制 |
| `share/` | 分享卡草稿、SVG 渲染、发布到社区、外部分享 |
| `media/` | 媒体上传（本地存储适配器）、MIME/大小校验 |
| `support/` | 帮助反馈工单 |
| `analytics/` | 事件埋点、WMRU 北极星指标、安全审核指标 |
| `admin/` | Feature Flags 管理、系统状态、审核后台 |

---

### test/ — 测试代码

```
backend-node/test/
├── helpers/
│   ├── http.js                       # HTTP 测试客户端
│   └── setup.js                      # 测试辅助函数
├── contract/
│   └── flutter-contract.test.js      # Flutter 契约回归测试
├── integration/
│   └── api-mainline.test.js          # API 主链路集成测试（20 个用例）
└── unit/                             # 单元测试（60+ 文件）
```

#### 单元测试分类

| 分类 | 测试文件 | 覆盖内容 |
|------|----------|----------|
| **验收工具** | acceptance-*.test.js (10 个) | 证据生成/校验/预检查/封存/汇总/门禁/溯源/进度 |
| **运维脚本** | adapter-check/mock/error.test.js, alert-check.test.js, security-check/expanded.test.js, perf-smoke/scenarios/report/integration.test.js, db-backup/restore/flow/manifest.test.js, data-deletion/validation.test.js | 所有运维脚本的功能和边界测试 |
| **中间件** | auth-middleware.test.js, idempotency.test.js, error-handler.test.js, middleware.test.js, rate-limit.test.js | 认证、幂等、错误处理、校验、限流 |
| **共享模块** | api-error.test.js, response.test.js, feature-flags.test.js, logger.test.js, env.test.js, prisma-client.test.js, outbox.test.js | 错误类、响应、Feature Flags、日志、环境配置、数据库、Worker |
| **业务模块** | community-moderation.test.js, recommend.test.js, analytics.test.js, admin-routes.test.js | 社区审核、推荐引擎、分析、管理后台 |
| **安全** | security-mainline.test.js, security-upload-replay.test.js, log-sanitization.test.js | 认证/越权/幂等/上传/重放/日志脱敏 |
| **数据库** | prisma-schema.test.js, migration-validation.test.js, seed-validation.test.js, db-verification-queries.test.js | Schema 完整性、迁移 SQL、种子数据、验证查询 |
| **契约** | openapi-compliance.test.js, npm-scripts.test.js, acceptance-flow.test.js | OpenAPI 合规、npm scripts、验收流程 |
| **基础设施** | health.test.js, error-format.test.js, monitoring.test.js, monitoring-validation.test.js, monitoring-endpoints.test.js | 健康检查、错误格式、监控指标 |

---

## 六爻/ — 六爻知识资料

```
六爻/
├── 六爻卦理.md                       # 卦理基础
├── 六爻基础.md                       # 六爻入门知识
├── 六爻用神.md                       # 用神取法
├── 装卦方法.md                       # 装卦步骤
└── 起卦方法.md                       # 起卦方式
```

| 文件 | 作用 |
|------|------|
| 六爻卦理.md | 卦理基础知识，阴阳、五行、六亲关系 |
| 六爻基础.md | 六爻入门，天干地支、纳甲、世应 |
| 六爻用神.md | 用神取法，不同问题类型的用神判断规则 |
| 装卦方法.md | 装卦步骤详解，从卦象到完整排卦的流程 |
| 起卦方法.md | 起卦方式，铜钱法、时间法、数字法等 |

---

## 数据流概览

```
用户 → Flutter 前端
         ↓
    Node.js 业务后端 (backend-node)
         ├── 认证 → JWT Token
         ├── 仪式 → 起卦数据 → PostgreSQL
         ├── 社区 → 帖子/评论 → PostgreSQL
         └── Agent 调用 → Python 六爻后端 (backend)
                            ├── liuyao_engine.py → 排卦
                            ├── knowledge.py → 知识库
                            └── llm.py → LLM 解读
```

---

## 技术栈

| 层级 | 技术 |
|------|------|
| 前端 | Flutter (Dart) |
| 业务后端 | Node.js + Express 5 + Prisma + PostgreSQL 16 |
| 推理后端 | Python + Flask |
| 数据库 | PostgreSQL 16 |
| ORM | Prisma 6.9 |
| 校验 | Zod |
| 日志 | Pino |
| 认证 | JWT (jsonwebtoken) |
| API 规范 | OpenAPI 3.1 |
| CI | GitHub Actions |
| 容器 | Docker Compose |
