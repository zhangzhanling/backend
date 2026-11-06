# 模块 B 专项学习计划：关系型数据库与 SQL

> 依据：`BACKEND_MASTER_PLAN.md`（总纲，最高层依据）、`BACKEND_ROADMAP.md`（任务规则）。
> 定位：主路径第 2 位（模块 A 之后、模块 C 并行），求职优先级 P0，直接支撑主项目 M1（数据库基础）与 M3（事务与并发）验收。
> 原则：先原生 SQL，后 ORM；理解优先于默写；每个知识点完成"能答 → 能扛追问 → 能审查 AI 输出"的闭环。

---

## 〇、学习模式（2026-10-31 与学习者共同确认的修订版）

AI coding 已能高质量生成 SQL，因此本模块**不以手写 SQL 熟练度为目标**，改为以下模式：

### 1. 主线：问答驱动（每天的核心）

- 每天围绕一个主题，由 AI 出 6–8 道**面试高频核心题**。
- 学习者先凭理解作答（口语化、要点式均可），AI 逐题批改：
  - 答对 → 立即追问（模拟真实面试往深里挖一层）。
  - 答错 → 先纠正，讲清为什么，学习者当天重答。
  - 答不上 → 标记为薄弱项，学习者查资料后重答。
- 所有题目、回答、追问、改进版回答记录到 `INTERVIEW_QUESTIONS.md`。

### 2. 实验：只保留"原理验证型"，砍掉"默写型"

- 不再要求不看教程手写 SQL。
- 每个原理级知识点保留一个 10–20 分钟的最小验证实验：**目的是亲眼看到刚回答的原理真实发生**（如 NULL 三值逻辑、死锁、索引失效）。
- 实验 SQL 可以由 AI 生成，学习者负责执行、观察、用自己的话解释现象。

### 3. AI 协作边界（AI 时代的数据库能力 = 审查与判断）

- 主项目的建表 SQL、查询、索引方案由 AI 起草，学习者做 design review：指出类型选错、约束缺失、索引不合理之处。
- 这个审查过程本身就是核心训练，成果可写进简历。
- 判断"AI 写得对不对"的能力，来自原理理解 + 验证实验，这正是问答主线提供的。

### 4. 不变的底线（总纲要求）

- 背诵答案不算掌握：每道题必须能扛住至少一层追问。
- 原理必须见过实验现象：特别是事务、隔离级别、锁、索引失效。
- 每周复盘日凭记忆重答薄弱题，滚动回测。

---

## 一、模块定位与学习目标

### 1. 定位

- 已有基础：会写业务接口和基本 SQL（CRUD、简单 JOIN），但**设计、事务、索引不扎实**——本模块正是补齐这三块。
- 依赖关系：模块 A（HTTP / Linux / 进程端口）为其前置；本模块是模块 D（API 幂等、并发写入）、模块 E（异步任务一致性）、模块 F（事务边界、领域建模）、模块 H（慢查询优化、复制分区）的共同地基。
- 与主项目结合：M1 验收物（ER 图、数据字典、建表 SQL、约束、核心查询、索引方案）即本模块 B1–B3 阶段的工程交付物；M3 验收物（事务回滚、并发更新、死锁处理）即 B4 阶段的交付物。

### 2. 完成本模块后应具备的能力（验收总目标）

1. 面试中能独立回答本模块核心题，并扛住追问（基础题、原理题、场景题、方案比较题）。
2. 能审查 AI 生成的 schema / SQL / 索引方案，指出并修正问题。
3. 能解释索引原理并用 EXPLAIN ANALYZE 定位常见慢查询。
4. 能解释事务、ACID、隔离级别、锁、MVCC、死锁，并亲手用实验验证过。
5. 能为并发更新、重复请求设计正确的处理方案（唯一约束、乐观锁、悲观锁、幂等）。
6. 能管理迁移、连接池、备份恢复，并理解基本数据库安全。

---

## 二、前置知识与起步环境

| 前置项 | 要求 | 检查方式 |
|---|---|---|
| 模块 A 基础 | 会用命令行、理解进程/端口/环境变量 | 能把 PostgreSQL 跑起来并连上 |
| 基本 SQL | 会写 SELECT / INSERT / WHERE / 简单 JOIN | 第一组题中自然暴露，不单独自测 |
| 主项目需求 | 知道有哪些实体 | 能口头列出用户、知识资源、标签、收藏集、文档、任务等实体 |

**起步环境（Day 1 用 30 分钟完成，可让 AI 协助）：**

- PostgreSQL 16（推荐 Docker：`docker run --name pg -e POSTGRES_PASSWORD=dev -p 5432:5432 -d postgres:16`）。
- 客户端：`psql` 命令行 + 一个 GUI（DBeaver / TablePlus 任选）。
- 练习库两个：`sandbox`（实验专用，随便折腾）和 `knowledge_base`（主项目库）。
- 所有实验 SQL 落盘到 `D:\person\backend\labs\module-b\`，按日期命名。

---

## 三、完整知识地图

标注说明：【P0】求职必备必须精通；【P1】需要理解并能实验；【P2】了解即可，后续深入。

### B1 数据建模与约束（基础，全部 P0）

```
关系模型基础
├── 关系 / 表 / 行 / 列 / 模式（schema）          【P0】
├── PostgreSQL 数据类型与选型                     【P0】
│   ├── 数值：int / bigint / numeric(不用 float 存金额)
│   ├── 文本：text / varchar
│   ├── 时间：timestamptz（默认） vs timestamp
│   ├── jsonb 适用场景与代价                      【P1】
│   └── 主键选型：identity vs bigserial vs UUID   【P0】
├── NULL 语义、默认值、三值逻辑                    【P0】
└── 约束体系（全部 P0）
    ├── PRIMARY KEY / UNIQUE / NOT NULL / CHECK
    ├── FOREIGN KEY 与 ON DELETE / ON UPDATE 行为
    └── 约束违反时的报错与事务影响
实体关系设计
├── 一对一 / 一对多 / 多对多（关联表）             【P0】
├── 主项目实体：user / resource / tag / resource_tag / collection / document / task
├── 逻辑删除 vs 物理删除                          【P0】
└── 规范化（1NF–3NF）与反规范化冗余字段的取舍       【P0/P1】
```

### B2 SQL 查询进阶（基础到进阶，P0 为主）

```
增删改
├── INSERT ... RETURNING / ON CONFLICT（upsert） 【P0】
├── UPDATE / DELETE 与 RETURNING、批量操作        【P0】
查询结构
├── SELECT 执行顺序（FROM→WHERE→GROUP→HAVING→SELECT→ORDER→LIMIT）【P0】
├── JOIN：INNER / LEFT / FULL，JOIN 与 WHERE 过滤的差异【P0】
├── 子查询：标量 / IN / EXISTS，相关子查询         【P0】
├── CTE（WITH）与递归 CTE                         【P0/P1】
├── 聚合：GROUP BY / HAVING / FILTER              【P0】
├── 窗口函数：ROW_NUMBER / RANK / LAG / 累计和 / OVER 分区【P0】
└── 集合运算：UNION / INTERSECT / EXCEPT          【P1】
分页排序过滤
├── OFFSET 分页及其深分页问题                     【P0】
├── Keyset（游标）分页                            【P0】
└── 动态排序、多条件过滤的正确写法                 【P1】
```

### B3 索引与执行计划（进阶，P0）

```
索引原理
├── B-tree 结构、为什么快、代价是什么             【P0】
├── 主键索引 vs 二级索引                          【P0】
├── 联合索引与最左前缀                            【P0】
├── 覆盖索引                                      【P1】
├── 部分索引（partial index）                     【P1】
├── 表达式索引                                    【P1】
├── 何时索引失效：函数包裹、隐式转换、前导模糊、低选择性【P0】
└── 索引的写入代价与膨胀                          【P1】
执行计划
├── EXPLAIN vs EXPLAIN (ANALYZE, BUFFERS)         【P0】
├── Seq Scan / Index Scan / Bitmap Scan / Nested Loop / Hash Join【P0】
├── 行数估算（cost / rows）与实际偏差             【P1】
├── 慢查询日志（log_min_duration_statement）      【P0】
└── 常见慢查询模式与优化套路                      【P0】
```

### B4 事务、锁与并发（进阶，P0，验收最严格）

```
事务基础
├── ACID 逐条含义与 Postgres 实现方式              【P0】
├── BEGIN / COMMIT / ROLLBACK / SAVEPOINT         【P0】
├── 自动提交与隐式事务                            【P0】
隔离级别
├── READ COMMITTED / REPEATABLE READ / SERIALIZABLE【P0】
├── 脏读 / 不可重复读 / 幻读 / 序列化异常          【P0】
└── MVCC：快照、xmin/xmax、为什么读不阻塞写        【P0】
锁
├── 行锁（FOR UPDATE / FOR SHARE）                【P0】
├── 表锁与意向锁概念                              【P1】
├── 咨询锁（advisory lock）                       【P1】
└── 死锁：成因、检测、排查（pg_locks）、避免策略   【P0】
并发模式
├── 乐观锁（version 列）                           【P0】
├── 悲观锁（SELECT ... FOR UPDATE）               【P0】
├── 唯一约束兜底防重                              【P0】
├── ON CONFLICT 幂等写入                          【P0】
└── 丢失更新 / 写偏斜（write skew）场景实验        【P0/P1】
维护概念
├── VACUUM、死元组、表膨胀的基本概念               【P1】
└── 长事务的危害（膨胀、锁持有）                   【P1】
```

### B5 工程化与运维（进阶，P1 为主）

```
├── 迁移管理：为什么不能用 ORM auto-sync，迁移文件规范【P0】
├── 连接池：为什么需要、Node 侧 pg Pool 配置       【P0】
├── 备份恢复：pg_dump / pg_restore 验证流程        【P1】
├── 数据库安全：最小权限账号、密码管理             【P1】
└── 容量与监控常识                                【P2】
```

### 阶段划分与预估时间

每天 2–3 小时，每周 6 天 + 1 天复盘，共约 **6 周**：

| 阶段 | 内容 | 时间 | 阶段交付物 |
|---|---|---|---|
| B1 | 数据建模与约束 | 第 1 周 | 题组 1–5 全部通过 + AI 起草、本人审查的主项目建表 SQL + DATABASE_DESIGN.md 初稿 |
| B2 | SQL 查询进阶 | 第 2 周 | 查询题组通过 + 核心查询集审查记录 + 分页方案对比实验 |
| B3 | 索引与执行计划 | 第 3 周 | 索引题组通过 + 3 个慢查询优化案例（EXPLAIN 前后对比） |
| B4 | 事务、锁与并发 | 第 4–5 周 | 事务题组通过 + 并发实验报告（达成 M3 验收） |
| B5 | 迁移、连接池、备份、安全 | 第 6 周 | 迁移流程 + 备份恢复演练记录 |

时间紧张时的取舍：宁可压缩 B5 和 B2 的 P1 内容，也要保住 **B1 建模、B3 索引、B4 事务** 三块求职命脉。

---

## 四、第一周详细计划（B1：数据建模与约束）

目标：B1 全部核心题能答、能扛追问；完成主项目 schema 的 AI 起草 + 本人审查。

### Day 1：环境 + 题组 1「关系模型与数据类型」

- 环境（30 min）：PostgreSQL 跑起来，建好 `sandbox` 和 `knowledge_base`。
- 问答主线（90 min）：8 道核心题 → 作答 → 批改 → 追问 → 重答。
- 验证实验（20 min）：float 精度误差对比、timestamp vs timestamptz 时区行为（SQL 可由 AI 生成）。
- 交付：题组 1 问答记录入 `INTERVIEW_QUESTIONS.md`；实验现象一句话结论。
- 用时：约 2.5 h。

### Day 2：题组 2「NULL 语义与约束体系」

- 问答主线（90 min）：NULL 三值逻辑、UNIQUE 与 NULL 的关系、CHECK、外键 ON DELETE 三种行为、"外键要不要用"的业界争议。
- 验证实验（30 min）：`WHERE col = NULL` 查不到、UNIQUE 下插入两个 NULL、违反外键的报错、RESTRICT vs CASCADE 行为对比。
- 交付：问答记录 + 4 个实验现象结论。
- 用时：约 2.5 h。

### Day 3：题组 3「实体关系设计与规范化」

- 问答主线（90 min）：1:1 / 1:N / M:N 建模、为什么 M:N 必须用关联表、逗号分隔存多值为什么是错的、1NF–3NF 各一句话、冗余字段取舍、逻辑删除 vs 物理删除。
- 应用（40 min）：让 AI 根据主项目需求生成 ER 图草案，学习者审查：关系是否完整、关联表是否正确、有无违反规范化。
- 交付：问答记录 + 审查后的 ER 图 v1。
- 用时：约 2.5 h。

### Day 4：主项目 schema 审查实战

- 流程（2 h）：
  1. 让 AI 根据 ER 图生成完整建表 SQL（类型、约束、ON DELETE 行为、默认值）。
  2. 学习者逐表审查：类型选对了吗？NOT NULL / UNIQUE / CHECK 缺了吗？外键删除行为合理吗？主键选型理由？
  3. AI 解释每一处质疑，学习者判断是否接受——这是答辩训练。
- 交付：`migrations/0001_init.sql`（定稿）+ `DATABASE_DESIGN.md` 初稿（含每处审查决策的记录）。
- 用时：约 2.5 h。

### Day 5：题组 4「增删改进阶与幂等写入」

- 问答主线（80 min）：RETURNING 解决什么、ON CONFLICT 两种模式、为什么 upsert 是幂等的数据库地基、批量插入怎么做、UPDATE 不带 WHERE 的防护。
- 验证实验（40 min）：造种子数据 + `generate_series` 造 10 万行（为 B3 备料）；ON CONFLICT 连跑两次验证幂等。
- 交付：问答记录 + `seed.sql`。
- 用时：约 2.5 h。

### Day 6：模拟面试日

- 混合抽题（90 min）：从题组 1–4 随机抽 6 题，计时作答，AI 扮演面试官连续追问。
- 薄弱项重答（40 min）：本周所有标记过的薄弱题重考。
- 交付：模拟面试表现记录；仍答不好的进入下周复盘清单。
- 用时：约 2.5 h。

### Day 7：复盘日（每周固定）

- 凭记忆重答 3 道本周最重要的题（不看笔记）。
- 更新 `BACKEND_PROGRESS.md`：本周掌握 / 只看过 / 实验结论 / 项目成果 / 下周三个任务。
- 用时：约 2 h。

### 第一周验收标准

- [ ] 题组 1–4 共约 30 题全部能答，且每题至少扛住一层追问。
- [ ] 能指出 AI 生成 schema 中至少 2 处真实问题并修正。
- [ ] 能解释 NULL 三值逻辑、float 精度、ON CONFLICT 幂等，且每个都见过实验现象。
- [ ] `0001_init.sql` + `DATABASE_DESIGN.md` + `INTERVIEW_QUESTIONS.md` 落盘可检查。

---

## 五、后续阶段预告（待第一周验收后逐周细化）

- **B2（第 2 周）**：题组覆盖 JOIN、子查询、CTE、窗口函数、执行顺序、分页；实验保留深分页对比、LEFT JOIN 被 WHERE 过滤成 INNER JOIN 等经典坑。
- **B3（第 3 周）**：题组覆盖 B-tree、联合索引、最左前缀、索引失效场景、EXPLAIN 读法；对 10 万行数据做 3 个慢查询优化案例（前后 EXPLAIN 对比）。
- **B4（第 4–5 周）**：题组覆盖 ACID、隔离级别、MVCC、锁、死锁、乐观/悲观锁；两个 psql 会话对打实验不可省略；达成主项目 M3 验收。
- **B5（第 6 周）**：迁移工具落地、连接池打满实验、pg_dump 恢复演练、最小权限改造。

---

## 六、常见误区与易混淆清单（本模块高频）

1. `WHERE col = NULL` 永远查不到——NULL 要用 `IS NULL`。
2. UNIQUE 不约束 NULL（Postgres 默认多个 NULL 共存）——防重要靠 NOT NULL + UNIQUE 组合。
3. `timestamp` 不带时区是坑，默认用 `timestamptz`。
4. float 存金额会因二进制浮点误差出错，用 `numeric`。
5. 逗号分隔存多值（tag id 列表）——违反 1NF，查询和约束全部失效。
6. LEFT JOIN 后在 WHERE 里过滤右表列——实际被过滤成了 INNER JOIN。
7. OFFSET 深分页越翻越慢且可能漏数据——正确方案是 Keyset 分页。
8. 以为建索引一定快——索引有写入代价，低选择性列建索引无用。
9. 以为 SELECT 不加锁就无并发问题——丢失更新恰恰发生在"读了改、改回写"之间。
10. 长事务不只是"慢"——持有锁、阻碍 VACUUM、导致表膨胀。

## 七、面试题与回答框架（本模块核心题方向）

- 基础题：JOIN 类型区别？UNION vs UNION ALL？主键和唯一索引区别？
- 原理题：索引为什么快（B-tree）？MVCC 怎么实现读写不互锁？四个隔离级别分别防住什么异常？
- 场景题：重复点击收藏产生重复数据怎么办？（唯一约束 + ON CONFLICT）；两人同时编辑怎么防覆盖？（乐观锁）；千万级深分页怎么优化？（Keyset）。
- 方案比较题：自增 ID vs UUID；逻辑删除 vs 物理删除；OFFSET vs Keyset；乐观锁 vs 悲观锁。
- 追问规则：每个答案准备时自带一层追问（"为什么""代价是什么""数据量大了怎么办"）。

## 八、推荐资料（精选，不堆砌）

1. **PostgreSQL 官方文档**（postgresql.org/docs/16）：Chapter 5 (Data Definition)、Chapter 13 (Concurrency Control)——原理类问题的最终依据。
2. **use-the-index-luke.com**：索引原理与最左前缀的最佳讲解，B3 阶段核心读物。
3. **《PostgreSQL Internals》（Egor Rogov，免费 PDF）**：MVCC 与事务内部机制，B4 阶段选读。
4. **SQLBolt**（sqlbolt.com）：仅用于语法快速过一遍。
5. 主项目代码库本身：所有知识的最终落点。

## 九、复习与补强机制

- 每周 Day 6 模拟面试 + Day 7 复盘（凭记忆重答 + 薄弱项重考）。
- B3 结束时做"模块中期考"：混合抽题 + 一次真实 schema 审查。
- 真实面试中被问住的题，48 小时内记入 `INTERVIEW_QUESTIONS.md`，写改进版回答，下周重考。
- 间隔重复：第 N 周复盘日抽 1–2 道第 1..N-1 周的旧题滚动回测。
