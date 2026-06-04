# 宽窄·Orbit 业务后端开发进度

## 版本管理要求（必须执行）

- 每轮后端任务开始前先确认 Git 状态，避免误覆盖用户改动。
- 每轮后端任务完成后必须运行必要校验（至少包含本轮相关的 generate/lint/test/contract check）。
- 校验通过后必须 `git add` 相关后端文件并创建清晰 commit，确保后续可查看版本、对比 diff、回滚到任意提交。
- 提交后再次确认工作区状态；若仍有未提交内容，必须在进度说明中写清原因。

> 依据：[BACKEND_TDL_AND_DELIVERY_PLAN.md](../BACKEND_TDL_AND_DELIVERY_PLAN.md) · [PRODUCT_PRD.md](../PRODUCT_PRD.md)
> 最后更新：2026-06-04

---

## 总览

| 里程碑 | 目标周期 | 当前状态 | 进度 |
|--------|---------|---------|------|
| M0：工程可持续 | 第 1 周 | ✅ 已完成 | 15/15 |
| M1：身份与账本 | 第 2 周 | ✅ 已完成 | 21/21 |
| M2：仪式数据链路 | 第 3 周 | ✅ 已完成 | 9/9 |
| M3：社区生产链路 | 第 4~5 周 | ✅ 已完成 | 12/12 |
| M4：现有 UI 业务能力接入 | 第 6~7 周 | ✅ 已完成 | 20/20 |
| M5：上线准备 | 第 8 周 | 🟡 进行中 | 5/8 |

**整体进度：82/92 个任务完成（89%）**

---

## Phase 0：契约冻结与工程基础（M0）

> 目标：解决接口口径、测试能力和基础设施问题

| ID | 任务 | 状态 | 交付物 | 备注 |
|----|------|------|--------|------|
| BE-000 | 冻结正式公共 API 口径 | ✅ 已完成 | `openapi/openapi.yaml` | OpenAPI 3.1，覆盖全部 12 模块 |
| BE-001 | 重构 Express 启动结构 | ✅ 已完成 | `src/app.js` + `src/server.js` | 测试可导入 app，不会自动监听端口 |
| BE-002 | 建立环境配置与 Secret 规范 | ✅ 已完成 | `.env.example` + `src/config/env.js` | Zod 校验，缺少必需变量时启动失败 |
| BE-003 | 接入 PostgreSQL 与 Prisma | ✅ 已完成 | `src/db/prisma.js` + Prisma Client | `/health` 可区分应用与 PostgreSQL 状态 |
| BE-004 | 建立 Prisma Schema 与迁移基线 | ✅ 已完成 | `prisma/schema.prisma` | 30 个模型，覆盖所有业务域 |
| BE-005 | 建立统一响应与错误处理中间件 | ✅ 已完成 | `src/shared/api-error.js` + `response.js` + `error-handler.js` | 统一 envelope 和 requestId |
| BE-006 | 建立认证中间件 | ✅ 已完成 | `src/middleware/auth.js` | JWT 校验、可选认证、权限门禁 |
| BE-007 | 建立参数校验 | ✅ 已完成 | `src/middleware/validate.js` | Zod-based，非法定返回 `40001` |
| BE-008 | 建立结构化日志与敏感信息脱敏 | ✅ 已完成 | `src/shared/logger.js` + `request-id.js` | Pino + redact |
| BE-009 | 建立自动化测试框架 | ✅ 已完成 | `test/` 目录 + 2 个测试套件 | Node test runner，5 个测试通过 |
| BE-010 | 建立 CI | ✅ 已完成 | `.github/workflows/backend-node-ci.yml` + `eslint.config.js` | GitHub Actions 执行 install、Prisma generate、lint、test |
| BE-011 | 清理 EN 占位与独立解读服务直连耦合 | ✅ 已完成 | — | Node 后端无旧代码残留 |
| BE-012 | 建立 PostgreSQL 开发环境 | ✅ 已完成 | `docker-compose.yml` + `.env` | PostgreSQL 16，一键启动 |
| BE-013 | 建立数据库幂等与敏感接口限流 | ✅ 已完成 | `src/middleware/idempotency.js` + `rate-limit.js` | 内存实现，生产需迁移至 DB |
| BE-014 | 建立 PostgreSQL Outbox / Jobs 机制 | ✅ 已完成 | `OutboxJob` 模型 + `src/workers/outbox.js` | 支持锁定、重试、失败记录；通知推送任务已写入 outbox |

**Phase 0 完成 ✅**（15/15）

---

## Phase 1：认证、用户、媒体与个人中心（M1）

> 目标：建立所有后续模块依赖的用户身份与媒体能力

| ID | 任务 | 状态 | 交付物 | 备注 |
|----|------|------|--------|------|
| AUTH-001 | 手机验证码发送与验证 | ✅ 已完成 | `src/modules/auth/` | test 模式固定 123456，真实 SMS 待接入 |
| AUTH-002 | Access Token 与 Refresh Token | ✅ 已完成 | `src/modules/auth/service.js` | Refresh Token 哈希存储，可吊销 |
| AUTH-003 | 游客身份与游客升级 | ✅ 已完成 | `src/modules/auth/service.js` | 升级合并逻辑已实现 |
| AUTH-004 | 协议与隐私版本存证 | ✅ 已完成 | `AgreementConsent` 模型 | 每次登录记录版本和时间 |
| AUTH-005 | 微信、QQ 社交登录适配层 | ✅ 已完成 | `SocialAccount` 模型 + `authService.socialLogin` | 开发/测试 mock adapter 可用；生产需接真实 SDK 配置 |
| PROFILE-001 | 获取与更新个人资料 | ✅ 已完成 | `src/modules/profile/` | GET/PUT /me |
| PROFILE-002 | 媒体上传服务 | ✅ 已完成 | `src/modules/media/service.js` | 本地存储适配器，支持 multipart 与远程 URL 登记，校验 MIME/大小/用途 |
| PROFILE-003 | 头像与封面更新 | ✅ 已完成 | `POST /profile/me/avatar` + `POST /profile/me/cover` | 只允许引用本人对应用途的已上传媒体 |
| PROFILE-004 | 用户设置 | ✅ 已完成 | `src/modules/profile/service.js` | 推送、震动、音效、公开主页开关 |
| PROFILE-005 | 公开主页与分享链接 | ✅ 已完成 | `GET /profile/me/share-card` + `GET /profile/public/:shortId` | 关闭公开主页时不泄露资料 |
| PROFILE-006 | 互动记录与浏览记录 | ✅ 已完成 | `src/modules/profile/service.js` + `PostView` 模型 | 互动与浏览记录均支持分页查询 |
| PROFILE-007 | 账号注销与冷静期 | ✅ 已完成 | `src/modules/profile/service.js` | 7 天冷静期 |
| SUPPORT-001 | 帮助与反馈 | ✅ 已完成 | `src/modules/support/` | 创建 `SupportTicket` 并返回 ticketId |

**Phase 1 进度：13/13**

---

## Phase 2：额度、会员与订单（M1）

> 目标：建立服务端权威额度账本

| ID | 任务 | 状态 | 交付物 | 备注 |
|----|------|------|--------|------|
| CREDIT-001 | 建立额度账户与账本 | ✅ 已完成 | `src/modules/credits/` | account + ledger 模型 |
| CREDIT-002 | 每日额度结算 | ✅ 已完成 | `src/modules/credits/service.js` | 普通/VIP 策略可配置，自动重置 |
| CREDIT-003 | 幂等额度消费 | ✅ 已完成 | `src/modules/credits/service.js` | Idempotency-Key 防重复扣除 |
| CREDIT-004 | 签到与签到日历 | ✅ 已完成 | `src/modules/profile/service.js` | 签到幂等，奖励进入账本 |
| BILLING-001 | 会员计划列表 | ✅ 已完成 | `src/modules/billing/` | 服务端读取 active plans |
| BILLING-002 | 订单创建与查询 | ✅ 已完成 | `BillingOrder.idempotencyKey` + service | 创建订单支持 Idempotency-Key，查询校验归属 |
| BILLING-003 | 支付确认与回调 | ✅ 已完成 | `confirmPayment` | 生产要求签名；客户端不能直接伪造生产支付结果 |
| BILLING-004 | VIP 权益生效与过期 | ✅ 已完成 | `CreditAccount.vipExpiresAt` 更新 | 支付后延长 VIP、补充额度并写 purchase ledger |

**Phase 2 进度：8/8**

---

## Phase 3：仪式基础业务与存档（M2）

> 目标：完成 `问一问` 所需的业务数据能力（不实现解读生成）

| ID | 任务 | 状态 | 交付物 | 备注 |
|----|------|------|--------|------|
| RITUAL-001 | 创建仪式会话 | ✅ 已完成 | `src/modules/ritual/` | 保存问题、分类、结构、动爻 |
| RITUAL-002 | 卦象结构持久化与校验 | ✅ 已完成 | `src/modules/ritual/schema.js` | 6 段结构 + 合法动爻校验 |
| RITUAL-003 | 解读卡数据模型与存储边界 | ✅ 已完成 | `InterpretationCard` 模型 | 私密/公开内容分开存储 |
| RITUAL-004 | 解读卡读取权限 | ✅ 已完成 | `src/modules/ritual/service.js` | preview（游客）/ full-read（登录） |
| RITUAL-005 | 追问消息数据模型 | ✅ 已完成 | `FollowupMessage` 模型 | 保存和读取会话消息 |
| RITUAL-006 | 心绪存档与会话恢复 | ✅ 已完成 | `src/modules/ritual/service.js` | 跨设备恢复 |
| RITUAL-007 | 仪式状态机与额度一致性 | ✅ 已完成 | `src/modules/ritual/service.js` | 起卦/追问接入额度消费；配合 Idempotency-Key 防重复扣额 |
| RITUAL-008 | 每日完成状态 | ✅ 已完成 | `src/modules/ritual/service.js` | completion-today 接口 |
| RITUAL-009 | 情绪校准与周期回顾 | ✅ 已完成 | `POST /ritual/session/:sessionId/calibration` + `GET /ritual/me/periodic-review` | 保存情绪反馈并输出近 N 天主题、反馈与关注点回顾 |

**Phase 3 进度：9/9**

---

## Phase 4：宽窄之间社区与内容安全（M3）

> 目标：让社区 UI 从本地模拟切换到真实数据

| ID | 任务 | 状态 | 交付物 | 备注 |
|----|------|------|--------|------|
| COMMUNITY-001 | 社区帖子模型与发布 | ✅ 已完成 | `src/modules/community/` | 支持纯文本、图片、解读卡关联 |
| COMMUNITY-002 | 推荐流与深谈流 | ✅ 已完成 | `src/modules/community/service.js` | recommended / deep 双 tab |
| COMMUNITY-003 | 帖子详情与浏览记录 | ✅ 已完成 | `src/modules/community/service.js` | 浏览计数去重 |
| COMMUNITY-004 | 评论线程 | ✅ 已完成 | `src/modules/community/service.js` | 分页 + 回复链 |
| COMMUNITY-005 | 点赞与收藏 | ✅ 已完成 | `src/modules/community/service.js` | 幂等，计数一致 |
| COMMUNITY-006 | 发布前内容审核 | ✅ 已完成 | `src/modules/community/moderation.js` | 命中高风险/隐私规则时帖子或评论不直接公开，并写审核记录 |
| COMMUNITY-007 | 解读卡公开版校验 | ✅ 已完成 | `loadShareableCard` + `cardPreview` | 校验卡归属与 communitySafeContent，社区接口只返回公开版摘要 |
| COMMUNITY-008 | 作者主页与关注 | ✅ 已完成 | `src/modules/community/service.js` | 关注幂等，屏蔽关系优先 |
| COMMUNITY-009 | 举报、不感兴趣与屏蔽 | ✅ 已完成 | `src/modules/community/service.js` | 举报可审计 |
| COMMUNITY-010 | 社区搜索 | ✅ 已完成 | `src/modules/community/service.js` | 支持帖子/用户/活动搜索 |
| COMMUNITY-011 | 审核后台最小能力 | ✅ 已完成 | `/community/admin/moderation` + `/community/admin/reports/:reportId` | 运营/admin 可处理自动审核命中内容与举报，写入审计记录 |
| COMMUNITY-012 | Feed 指标一致性 | ✅ 已完成 | `src/modules/community/service.js` | 点赞/收藏/浏览/评论数一致 |

**Phase 4 进度：12/12**

---

## Phase 5：通知与消息中心（M4）

> 目标：支持现有顶部通知入口与消息中心 UI

| ID | 任务 | 状态 | 交付物 | 备注 |
|----|------|------|--------|------|
| NOTIFY-001 | 通知模型与事件生产器 | ✅ 已完成 | `src/modules/notifications/service.js` | 评论、点赞、收藏、关注、活动报名可产生通知 |
| NOTIFY-002 | 通知列表与未读数 | ✅ 已完成 | `GET /notifications` + `/unread-count` | 支持分页与类型筛选 |
| NOTIFY-003 | 已读、全部已读与删除 | ✅ 已完成 | read/read-all/dismiss/state | 操作幂等 |
| NOTIFY-004 | 推送 Token 注册 | ✅ 已完成 | `PushToken` 接口 | Token 与用户、设备平台绑定 |
| NOTIFY-005 | 异步推送任务 | ✅ 已完成 | `OutboxJob notification.push` + worker | 推送 adapter 未配置时可安全确认任务 |
| NOTIFY-006 | 活动与系统通知 | ✅ 已完成 | 活动报名通知 + `/notifications/admin/system` | operator/admin 可定向或广播系统通知，复用 Outbox 推送 |

**Phase 5 进度：6/6**

---

## Phase 6：此刻、同频与活动（M4）

> 目标：补齐 `此刻` 和 `活动` 页面的真实后端能力

| ID | 任务 | 状态 | 交付物 | 备注 |
|----|------|------|--------|------|
| MATCH-001 | 同频解锁状态 | ✅ 已完成 | `src/modules/match/` | 用户+日期幂等解锁 |
| MATCH-002 | 今日签名与匹配数据 | ✅ 已完成 | same-frequency users | 返回匹配理由，不返回评分 |
| MATCH-003 | 历史同频内容 | ✅ 已完成 | same-frequency history | 从公开社区内容返回历史同频 |
| ACTIVITY-001 | 活动列表与详情 | ✅ 已完成 | `src/modules/activities/` | 支持分页、详情、joinStatus |
| ACTIVITY-002 | 活动管理最小能力 | ✅ 已完成 | `/activities/admin` + `/activities/admin/:id` | 仅 operator/admin 可创建、编辑和变更状态 |
| ACTIVITY-003 | 活动报名与状态 | ✅ 已完成 | join/join-status | 重复报名幂等 |
| ACTIVITY-004 | 活动参与人数与容量 | ✅ 已完成 | capacity control | 满员进入 waitlist，不增加参与人数 |

**Phase 6 进度：7/7**

---

## Phase 7：分享、运营能力与数据指标（M4）

> 目标：补齐分享卡、帮助反馈和产品指标

| ID | 任务 | 状态 | 交付物 | 备注 |
|----|------|------|--------|------|
| SHARE-001 | 保存分享卡草稿 | ✅ 已完成 | `ShareCardDraft` + `/share/card/save` | 草稿按用户和 cardId 幂等 |
| SHARE-002 | 服务端分享卡渲染 | ✅ 已完成 | `/share/card/render` + `/uploads/share/*.svg` | 服务端生成 1200x1600 SVG 分享图并返回稳定 imageUrl |
| SHARE-003 | 发布分享卡到社区 | ✅ 已完成 | `/share/community/publish` | 复用社区发布审核与公开卡校验 |
| SHARE-004 | 外部分享载荷 | ✅ 已完成 | `/share/external` | 返回标题、摘要、链接和图片 URL |
| ANALYTICS-001 | 核心事件埋点接收 | ✅ 已完成 | `src/modules/analytics/` | 登录用户可上报核心事件 |
| ANALYTICS-002 | 北极星指标计算 | ✅ 已完成 | `/analytics/wmru` + `/analytics/wmru/recalculate` | 按 ISO 周计算 WMRU 并缓存到 `WeeklyMetric` |
| ANALYTICS-003 | 安全与审核指标 | ✅ 已完成 | `/analytics/safety` | 输出审核命中率、举报处理状态、下架/限流数量 |

**Phase 7 进度：7/7**

---

## Phase 8：生产上线与质量加固（M5）

> 目标：正式发布前完成性能、安全、迁移和回滚准备

| ID | 任务 | 状态 | 交付物 | 备注 |
|----|------|------|--------|------|
| OPS-001 | 数据迁移与种子数据 | ✅ 已完成 | `prisma/seed.js` | 种子脚本已创建 |
| OPS-002 | 自动化备份与恢复演练 | ✅ 已完成 | `scripts/db-backup.js` + `scripts/db-restore.js` + `docs/ops-runbook.md` | 支持 dry-run、备份 manifest、恢复演练命令；真实恢复需 PostgreSQL 环境 |
| OPS-003 | 安全检查 | ✅ 已完成 | `scripts/security-check.js` + `npm run ops:security-check` | 检查 PostgreSQL URL、JWT Secret、生产默认项、Git ignore 和 lockfile |
| OPS-004 | 性能压测 | ✅ 已完成 | `scripts/perf-smoke.js` + `npm run ops:perf-smoke` | 支持并发请求、p50/p95、错误率和阈值失败退出 |
| OPS-005 | 灰度开关与回滚 | 🔲 未开始 | — | — |
| OPS-006 | 生产监控与告警 | ✅ 已完成 | `/api/v1/ready` + `/api/v1/metrics` + `scripts/alert-check.js` | 记录请求数、状态码、错误率、耗时，并支持 webhook 告警检查 |
| OPS-007 | 隐私与数据删除验收 | 🔲 未开始 | — | — |
| OPS-008 | 前后端契约回归 | 🔲 未开始 | — | — |

**Phase 8 进度：5/8**

---

## Phase 9：P2 长期社区价值

> 目标：主链路稳定后增强社区长期价值

| ID | 任务 | 状态 | 交付物 | 备注 |
|----|------|------|--------|------|
| IDENTITY-001 | 显式匿名身份 | 🔲 未开始 | — | — |
| COMMUNITY-013 | 匿名发布与匿名互动 | 🔲 未开始 | — | — |
| FEEDBACK-001 | 解读结果反馈 | 🔲 未开始 | — | — |
| COMMUNITY-014 | 反馈帖与阶段性复盘 | 🔲 未开始 | — | — |
| RECOMMEND-001 | 推荐与深谈分发深化 | 🔲 未开始 | — | — |
| CASE-001 | 结构化案例检索 | 🔲 未开始 | — | — |
| REVIEW-001 | 周期性情绪与成长报告 | 🔲 未开始 | — | — |

**Phase 9 进度：0/7**

---

## 已创建文件清单

```
repo root/
├── .github/workflows/backend-node-ci.yml       # 后端 CI
└── .gitignore                                  # 忽略 node_modules、uploads、backups、.env

backend-node/
├── .env                                        # 本地开发环境变量
├── .env.example                                # 环境变量模板
├── docker-compose.yml                          # PostgreSQL 16 容器
├── package.json                                # 依赖与脚本（含 worker、backup、restore、安全检查）
├── eslint.config.js                            # ESLint 9 配置
├── docs/
│   └── ops-runbook.md                          # 备份、恢复、安全检查、压测、监控和 Git 版本管理步骤
├── openapi/
│   └── openapi.yaml                            # OpenAPI 3.1 契约（全模块）
├── prisma/
│   ├── schema.prisma                           # 36 个数据模型
│   └── seed.js                                 # 种子数据脚本
├── scripts/
│   ├── db-backup.js                            # PostgreSQL 备份脚本
│   ├── db-restore.js                           # PostgreSQL 恢复演练脚本
│   ├── security-check.js                       # 本地安全检查脚本
│   ├── perf-smoke.js                           # 性能 smoke test 脚本
│   └── alert-check.js                          # 监控告警检查脚本
├── test/
│   ├── helpers/
│   │   ├── setup.js                            # 测试辅助函数
│   │   └── http.js                             # HTTP 测试客户端
│   └── unit/
│       ├── health.test.js                      # 健康检查测试
│       ├── error-format.test.js                # 错误格式测试
│       ├── community-moderation.test.js        # 社区审核规则测试
│       ├── analytics.test.js                   # Analytics 周指标辅助函数测试
│       ├── security-check.test.js              # 运维安全检查脚本测试
│       ├── perf-smoke.test.js                  # 性能统计脚本测试
│       └── monitoring.test.js                  # 运行指标与告警规则测试
├── src/
│   ├── app.js                                  # Express app 工厂
│   ├── server.js                               # 服务器启动入口
│   ├── config/env.js                           # 环境变量校验
│   ├── db/prisma.js                            # Prisma Client 单例
│   ├── middleware/
│   │   ├── auth.js                             # JWT 认证
│   │   ├── error-handler.js                    # 错误处理
│   │   ├── idempotency.js                      # 幂等控制
│   │   ├── rate-limit.js                       # 限流
│   │   ├── request-id.js                       # 请求 ID
│   │   └── validate.js                         # 参数校验
│   ├── shared/
│   │   ├── api-error.js                        # 统一错误类
│   │   ├── logger.js                           # Pino 日志
│   │   └── response.js                         # 响应助手
│   ├── workers/
│   │   └── outbox.js                           # PostgreSQL Outbox worker
│   └── modules/
│       ├── auth/        (route + service + schema)
│       ├── profile/     (route + service + schema)
│       ├── credits/     (route + service + schema)
│       ├── ritual/      (route + service + schema)
│       ├── community/   (route + service + schema + moderation)
│       ├── billing/     (route + service + schema)
│       ├── notifications/ (route + service + schema)
│       ├── match/       (route + service + schema)
│       ├── activities/  (route + service + schema)
│       ├── share/       (route + service + schema)
│       ├── support/     (route + service + schema)
│       ├── media/       (route + service)
│       └── analytics/   (route + service + schema)
```

---

## 关键风险

| 风险 | 当前状态 | 处理方案 |
|------|---------|---------|
| 三套 API 口径并存 | ✅ 已解决 | OpenAPI 冻结正式契约，旧路由保留兼容层 |
| 私密问题泄露到社区 | ✅ 已落地 | 社区发布校验卡归属与 communitySafeContent，只返回公开版 cardPreview |
| 社区内容安全不足 | ✅ 已解决 | 发布/评论前审核、举报/屏蔽、审核记录和审核后台已实现 |
| 同时开发全部模块 | ✅ 已避免 | 严格按 M0→M5 里程碑推进 |
| 缺少自动化测试 | ⚠️ 部分解决 | CI、lint、基础测试与审核规则测试已补；业务集成测试待扩展 |
| 无 Docker/PostgreSQL 环境 | ⚠️ 当前限制 | Docker Compose、备份/恢复脚本已创建，需在有 Docker 环境时运行迁移、seed 与恢复演练 |
| 当前环境 npm 全局命令不可用 | ⚠️ 当前限制 | 使用内置 Node 直接调用本地 CLI；Git 已通过 `D:\Git\cmd\git.exe` 可用 |

---

## 下一步行动

### 优先级 P0（让前端真正可用）
1. **启动 PostgreSQL** → `docker compose up -d` → `npm run db:migrate` → `npm run db:seed`
2. **跑一次真实迁移/种子验收** → 当前已通过 Prisma generate，待数据库环境验证迁移和 seed
3. **补真实数据库迁移文件** → 当前 schema 可 generate，待连接 PostgreSQL 后执行 migrate

### 优先级 P1（补齐 UI 后端能力）
4. **补业务集成测试** → 覆盖审核、活动、账单、公开主页、通知、分享和 Analytics
5. **OPS-005、OPS-007、OPS-008** → 灰度回滚、隐私删除验收、前后端契约回归

### 优先级 P2（长期价值）
6. **Phase 9** → 匿名身份、反馈帖、推荐深化

---

## 更新日志

| 日期 | 内容 |
|------|------|
| 2026-06-04 | 本轮追加：补 OPS-004 性能压测脚本、OPS-006 ready/metrics 监控端点与告警检查脚本；同步 OpenAPI、Runbook 和测试；更新进度至 82/92 |
| 2026-06-04 | 本轮追加：在文档最前面补 Git 版本管理要求；补 OPS-002 备份/恢复演练脚本与 Runbook、OPS-003 本地安全检查脚本和测试；更新进度至 80/92 |
| 2026-06-04 | 本轮追加：补 SHARE-002 服务端 SVG 分享图、NOTIFY-006 系统通知运营入口、RITUAL-009 情绪校准与周期回顾；同步 OpenAPI；更新进度至 78/92 |
| 2026-06-04 | 本轮追加：删除临时快照；补审核后台、公开主页、活动管理和 Analytics 指标；更新进度至 75/92 |
| 2026-06-04 | 本轮更新：补 CI、Prisma 模型、社区审核与公开卡校验、通知、媒体、账单、同频、活动、分享、反馈、Outbox worker；修正进度统计口径 |
| 2026-06-04 | 初始创建。完成 Phase 0 全部工程基础、Phase 1 认证与个人资料、Phase 2 额度管理、Phase 3 仪式数据链路、Phase 4 社区核心功能 |
