# 宽窄·Orbit 业务后端开发进度

## 版本管理要求（必须执行）

- 每轮后端任务开始前先确认 Git 状态，避免误覆盖用户改动。
- 每轮后端任务完成后必须运行必要校验（至少包含本轮相关的 generate/lint/test/contract check）。
- 校验通过后必须 `git add` 相关后端文件并创建清晰 commit，确保后续可查看版本、对比 diff、回滚到任意提交。
- 提交后再次确认工作区状态；若仍有未提交内容，必须在进度说明中写清原因。

> 依据：[BACKEND_TDL_AND_DELIVERY_PLAN.md](../BACKEND_TDL_AND_DELIVERY_PLAN.md) · [PRODUCT_PRD.md](../PRODUCT_PRD.md)
> 最后更新：2026-06-05

---

## 总览

> 状态口径：下方 M0~Phase 9 的任务表记录“功能实现进度”。是否可宣布上线完成，必须再通过“上线验收矩阵”。脚本、dry-run、mock adapter、单元测试通过只能算能力具备，不能替代真实迁移、预发布演练、Flutter 联调和生产 provider 验收。

| 里程碑 | 目标周期 | 当前状态 | 进度 |
|--------|---------|---------|------|
| M0：工程可持续 | 第 1 周 | 🟡 功能完成，契约/迁移待验收 | 15/15 |
| M1：身份与账本 | 第 2 周 | ✅ 已完成 | 21/21 |
| M2：仪式数据链路 | 第 3 周 | ✅ 已完成 | 9/9 |
| M3：社区生产链路 | 第 4~5 周 | ✅ 已完成 | 12/12 |
| M4：现有 UI 业务能力接入 | 第 6~7 周 | ✅ 已完成 | 20/20 |
| M5：上线准备 | 第 8 周 | 🟡 能力具备，验收待执行 | 8/8 |

**功能实现进度：92/92 个任务完成（100%）**

**上线验收进度：3/11 项完成（27%）**

---

## Phase 0：契约冻结与工程基础（M0）

> 目标：解决接口口径、测试能力和基础设施问题

| ID | 任务 | 状态 | 交付物 | 备注 |
|----|------|------|--------|------|
| BE-000 | 冻结正式公共 API 口径 | ✅ 已完成 | `openapi/openapi.yaml` + `docs/api-contract-decision.md` | 决议当前实现以 `/api/v1` + `success/data` envelope 为准，TDL 原 `/v1` 口径作为历史目标记录 |
| BE-001 | 重构 Express 启动结构 | ✅ 已完成 | `src/app.js` + `src/server.js` | 测试可导入 app，不会自动监听端口 |
| BE-002 | 建立环境配置与 Secret 规范 | ✅ 已完成 | `.env.example` + `src/config/env.js` | Zod 校验，缺少必需变量时启动失败 |
| BE-003 | 接入 PostgreSQL 与 Prisma | ✅ 已完成 | `src/db/prisma.js` + Prisma Client | `/health` 可区分应用与 PostgreSQL 状态 |
| BE-004 | 建立 Prisma Schema 与迁移基线 | 🟡 迁移基线完成，数据库验证待执行 | `prisma/schema.prisma` + `prisma/migrations/202606050001_initial_schema/` + `seed.js` | 已生成 initial migration；需在 PostgreSQL 环境执行 deploy/seed |
| BE-005 | 建立统一响应与错误处理中间件 | ✅ 已完成 | `src/shared/api-error.js` + `response.js` + `error-handler.js` | 统一 envelope 和 requestId |
| BE-006 | 建立认证中间件 | ✅ 已完成 | `src/middleware/auth.js` | JWT 校验、可选认证、权限门禁 |
| BE-007 | 建立参数校验 | ✅ 已完成 | `src/middleware/validate.js` | Zod-based，非法定返回 `40001` |
| BE-008 | 建立结构化日志与敏感信息脱敏 | ✅ 已完成 | `src/shared/logger.js` + `request-id.js` | Pino + redact |
| BE-009 | 建立自动化测试框架 | ✅ 已完成 | `test/` 目录 + 2 个测试套件 | Node test runner，5 个测试通过 |
| BE-010 | 建立 CI | ✅ 已完成 | `.github/workflows/backend-node-ci.yml` + `eslint.config.js` | GitHub Actions 执行 install、Prisma generate、lint、test |
| BE-011 | 清理 EN 占位与独立解读服务直连耦合 | ✅ 已完成 | — | Node 后端无旧代码残留 |
| BE-012 | 建立 PostgreSQL 开发环境 | ✅ 已完成 | `docker-compose.yml` + `.env` | PostgreSQL 16，一键启动 |
| BE-013 | 建立数据库幂等与敏感接口限流 | ✅ 已完成 | `src/middleware/idempotency.js` + `rate-limit.js` + `RateLimitBucket` | 生产限流决议为 PostgreSQL bucket，开发/测试可用内存 fallback |
| BE-014 | 建立 PostgreSQL Outbox / Jobs 机制 | ✅ 已完成 | `OutboxJob` 模型 + `src/workers/outbox.js` | 支持锁定、重试、失败记录；通知推送任务已写入 outbox |

**Phase 0 功能进度：15/15；上线验收见 DB-001**

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
| OPS-001 | 数据迁移与种子数据 | 🟡 Seed 完成，迁移待验收 | `prisma/seed.js` | 种子脚本已创建；缺 migration 基线和真实 PostgreSQL migrate/seed 记录 |
| OPS-002 | 自动化备份与恢复演练 | 🟡 能力具备，演练待执行 | `scripts/db-backup.js` + `scripts/db-restore.js` + `docs/ops-runbook.md` | 支持 dry-run、备份 manifest、恢复命令；需预发布恢复记录 |
| OPS-003 | 安全检查 | 🟡 本地检查完成，安全验收待执行 | `scripts/security-check.js` + `npm run ops:security-check` | 已检查配置基线；需依赖审计、Secret 扫描、越权/重放/上传/隐私泄露测试 |
| OPS-004 | 性能压测 | 🟡 脚本完成，压测报告待执行 | `scripts/perf-smoke.js` + `npm run ops:perf-smoke` | 支持并发、p50/p95、错误率；需 Feed/评论/仪式会话场景报告 |
| OPS-005 | 灰度开关与回滚 | 🟡 能力具备，回滚演练待执行 | `src/shared/feature-flags.js` + `src/modules/admin/route.js` + `docs/ops-runbook.md` 回滚章节 | 10 个 feature flag，需预发布关闭发布/评论/报名/订单演练 |
| OPS-006 | 生产监控与告警 | 🟡 能力具备，告警联调待执行 | `/api/v1/ready` + `/api/v1/metrics` + `scripts/alert-check.js` | 记录请求数、状态码、错误率、耗时；需 Dashboard/Webhook 告警记录 |
| OPS-007 | 隐私与数据删除验收 | 🟡 脚本完成，隐私验收待执行 | `scripts/data-deletion.js` + `npm run ops:data-export` / `ops:data-delete` | 支持用户数据导出和删除；需注销、删除、日志脱敏验收记录 |
| OPS-008 | 前后端契约回归 | 🟡 测试骨架完成，Flutter 联调待执行 | `test/contract/flutter-contract.test.js` | 覆盖主链路契约骨架；需当前 Flutter 页面真实联调报告 |

**Phase 8 功能进度：8/8；上线验收：0/8**

---

## Phase 9：P2 长期社区价值

> 目标：主链路稳定后增强社区长期价值

| ID | 任务 | 状态 | 交付物 | 备注 |
|----|------|------|--------|------|
| IDENTITY-001 | 显式匿名身份 | ✅ 已完成 | `src/modules/profile/anonymous-service.js` + `AnonymousProfile` 模型 | 随机匿名昵称 + avatar 种子 |
| COMMUNITY-013 | 匿名发布与匿名互动 | ✅ 已完成 | `POST /profile/me/anonymous/post` | 后端仍可审计真实用户，前端只见匿名身份 |
| FEEDBACK-001 | 解读结果反馈 | ✅ 已完成 | `src/modules/ritual/feedback-service.js` + `RitualFeedback` 模型 | 用户可在后续补充事情发展与感受 |
| COMMUNITY-014 | 反馈帖与阶段性复盘 | ✅ 已完成 | `POST /ritual/feedback/:id/publish` | 反馈可关联原会话，不泄露私密问题 |
| RECOMMEND-001 | 推荐与深谈分发深化 | ✅ 已完成 | `src/modules/community/recommend.js` | 可解释的分发规则，支持多样性过滤 |
| CASE-001 | 结构化案例检索 | ✅ 已完成 | `src/modules/ritual/case-service.js` | 支持问题类型、卦象结构、关键词筛选 |
| REVIEW-001 | 周期性情绪与成长报告 | ✅ 已完成 | `GET /ritual/me/periodic-review` | 输出近 N 天主题、反馈与关注点回顾 |

**Phase 9 进度：7/7**

---

## 上线验收矩阵

> 依据 TDL 6.4、6.5、6.6、6.8 与第 9 章最终验收。只有下列验收项完成后，后端才可从“功能实现完成”进入“上线完成”。

| ID | 验收项 | 状态 | 验收证据 | 当前缺口 |
|----|--------|------|----------|----------|
| CONTRACT-001 | 正式 API 口径决议 | ✅ 已完成 | `docs/api-contract-decision.md` | 决议保留 `/api/v1` 和 `success/data` 作为当前实现契约；未来如需 `/v1` 另开兼容层任务 |
| DB-001 | Prisma migration 基线与回滚 | 🟡 部分完成 | `prisma/migrations/202606050001_initial_schema/migration.sql` + `docs/db-migration-baseline.md` | migration 基线已生成；真实 `migrate deploy`、`seed`、恢复验证待 PostgreSQL 环境执行 |
| RATE-001 | 生产级敏感接口限流策略 | ✅ 已完成 | `RateLimitBucket` + `202606050002_rate_limit_buckets` + `docs/rate-limit-strategy.md` + `test/unit/rate-limit.test.js` | 生产要求 `RATE_LIMIT_STORE=database`；真实表创建随 DB-001 deploy 执行 |
| AGENT-001 | 独立 Agent 接入边界与联调计划 | ✅ 已完成 | `docs/agent-integration-boundary.md` | 已明确业务后端与 Agent 的认证、请求/响应、超时、重试、降级、结果缓存、SSE relay 和后续联调计划；当前不实现生成能力 |
| TEST-001 | API 集成测试主链路 | 🔲 未开始 | 登录、仪式、社区、通知、同频、活动、媒体、资料、账单等 API 集成测试报告 | 当前以单元测试和契约骨架为主 |
| TEST-002 | 安全测试主链路 | 🔲 未开始 | 无 Token/过期 Token/越权/Idempotency 重放/非法上传/私密泄露/审核绕过测试记录 | 当前仅有本地安全配置检查 |
| OPS-VERIFY-001 | 备份恢复演练 | 🔲 未开始 | 预发布数据库备份文件、恢复命令、恢复后校验记录 | 当前只有 dry-run 脚本 |
| OPS-VERIFY-002 | 性能压测报告 | 🔲 未开始 | Feed、帖子详情、评论创建、仪式会话创建的 P95 与错误率报告 | 当前只有压测脚本 |
| OPS-VERIFY-003 | 监控 Dashboard 与告警联调 | 🔲 未开始 | Dashboard 截图/链接、错误率和延迟告警触发记录、Webhook 记录 | 当前只有 `/metrics` 与 alert-check 脚本 |
| FE-CONTRACT-001 | Flutter 主页面契约回归 | 🔲 未开始 | 当前 Flutter 页面 Auth→Profile→Ritual→Community→Notification→Match→Activity 的真实后端联调记录 | 契约测试骨架已存在，默认跳过；真实执行需 PostgreSQL + `RUN_CONTRACT_DB=1` |
| ADAPTER-001 | 生产外部服务适配验收 | 🔲 未开始 | SMS、微信/QQ、对象存储、Push、支付回调验签的生产或预发布配置与回归记录 | 当前多为 mock/dev fallback |

**上线验收进度：3/11**

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
│   ├── ops-runbook.md                          # 备份、恢复、安全检查、压测、监控和 Git 版本管理步骤
│   ├── api-contract-decision.md                # 正式 API 口径决议
│   ├── db-migration-baseline.md                # Prisma migration 基线与部署/回滚说明
│   ├── rate-limit-strategy.md                  # 生产级敏感接口限流策略
│   └── agent-integration-boundary.md           # 独立 Agent 接入边界与联调计划
├── openapi/
│   └── openapi.yaml                            # OpenAPI 3.1 契约（全模块）
├── prisma/
│   ├── migrations/                             # Prisma migration 基线
│   │   ├── migration_lock.toml
│   │   ├── 202606050001_initial_schema/migration.sql
│   │   └── 202606050002_rate_limit_buckets/migration.sql
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
│       ├── monitoring.test.js                  # 运行指标与告警规则测试
│       └── rate-limit.test.js                  # 敏感接口限流策略测试
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
| API 口径与 TDL 不一致 | ✅ 已决议 | CONTRACT-001 已决定当前以后端实现的 `/api/v1` 与 `success/data` envelope 为准，未来如需 `/v1` 另开兼容层任务 |
| 私密问题泄露到社区 | ✅ 已落地 | 社区发布校验卡归属与 communitySafeContent，只返回公开版 cardPreview |
| 社区内容安全不足 | ✅ 已解决 | 发布/评论前审核、举报/屏蔽、审核记录和审核后台已实现 |
| 同时开发全部模块 | ✅ 已避免 | 严格按 M0→M5 里程碑推进 |
| 缺少自动化测试 | ⚠️ 部分解决 | CI、lint、基础测试、契约骨架已补；API 集成测试与安全测试待补 |
| 无 Docker/PostgreSQL 环境 | ⚠️ 当前限制 | Docker Compose、备份/恢复脚本已创建，需在有 Docker 环境时运行迁移、seed 与恢复演练 |
| 生产适配与预发布演练未完成 | ⚠️ 待验收 | ADAPTER-001、OPS-VERIFY-001~003 补齐真实 provider、恢复、压测、监控告警记录 |
| 当前环境 npm 全局命令不可用 | ⚠️ 当前限制 | 使用内置 Node 直接调用本地 CLI；Git 已通过 `D:\Git\cmd\git.exe` 可用 |

---

## 下一步行动

### 优先级 P0（修正完成口径并补上线验收）
1. **DB-001** → 在 PostgreSQL 环境执行 `npm run db:deploy` / `npm run db:seed`，记录验证与恢复方案。
2. **TEST-001 / TEST-002** → 补 API 集成测试与安全测试，覆盖 TDL 6.5 中的主链路。
3. **FE-CONTRACT-001** → 用当前 Flutter 页面跑真实后端联调，形成契约回归记录。

### 优先级 P1（预发布演练）
5. **OPS-VERIFY-001 ~ 003** → 预发布恢复演练、性能压测报告、Dashboard/告警联调记录。
6. **ADAPTER-001** → SMS、社交登录、S3、Push、支付回调验签的生产/预发布适配验收。

### 已完成的边界决议
- **AGENT-001** → 已明确业务后端与独立 Agent 的接入边界、超时重试、降级、结果缓存和 SSE relay 后续计划；真实 Agent adapter 与预发布联调另行进入实现/验收任务。

---

## 更新日志

| 日期 | 内容 |
|------|------|
| 2026-06-05 | 本轮验收推进：完成 AGENT-001，新增 `docs/agent-integration-boundary.md`，冻结业务后端与独立 Agent 的认证、请求/响应、SSE relay、超时重试、降级和缓存边界；上线验收进度更新至 3/11 |
| 2026-06-05 | 本轮验收推进：完成 RATE-001，新增 `RateLimitBucket`、DB-backed 限流策略、生产安全检查和限流单测；上线验收进度更新至 2/11 |
| 2026-06-05 | 本轮验收推进：完成 CONTRACT-001 API 口径决议；生成 Prisma initial migration 基线并补 `db:deploy` 与迁移说明；DB-001 标为部分完成；上线验收进度更新至 1/11 |
| 2026-06-05 | 本轮文档校准：根据 TDL/PRD 将进度拆分为“功能实现进度”和“上线验收进度”；新增 11 项上线验收矩阵；修正 API 口径、迁移、限流、OPS dry-run、联调和生产适配的完成状态 |
| 2026-06-04 | 本轮追加：补 OPS-004 性能压测脚本、OPS-006 ready/metrics 监控端点与告警检查脚本；同步 OpenAPI、Runbook 和测试；更新进度至 82/92 |
| 2026-06-04 | 本轮完成：OPS-005 灰度开关（10 个 feature flag + admin API + 回滚手册）、OPS-007 隐私删除（数据导出/删除脚本）、OPS-008 契约回归测试（Flutter 主链路覆盖）；更新进度至 85/92 |
| 2026-06-04 | 本轮完成：Phase 9 P2 功能 — IDENTITY-001 匿名身份、COMMUNITY-013 匿名发布、FEEDBACK-001 解读反馈、COMMUNITY-014 反馈帖、REVIEW-001 周期回顾；更新进度至 90/92 |
| 2026-06-04 | 本轮完成：RECOMMEND-001 推荐分发深化（可解释规则 + 多样性过滤）、CASE-001 结构化案例检索（问题类型/卦象/关键词筛选）；更新进度至 92/92（100%） |
| 2026-06-04 | 本轮追加：在文档最前面补 Git 版本管理要求；补 OPS-002 备份/恢复演练脚本与 Runbook、OPS-003 本地安全检查脚本和测试；更新进度至 80/92 |
| 2026-06-04 | 本轮追加：补 SHARE-002 服务端 SVG 分享图、NOTIFY-006 系统通知运营入口、RITUAL-009 情绪校准与周期回顾；同步 OpenAPI；更新进度至 78/92 |
| 2026-06-04 | 本轮追加：删除临时快照；补审核后台、公开主页、活动管理和 Analytics 指标；更新进度至 75/92 |
| 2026-06-04 | 本轮更新：补 CI、Prisma 模型、社区审核与公开卡校验、通知、媒体、账单、同频、活动、分享、反馈、Outbox worker；修正进度统计口径 |
| 2026-06-04 | 初始创建。完成 Phase 0 全部工程基础、Phase 1 认证与个人资料、Phase 2 额度管理、Phase 3 仪式数据链路、Phase 4 社区核心功能 |
