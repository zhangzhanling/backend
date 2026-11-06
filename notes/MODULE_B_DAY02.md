# 模块 B · Day 2：NULL 语义与约束体系

> 日期：待开始 ｜ 阶段：B1 数据建模与约束 ｜ 预计用时：约 2.5 小时
> 学习模式：先凭理解作答（不查资料）→ AI 批改 → 追问/重答 → 验证实验
> 前置：Day 1 已完成（题组 1 + 实验 1、2）

---

## 任务 1：题组 2 问答（90 分钟）

**作答要求**：凭当前理解答，不查资料；口语化、要点式均可；不确定标"不确定"；可以跳题。
**今日特别提醒**：昨天的画像显示你在"底层怎么存/怎么算"类问题上直觉易错——今天这组题全是这类，**先怀疑直觉，再作答**。

---

### Q1. NULL 是什么？

它和空字符串 `''`、数字 `0` 是一回事吗？数据库里怎么理解 NULL？

> **标准答案：** 不是一回事。`''` 和 `0` 是确定的值，NULL 不是值，而是"缺失 / 未知 / 不适用"的**状态标记**。物理实现上，NULL 是行头 **NULL 位图（bitmap）** 中的 1 个 bit，NULL 列本身不占用数据空间——不是"空指针"。关键推论："NULL 不是值"是三值逻辑的根源：两个"未知"无法断言相等。

> 我的回答：NULL 和空字符、数字 0 都不是一回事。数据库中存储 null 存储的是空指针？
>
> 批改记录：⚠️ 一半（2026-10-31）。✅ NULL ≠ '' ≠ 0：'' 和 0 是确定的值，NULL 不是值。❌ "空指针"是概念错位：SQL 中 NULL = "缺失/未知/不适用"的**状态标记**；物理上是行头 **NULL 位图（bitmap）** 中的 1 个 bit，NULL 列本身不占用数据空间。关键推论："NULL 不是值" → Q2 三值逻辑的根源（两个"未知"无法断言相等）。
> 重答（2026-10-31）："NULL 存的不是值也不是指针，是用 1 bit 标记这一列是 null。" → ✅ 正确，Q1 闭环。

### Q2. `WHERE col = NULL` 为什么查不到数据？

NULL 参与比较运算时遵循什么逻辑？

> **标准答案：** **三值逻辑**——比较结果有 TRUE / FALSE / **UNKNOWN** 三种，凡涉及 NULL 的比较结果都是 UNKNOWN；WHERE 只保留 TRUE，FALSE 和 UNKNOWN 均被过滤，所以 `WHERE col = NULL` 查出 0 行。推论：**CHECK 约束遇 UNKNOWN 放行**（只为 FALSE 报错），所以 NOT NULL 不可替代。判断 NULL 必须用 IS NULL / IS NOT NULL。

> 我的回答：因为 NULL 不是值，无法参与比较。
>
> 批改记录：⚠️ 原因对、缺机制（2026-10-31）。补全：**三值逻辑**——比较结果有 TRUE/FALSE/**UNKNOWN** 三种，凡涉及 NULL 的比较结果都是 UNKNOWN；WHERE 只保留 TRUE，FALSE 和 UNKNOWN 均被过滤 → `WHERE col = NULL` 查出 0 行。推论：**CHECK 约束遇 UNKNOWN 放行**（只为 FALSE 报错），所以 NOT NULL 不可替代——预告 Q6。
> 重答（2026-11-02）：三值逻辑版复述（TRUE/FALSE/UNKNOWN、NULL 比较得 UNKNOWN、IS NULL 判断）→ ✅ Q2 闭环。实验 1、2 现象已验证（`WHERE NULL = NULL` 返回 0 行）。补充：NULLIF(10,10) 返回 NULL 的原理已讲解（NULLIF = COALESCE 反面；实战：除零保护 NULLIF(x,0)、脏数据归一化）。

### Q3. 如何判断和处理 NULL？

写 SQL 时判断"是 NULL"用什么？想让 NULL 显示成别的值用什么函数？

> **标准答案：** 判断用 **IS NULL / IS NOT NULL**；显示替换用 **COALESCE**（返回参数中第一个非 NULL 值）。注意 IFNULL 是 MySQL 方言，PG 用 COALESCE 保证可移植。实战组合：`COALESCE(NULLIF(note, ''), '无备注')`（NULLIF 两值相等返回 NULL，常用于除零保护 `x / NULLIF(qty, 0)` 和脏数据归一化）。

> 我的回答：IS NULL，使用 COALESCE 将 NULL 值显示成别的值。
>
> 批改记录：✅ 正确（2026-11-02）。COALESCE 返回第一个非 NULL 值；注意 IFNULL 是 MySQL 方言，PG 用 COALESCE 保证可移植。Q3 闭环。

### Q4. UNIQUE 约束的列，能插入多行 NULL 吗？

为什么？（答完做实验 3 验证）

> **标准答案：** 能，可以插入多行 NULL。机制：UNIQUE 靠唯一索引查重，查重是相等比较，任何值与 NULL 比较得 UNKNOWN ≠ TRUE → 判不重复放行（SQL 标准语义"NULL 互不相等"）。PG 15+ 可用 `UNIQUE NULLS NOT DISTINCT` 改变默认。工程结论：语义"允许缺失"的可选唯一列用 UNIQUE + NULL；要 NULL 也算重复，用 NULLS NOT DISTINCT。

> 我的回答：我认为会成功，因为 NULL 无法参与比较。
>
> 批改记录：✅ 完全正确（2026-11-02），且用 Q2 三值逻辑推出——推理链即标准答案。机制补全：UNIQUE 靠唯一索引查重，查重是相等比较，值与 NULL 比较得 UNKNOWN ≠ TRUE → 判不重复放行；SQL 标准"NULL 互不相等"。进阶：PG 15+ 支持 `UNIQUE NULLS NOT DISTINCT` 改变默认。工程结论：NOT NULL 语义上"允许缺失"的可选唯一列用 UNIQUE + NULL；要 NULL 也算重复用 NULLS NOT DISTINCT。
> 待验证：实验 3。
> ✅ 实验 3 已验证（2026-11-02）：双 NULL 均插入成功，重复 email 报错。Q4 闭环。

### Q5. NOT NULL 和 DEFAULT 是什么关系？

INSERT 时不写这一列，数据库的执行顺序是什么？

> **标准答案：** 职责划分：DEFAULT 决定"没写时填什么"，NOT NULL 决定"最终值能否为 NULL"，两者独立且常组合。执行顺序：INSERT 省略列 → 触发 DEFAULT 填值 → 再做 NOT NULL 校验（默认值同样过校验：DEFAULT NULL + NOT NULL 建表合法，但省略列插入即报错）。关键陷阱：**DEFAULT 仅在列被省略时触发；显式 `VALUES (NULL)` 直达约束校验**，撞 NOT NULL 报错。工程形态：ORM / JSON 传 null = 显式插 NULL → 报错（前端转型者高频坑）。防御：应用层把 null 转为省略字段，或列改可空 + DEFAULT。

> 我的回答：INSERT 时不写这列不会报错，因为有 DEFAULT。处理顺序：先设置默认值，再校验非空。有 DEFAULT 没有 NOT NULL，则不校验非空。
>
> 批改记录：✅ 基本正确（2026-11-03）。补全：① 校验同样作用于默认值（DEFAULT NULL + NOT NULL 建表合法，但省略列插入即报错）② 一句话职责：DEFAULT 决定"没写时填什么"，NOT NULL 决定"最终值能否为 NULL"，独立且常组合。
> Q5-追问（2026-11-03）："DEFAULT 为 NULL 则校验报错。" → ❌ 答偏（答的是上一轮补充点）。正确答案：**显式 VALUES (NULL) 时 DEFAULT 完全不生效**——DEFAULT 仅在列被省略时触发；显式给值（含 NULL）直达约束校验，撞 NOT NULL 报错。
> 工程形态：ORM/JSON 传 null = 显式插 NULL → NOT NULL 报错（前端转型者高频坑）。防御：应用层 null → 省略字段，或列改可空 + DEFAULT。
> 待重答：复述"省略才触发，显式给值不参与"。
> ✅ 重答正确（2026-11-03）："只有列省略时才触发默认值；手动设 NULL 不走默认值逻辑，直达非空校验。" Q5 闭环。

### Q6. CHECK 约束什么时候生效？它能做什么、不能做什么？

> **标准答案：** CHECK 在 **INSERT / UPDATE 写入时**校验被写入的行（与 SELECT 查询无关），表达式为 FALSE 才拒绝，UNKNOWN 放行（连回 Q2 三值逻辑）。能做：行级 / 列级的表达式校验。不能做：**跨行 / 跨表 / 聚合校验**（如"库存总数 ≤ 100"），去处 = 应用层事务 / 触发器 / deferred constraint trigger；PG 禁止 CHECK 含子查询（写入中途发起读取，语义嵌套 + 开销不可控）。

> 我的回答：CHECK 只为 false 报错，遇到 UNKNOWN 就会放行；比如本来能查到 2 行，其中一行是 UNKNOWN，就只能查到 1 行。CHECK 只能做列字段校验，无法查表的总数。
>
> 批改记录：⚠️ 两点对、例子错（2026-11-03）。✅ UNKNOWN 放行（连上 Q2）、行级约束不能跨行聚合。❌ 例子张冠李戴："2 行变 1 行"是 WHERE 查询过滤行为，CHECK 与 SELECT 无关——CHECK 只在 INSERT/UPDATE 时校验被写入的行。补全：跨行/跨表/聚合校验（如库存总数≤100）要去处 = 应用层事务 / 触发器 / deferred constraint trigger。
> Q6-追问（2026-11-03）："CHECK 在 INSERT/UPDATE 时机，跨表聚合需要先查看，时机不一致。" → ✅ 正确。补实现层：PG 禁止 CHECK 含子查询（写入中途发起读取，语义嵌套+开销不可控）。Q6 闭环。

### Q7. 外键的 ON DELETE 三种行为

`CASCADE`、`RESTRICT`、`SET NULL` 分别是什么含义？各自适合什么业务场景？（例：collection_item 引用 resource，resource 被删除时你选哪种，为什么？）

> **标准答案：** 前提：ON DELETE 修饰"**删父行时**"，动作落在**子表**。① **CASCADE 级联删除**：自动删所有子行——子记录无独立意义、从属父记录（order_item 随 order）；风险是多级链放大误删。② **RESTRICT 限制删除**：有子行引用即报错，必须先处理子行——防误删的重要引用。③ **SET NULL 置空**：把子表引用列改 NULL（列必须可空）——子记录独立存在、只清归属（作者注销 → 文章 author_id 置 NULL）。默认 NO ACTION ≈ RESTRICT（检查时机可推迟，了解即可）。决策树：随父消亡 → CASCADE；不许删 → RESTRICT；独立存在只清归属 → SET NULL。选型检验框架——谁受损：CASCADE = 用户（收藏无声消失）、RESTRICT = 删除方（报错强制人工决策）、SET NULL = 用户（幽灵条目）；另有技术约束：SET NULL 要求引用列可空。主项目参考答案：**RESTRICT**（不静默修改用户数据 + 软删除为主、真删除需人工审慎）。

> 我的回答：知识盲区（2026-11-03 首答）。
>
> 概念讲解：前提——外键在子表上指向父表主键，ON DELETE 规定"删父行时引用它的子行怎么办"。
> ① CASCADE 级联删除：自动删所有子行。适用：子记录无独立意义、从属父记录（order_item 随 order、document 随 resource）。风险：多级链放大误删。
> ② RESTRICT 限制删除：有子行引用就报错，必须先处理子行。适用：防误删的重要引用。
> ③ SET NULL 置空：引用列改 NULL（列必须可空）。适用：可选归属清空、子记录保留（作者注销 → 文章 author_id 变 NULL）。
> 补充：默认 NO ACTION ≈ RESTRICT（检查可推迟到事务末，RESTRICT 立即检查，了解即可）。
> 决策树：随父消亡 → CASCADE；不许删 → RESTRICT；独立存在只清归属 → SET NULL。
> 重答（2026-11-03）：① CASCADE ✅ ② RESTRICT ✅（本质对：有子行引用父行删不掉）③ SET NULL ❌ **方向反了**——是删**父行**时把**子表引用列**置 NULL，不是删子行改父表。口诀：ON DELETE 修饰"删父行时"，动作落在子表。
> 选型：SET NULL，理由"resource 可能还被其他 collection_item 收集" → ❌ 理由不成立（CASCADE/RESTRICT 同样能处理多处引用，非 SET NULL 独有）。
> 重新推理框架——谁受损：CASCADE=用户收藏无声消失；RESTRICT=管理员删资源被挡（矛盾暴露，需人工决策）；SET NULL=用户得到幽灵条目。技术约束：SET NULL 要求引用列可空，collection_item.resource_id 设计为 NOT NULL 则此路不通。
> 参考答案：RESTRICT（用户数据不被静默吞掉 + 软删除为主的项目里真删除需人工干预）。CASCADE + "条目无独立意义"理由同样合格——关键是理由经得起"谁受损"检验。
> 重答 2（2026-11-03）：SET NULL 方向 ✅（删父行→子表引用列置 NULL）；三方损益：CASCADE=用户受损（收藏无声消失）、RESTRICT=管理员受损（报错强制决策）、SET NULL=用户受损（幽灵条目）；选 RESTRICT ✅。
> 补完整理由：RESTRICT 把矛盾暴露给删除方强制决策，不静默修改用户数据；配合软删除设计，真删除本就需要人工审慎。
> ✅ Q7 闭环。

### Q8. 外键到底要不要用？

业界对此有争议，双方的理由分别是什么？你在自己的项目里用不用，为什么？

> **标准答案：** 争论对象 = 关联关系是否用数据库 FOREIGN KEY 约束强制执行（不是"要不要关联"）。**支持方**：一致性是数据库的职责，应用层校验成本高、易漏。**反对方（完整版三条）**：① 架构失效——分库分表把父子表拆到不同物理节点、微服务把表拆进各服务私有库，跨边界引用数据库无从检查（核心原理：外键只能在单库内执行）；② 写入检查开销；③ 大表 DDL 成本（加外键锁表校验）。结论：外键是架构形态的函数——单库单体用外键，分布式降级为应用层契约（API / 事件）。本项目立场：单体单库，用外键。

> 我的回答（2026-11-03）：支持方——该用外键，保证数据一致性本来就是数据库的职责，如果不用外键，就需要在应用层做校验和约束，实现成本不如外键。反对方——在分库分表或微服务架构下，外键无从谈起，想要也用不了。主项目——个人项目、单体数据库，可使用外键，因为不涉及分库分表。
>
> 铺垫讲解（2026-11-03）：争论对象 = 关联关系是否用数据库 FOREIGN KEY 约束强制执行（非"要不要关联"）。
> 路线对比：声明外键 = 数据库强制一致性+报错明确，代价是写入检查开销/分库分表与微服务下失效/大表 DDL 成本；不声明 = 写入快+架构自由，代价是脏数据静默产生。
> 核心原理：外键只能在**单库内**执行（插入子行时实时查父表）；分库分表把父子表拆到不同物理节点、微服务把表拆进各服务私有库（共享库=分布式单体反模式），跨边界引用数据库无从检查 → 降级为应用层契约（API/事件）。
> 结论：外键是架构形态的函数——单库单体用，分布式靠应用层。
> 待作答：支持方理由 / 反对方理由 / 我的立场与依据（三段式）。【已完成，见上方"我的回答"】
> 作答（2026-11-03）：支持方=一致性是数据库职责，应用层校验成本高 ✅；反对方=分库分表/微服务下无从谈起 ⚠️ 只答"用不了"，缺"用不起"（写入检查开销 + 大表 DDL 锁表校验成本）；立场=单体单库，用外键 ✅。
> 补全：反对方完整版 = 架构失效 + 写入开销 + DDL 成本。
> ✅ Q8 闭环。**Day 2 题组全部完成。**

---

## 任务 2：验证实验（30 分钟，答完对应题目后做）

在 `sandbox` 库执行（SQL 可让 AI 生成），观察现象，写一句话结论。

### 实验 1：NULL vs '' vs 0（对应 Q1、Q2）

```sql
SELECT NULL = '';      -- 预期：NULL（不是 true/false）
SELECT NULL = 0;       -- 预期：NULL
SELECT NULL IS NULL;   -- 预期：true

CREATE TABLE null_demo (id int, note text, score int);
INSERT INTO null_demo VALUES (1, NULL, NULL), (2, '', 0);
SELECT * FROM null_demo WHERE note IS NULL;   -- 预期：只有 id=1
SELECT COUNT(*), COUNT(note) FROM null_demo; -- 预期：COUNT(*) = 2，COUNT(note) = 1
```

> 现象与结论：✅ 已验证（2026-11-02）：步骤 3 输出 NULL（NULL 与 '' 无法比较）；步骤 5 只返回 id=1（空字符串 ≠ NULL 亲眼证实）；步骤 6 输出 2 和 1（COUNT(列) 跳过 NULL，Q3 铺垫）。

### 实验 2：三值逻辑与 COALESCE（对应 Q2、Q3）

```sql
SELECT 1 WHERE NULL = NULL;           -- 预期：0 行（NULL 不是 true，不进结果集）
SELECT COALESCE(NULL, 'default');     -- 预期：default
SELECT NULLIF(10, 10);                -- 预期：NULL
```

> 现象与结论：✅ 已验证（2026-11-02）：`SELECT 1 WHERE NULL = NULL` 返回 0 行（UNKNOWN 被 WHERE 过滤——GUI 中只看到列头 "?column?" integer）；`COALESCE(NULL, 'default')` 返回 default；`NULLIF(10,10)` 返回 NULL（两值相等→无意义→NULL；实战：除零保护 `x / NULLIF(qty, 0)`、脏数据归一化 `COALESCE(NULLIF(note,''),'无备注')`）。

```sql
CREATE TABLE uniq_null (id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, email text UNIQUE);
INSERT INTO uniq_null (email) VALUES (NULL);
INSERT INTO uniq_null (email) VALUES (NULL);   -- 预期：成功！不报错
INSERT INTO uniq_null (email) VALUES ('a@x.com');
INSERT INTO uniq_null (email) VALUES ('a@x.com');   -- 预期：报错，违反唯一约束
```

> 现象与结论：✅ 已验证（2026-11-02）：连续插入两次 NULL 均成功；重复插入 'a@x.com' 报 `Key (email)=(a@x.com) already exists`。Q4 焊死。附带记忆点：唯一约束冲突的报错格式 `Key (列)=(值) already exists` 是生产排障第一线索。

### 实验 4：外键 ON DELETE 行为对比（对应 Q7）

```sql
CREATE TABLE parent (id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY);
CREATE TABLE child_restrict (id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  parent_id bigint REFERENCES parent(id) ON DELETE RESTRICT);
CREATE TABLE child_cascade (id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  parent_id bigint REFERENCES parent(id) ON DELETE CASCADE);

INSERT INTO parent DEFAULT VALUES;  -- id = 1
INSERT INTO child_restrict (parent_id) VALUES (1);
INSERT INTO child_cascade (parent_id) VALUES (1);

DELETE FROM parent WHERE id = 1;   -- 预期：报错（RESTRICT 子表挡着）
-- 删 child_restrict 里那行后再执行上面的 DELETE，观察 child_cascade 的行是否一起消失
```

> 现象与结论：✅ 已验证（2026-11-03）：① RESTRICT 挡删除，报错 `violates RESTRICT setting of foreign key constraint ... Key (id)=(1) is referenced from table "child_restrict"`（含约束名+被引用键值，排障价值高）② 清引用后父行删除成功 ③ child_cascade 0 行——CASCADE 自动级联删除，无需手动操作子表。

---

## 当天交付物

- [ ] Q1–Q8 回答 + 批改记录（本文件）
- [ ] 4 个实验的现象结论（本文件）
- [ ] 答错/跳过的题目标记为薄弱项，重答后更新

## 验收标准

- 8 题全部作答，答错的题能复述修正版。
- Q2（三值逻辑）、Q4（UNIQUE 与 NULL）的结论与实验现象对得上——这两题是今天的焊点，必须亲手验证。
- 能用自己的话讲清"NOT NULL + UNIQUE 组合"为什么才是完整的防重方案。
