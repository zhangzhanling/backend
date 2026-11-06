# DATABASE_DESIGN.md — 个人 AI 知识库 · 数据库设计（草案 v0.1）

> 状态：**已审查 v0.2**（2026-11-06 学习者完成 A–D 组 design review，两处修订：collection_item.resource_id 改 CASCADE、resource 加部分唯一索引与行级 CHECK）。下一步：按本设计生成建表 SQL（0001_init.sql）并在 knowledge_base 库执行。
> 数据库：PostgreSQL 16。约定：小写蛇形命名；时间默认 `timestamptz`；主键默认 `bigint GENERATED ALWAYS AS IDENTITY`（模块 B Day 1 Q8 决策：默认 bigint）。

---

## 一、ER 总览

```
                        ┌──────────────┐
                        │     "user"    │
                        └──────┬───────┘
           ┌───────────────────┼────────────────────┐
           │ 1:N               │ 1:N                │ 1:N
           ▼                   ▼                    ▼
   ┌──────────────┐    ┌──────────────┐     ┌──────────────┐
   │  collection  │    │   resource    │     │     tag      │
   └──────┬───────┘    └───┬───────┬───┘     └───┬──────────┘
          │ 1:N            │ 1:1   │ 1:N         │ 1:N
          ▼                ▼       ▼             ▼
  ┌───────────────┐  ┌──────────────┐  ┌──────────────────┐
  │collection_item│  │resource_content│ │  resource_tag     │
  │  (M:N 关联表) │  │  (冷热分离)   │  │   (M:N 关联表)    │
  └───────────────┘  └──────────────┘  └──────────────────┘
                              ▲
                              │ 1:N（M4 细化）
                       ┌──────┴───────┐
                       │   document    │
                       └──────────────┘
```

M:N 两处：collection ↔ resource（经 collection_item）、resource ↔ tag（经 resource_tag）。
1:1 一处：resource ↔ resource_content（冷热分离，Day 3 Q3 决策）。

---

## 二、表结构明细

### "user"

| 列 | 类型 | 约束 | 说明 |
|---|---|---|---|
| id | bigint identity | PK | |
| email | text | NOT NULL, UNIQUE | 用户登录标识 |
| password_hash | text | NOT NULL | 哈希值，绝不存明文 |
| created_at | timestamptz | NOT NULL DEFAULT now() | |

- 注销账号采用**物理删除**（合规要求，Day 3 Q6 决策）→ 级联清理其资源、收藏集、标签。

### resource（瘦表：元数据）

| 列 | 类型 | 约束 | 说明 |
|---|---|---|---|
| id | bigint identity | PK | |
| user_id | bigint | NOT NULL FK→"user" ON DELETE CASCADE | 资源主人 |
| title | text | NOT NULL | |
| url | text | | 可空：部分资源为本地上传 |
| note | text | | 用户备注 |
| type | text | NOT NULL DEFAULT 'article' | 资源类型 |
| deleted_at | timestamptz | | 逻辑删除标记（Day 3 Q6） |
| — | — | **CHECK (url IS NOT NULL OR btrim(COALESCE(note,'')) <> '')** | 行级完整性底线（2026-11-06 审查新增：url 与非空 note 至少其一；content 在另一表，完整校验归应用层） |
| — | — | **部分唯一索引 UNIQUE (user_id, url) WHERE deleted_at IS NULL** | 同一用户同一 URL 只收藏一次（2026-11-06 审查拍板：产品理由=无需重复收藏；NULL 行不受约束；软删行不占名额） |
| created_at | timestamptz | NOT NULL DEFAULT now() | |
| updated_at | timestamptz | NOT NULL DEFAULT now() | |

- 正文**不在这张表**（冷热分离，见 resource_content）。
- 所有查询必须带 `WHERE user_id = ? AND deleted_at IS NULL`（Day 3 Q6 坑 1 的工程纪律）。

### resource_content（1:1，冷热分离）

| 列 | 类型 | 约束 | 说明 |
|---|---|---|---|
| resource_id | bigint | **PK**, FK→resource ON DELETE CASCADE | 共享主键，FK²（Day 3 Q3） |
| content | text | NOT NULL | 全文/正文，大文本 |

- 列表查询永不碰此表；详情页才 JOIN。

### tag

| 列 | 类型 | 约束 | 说明 |
|---|---|---|---|
| id | bigint identity | PK | |
| user_id | bigint | NOT NULL FK→"user" ON DELETE CASCADE | 标签主人 |
| title | text | NOT NULL | |
| created_at | timestamptz | NOT NULL DEFAULT now() | |
| | | **UNIQUE (user_id, title)** | 每用户命名空间独立（Day 3 Q8） |

### resource_tag（M:N 关联表）

| 列 | 类型 | 约束 | 说明 |
|---|---|---|---|
| resource_id | bigint | NOT NULL FK→resource ON DELETE CASCADE | |
| tag_id | bigint | NOT NULL FK→tag ON DELETE CASCADE | |
| | | **PK (resource_id, tag_id)** | 防重复打标，双向索引 |
| created_at | timestamptz | NOT NULL DEFAULT now() | |

### collection

| 列 | 类型 | 约束 | 说明 |
|---|---|---|---|
| id | bigint identity | PK | |
| user_id | bigint | NOT NULL FK→"user" ON DELETE CASCADE | 收藏集主人 |
| title | text | NOT NULL | |
| created_at | timestamptz | NOT NULL DEFAULT now() | |

### collection_item（M:N 关联表）

| 列 | 类型 | 约束 | 说明 |
|---|---|---|---|
| collection_id | bigint | NOT NULL FK→collection ON DELETE CASCADE | |
| resource_id | bigint | NOT NULL FK→resource ON DELETE **CASCADE** | 2026-11-06 审查修订（原 RESTRICT）：资源主人==收藏集主人，无第三方；若未来支持收藏他人资源须重审 |
| | | **PK (collection_id, resource_id)** | 同一收藏集不重复收同一资源 |
| created_at | timestamptz | NOT NULL DEFAULT now() | |

### document（解析产物，M4 阶段细化）

| 列 | 类型 | 约束 | 说明 |
|---|---|---|---|
| id | bigint identity | PK | |
| resource_id | bigint | NOT NULL FK→resource ON DELETE CASCADE | 解析产物随资源消亡 |
| status | text | NOT NULL DEFAULT 'pending' | pending/processing/done/failed |
| result | jsonb | | 解析器输出的半结构化结果（Day 1 Q7：jsonb 的适用场景） |
| error_message | text | | 失败原因 |
| created_at / updated_at | timestamptz | NOT NULL DEFAULT now() | |

- 详细状态机与任务队列设计属 M4，此处仅定骨架。

---

## 三、ON DELETE 决策汇总（"谁受损"检验）

| 外键 | 行为 | 决策理由 |
|---|---|---|
| resource.user_id | CASCADE | 账号物理删除，其资源无独立意义 |
| resource_content.resource_id | CASCADE | 1:1 从属，主表删则内容无意义 |
| tag.user_id | CASCADE | 标签是用户私有分类体系 |
| resource_tag 两侧 | CASCADE | 打标关系随任一端消亡，无第三方 |
| collection.user_id | CASCADE | 收藏集无独立意义 |
| collection_item.collection_id | CASCADE | 条目随收藏集消亡（Day 2 Q7） |
| collection_item.resource_id | **CASCADE**（2026-11-06 审查修订，原为 RESTRICT） | 个人知识库中"资源主人==收藏集主人"，无第三方受损；删除确认逻辑在业务层。**重审条款：若未来支持收藏他人资源，必须改回 RESTRICT 或软删除。** |
| document.resource_id | CASCADE | 解析产物从属资源 |

## 三点五、审查记录（2026-11-06，学习者审查）

A 组：1 ✅ 2 ✅ 3 部分——resource↔resource_tag 物理层 1:N / 概念层 M:N（M:N 物理上表现为两个 1:N），两层表述面试都要会说；document 方向存歧义：草案 1:N（无 UNIQUE），审查者质疑应为 1:1——**决策点**：1:N 保留解析历史（重排障刚需），1:1 结构简单丢历史。建议 1:N，待拍板。

B 组：4 ✅ 5 ✅ 7 ✅（RESTRICT 经复核同意）。6 审查者初判"没有遗漏"——抽查：resource.url 可空 ✅（多来源资源：链接收藏/纯笔记/上传文件）；行级完整性结论：**CHECK(url IS NOT NULL OR btrim(COALESCE(note,'')) <> '') 做底线**（NULL≠'' + COALESCE 合体；content 在另一张表 CHECK 管不到 → 完整校验归应用层——"数据库拦明显垃圾，应用层拦业务规则"的分层实践）。

## 四、已记录的开放问题（待审查/后续阶段）

**审查进展（2026-11-06）**：
- C 组：✅ 已解决。审查者找出冲突（user 物理删除 CASCADE 链撞 collection_item.resource_id RESTRICT → 注销删号被挡）并给出解法：改 CASCADE（理由：原 RESTRICT 基于"可收藏他人资源"假设，Day 3 已澄清个人知识库中资源主人==收藏集主人，假设消失决策重审）。**教学点：设计决策挂在产品假设上，假设变了要重审。** 附重审条款：未来若支持收藏他人资源，须改回 RESTRICT/软删。
- D1：✅ 已拍板：加。审查者初判理由"url 可空无法判唯一"❌（UNIQUE 允许多个 NULL，Day 2 Q4），经补全考点后拍板：同一用户同一 URL 只收藏一次（产品理由）。落实为**部分唯一索引** UNIQUE(user_id, url) WHERE deleted_at IS NULL（软删行不占名额）。
- D2：分享功能确认需要；建议 M2 阶段加（依赖认证/权限体系就位）。
- D3：已讲解——document 状态机/任务幂等重试属模块 E 异步任务专项，M4 处理，仅登记。
- D4 ✅：反规范化暂不做。

1. resource.url 是否需要 UNIQUE(user_id, url)？——防止同一用户重复收藏同一链接，但笔记型资源可能没有 url。**待产品决策**。
2. 分享功能（Day 1 Q3：share_token）需要独立 `share_link` 表——M2 之后按需添加，不影响本草案。
3. document 状态机、处理任务的幂等/重试设计——M4 专项。
4. 计数类反规范化（resource 冗余 tag 数量等）——Day 3 Q5 决策：**暂不做**，实测有热点再议。
