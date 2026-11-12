# 模块 B · Day 4：增删改进阶与幂等写入

> 日期：2026-11-09 ｜ 阶段：B1 收尾 → B2 SQL 进阶过渡 ｜ 预计用时：约 2.5 小时
> 学习模式：先凭理解作答（不查资料）→ AI 批改 → 追问/重答 → 验证实验
> 前置：M1 已验收（knowledge_base 8 表建成），sandbox 库可用

---

## 任务 1：题组 4 问答（80 分钟）

**作答要求**：凭当前理解答，不查资料；口语化、要点式均可；不确定标"不确定"。
**今日特别提醒**：这组题围绕一个主题——**重复请求**（用户双击、网络重试、消息重复投递）。后端工程师的核心价值之一就是"让系统对重复请求免疫"。

---

### Q1. `INSERT ... RETURNING` 解决什么问题？

（提示：从 Node.js 应用插入一行后，通常紧接着需要什么？没有 RETURNING 时人们怎么做、有什么风险？）

> 我的回答：使用 RETURNING 少了一次网络往返，可以立即拿到想要的数据。
>
> 批改记录：✅ 正确（2026-11-09）。PG 的 INSERT/UPDATE/DELETE 均可挂 RETURNING，一条语句原子拿回自增 id/默认值/触发器计算值；对照 MySQL LAST_INSERT_ID() 的绕路。Q1 闭环。
> Q1-追问①（2026-11-09）："RETURNING 指的是数据库操作吗？" → 讲解：纯 SQL 语法（非 ORM 特性），PG 的 INSERT/UPDATE/DELETE 尾部均可挂 RETURNING，受影响行作为结果集直接返回。无 RETURNING 时（如 MySQL）：INSERT 后再 SELECT LAST_INSERT_ID()/再查一次——多一次往返，连接池/并发下逻辑绕。工程价值：①拿自增 id（插完用户建 session）②拿默认值列（created_at 等）③UPDATE/DELETE 也支持（删改留审计值顺手）。
> Q1-追问②（2026-11-09）："MySQL 有 RETURNING 吗？劣势？" → 讲解：MySQL 8.0 没有（用 LAST_INSERT_ID() 只拿 id 拿不到整行；想拿改完的数据只能再 SELECT）。RETURNING 三代价：①**方言不兼容**（绑定 PG/Oracle/SQLite，迁 MySQL 要改代码，ORM 抽象层存在的原因之一）；②**大批量别返回所有行**（INSERT 10 万行 RETURNING * = 序列化+传输+客户端内存全吃，批量时只返回需要的列或不用）；③**宽表别 RETURNING ***（每多一列都是网络成本）。定位：拿少量关键返回值的利器，不是批量回读数据的通道。
> Q1-追问③（2026-11-09）："为什么 RETURNING 可以立即返回？插入成功后才查得到吗？" → 讲解：是——RETURNING 是**同一条语句执行流程的最后一步**，非二次查询。生命周期：写入行（生成 id/默认值）→ 触发器触发 → 行进入最终状态 → RETURNING 对最终行求值返回。两性质：①**原子性**——拿到的永远是语句执行完的最终值（含默认值、触发器计算），语句失败则整个报错，不存在"插了一半"；②**无竞态窗口**——INSERT 再 SELECT 两条语句之间数据可能被别人改，RETURNING 把这个窗口关掉。彩蛋：PG 18 新增 `RETURNING OLD`（UPDATE/DELETE 返回修改前的值，审计利器；2025-09 发布的头条特性，面试细节控加分）。

### Q2. `ON CONFLICT` 是什么？两种模式 `DO NOTHING` 和 `DO UPDATE` 分别干什么？

> 我的回答：知识盲区（2026-11-09 首答）。
>
> 概念讲解：ON CONFLICT = INSERT 撞唯一约束/主键时执行 Plan B 而非报错。DO NOTHING 静默跳过（受影响行数 0；场景=幂等收藏）；DO UPDATE 原子更新已存在行（`SET count = vote.count + 1` 右侧是旧值；场景=投票计数）。冲突目标两种写法：列组合 / `ON CONSTRAINT 约束名`（推荐，意图清晰）。面试版：幂等与 upsert 的数据库原语，比"先查后插"少一次往返且无并发窗口。
> 重答（2026-11-09）：① 冲突时的决策逻辑 ✅；② DO NOTHING=语句不执行 ⚠️ 精修（语句成功返回、插入动作跳过、0 行受影响——"重复操作 ≡ 一次操作"的幂等语义）；DO UPDATE=更新逻辑 ✅；③ 少一次往返 ✅ 但大头未答——补：**原子性无并发窗口**（先查后插的竞态缝隙 vs ON CONFLICT 单语句原子动作，数据库保证同时只有一个请求赢）。
> Q2-追问（2026-11-09）："引用指定行的旧值 ✅；两个并发实际是一个执行完再执行另一个 ✅" → 补全机制：行锁串行化 + READ COMMITTED 重读最新版本，count 0→1→2 无丢失更新；对照应用层"SELECT 后加一写回"的丢更新。✅ Q2 闭环。
> Q2-追问②（2026-11-09）："MySQL 没有通过行锁把并发写串行化吧？是不是只能靠事务？" → 三处纠正：①**前提错**——InnoDB 恰恰靠行锁（记录锁/间隙锁）串行化同写，所有主流事务库共同机制，非 PG 独有；MVCC 解决"读写不互等"，写写冲突永远靠锁排队。②**事务 ≠ 解决并发**：事务管原子性/回滚，事务内普通 SELECT 读快照照样丢更新；防丢更新三件套=**原子单语句 / SELECT ... FOR UPDATE 锁读 / 串行化隔离**，事务只是容器。③**MySQL 有 upsert**——`INSERT ... ON DUPLICATE KEY UPDATE`（撞任何唯一键都触发，没得挑）；PG 的 ON CONFLICT 是标准化通用版，可点名冲突目标、DO NOTHING 独立、配合部分唯一索引玩"软删不占名额"。面试把两家语法摆一起对比，比"PG 有 MySQL 没有"高明。

### Q3. 为什么 upsert 是"幂等写入"的数据库地基？

场景：用户双击"收藏"按钮，同一个请求到达后端两次——没有幂等设计会发生什么？有了 ON CONFLICT 会发生什么？

> 我的回答：没有幂等设计可能会生成多条收藏条目？
>
> 批改记录：⚠️ 一半（2026-11-09）。纠偏：本项目有复合主键 UNIQUE，重复**物理不可能**，无幂等设计的真实表现 = 第二次请求撞键**报错**，未特判则用户看到"收藏失败"（实际已收藏成功）——UX 事故。幂等完整定义：同一操作执行 1 次与 N 次，终态与用户感知完全一致。ON CONFLICT DO NOTHING = 静默跳过照常成功，无需 catch。地基 = 唯一约束（不许重）+ ON CONFLICT（重了怎么办），缺一不可。
> Q3-追问（2026-11-09）："INSERT 会撞，DO NOTHING 静默处理。" → ❌ 核心错。**不会撞**：部分唯一索引随 UPDATE 自动维护，软删行（deleted_at 非 NULL）被移出索引，名额自动让出 → 重新 INSERT 直接成功，应用层零处理。DO NOTHING 若真撞反而有害（假成功）。对照：若当初用全表 UNIQUE 才会撞，那时该 DO UPDATE"复活"旧行——部分索引把复杂性消灭在 Schema 层（Day 3 设计决策的回报）。
> 待重答：撞不撞 + 为什么（索引是活的、软删行移出索引、空名额）。
> ✅ 重答正确（2026-11-09）："不会撞——部分唯一索引随 UPDATE 维护，软删后行被移出索引，名额空出。" Q3 全部闭环。

### Q4. 批量插入有哪几种方式？各适合什么场景？

（提示：多行 VALUES / generate_series / COPY——至少答前两种）

> 我的回答：知识盲区，请讲解（2026-11-09 首答）。
>
> 概念讲解（2026-11-09）——批量插入三招，从常用到极客：
> **第一招：多行 VALUES**（应用开发最常用）：`INSERT INTO t (cols) VALUES (...),(...),(...);` 一条语句塞多行。Node 侧场景：用户批量导入 500 条书签——ORM 的 createMany 底层就是它。比循环单条快的原因：循环 500 次 = 500 次往返 + 500 次解析 + 500 个独立事务（各自写 WAL）；合成一条 = 1 次往返、1 次解析、1 个事务——**数量级优化，不是百分之几**。
> **第二招：INSERT ... SELECT**（数据加工/造数）：SELECT 可任意复杂（JOIN、函数、generate_series）。造数标准武器——实验 3 的 10 万行即 `INSERT INTO resource ... SELECT ..., '资源-'||i, ... FROM generate_series(1,100000) AS i;`：generate_series 像内存虚拟表，瞬间产出 10 万行供 SELECT 加工，几秒钟造全量测试数据。
> **第三招：COPY**（海量数据专用，了解即可）：`COPY t FROM '/tmp/data.csv' WITH (FORMAT csv);` 绕过 INSERT 常规解析路径直接灌文件，百万行级导入导出（pg_dump 底层、数据迁移常见）。面试提到名字+场景就够。
>
> 批改记录：✅ 盲区讲解后进入实验 3 实操（2026-11-09）：10 万行成功落库，COUNT(*)=100000。Q4 闭环。
> 面试标准回答："批量插入三招：多行 VALUES（应用层批量写入首选，省往返省解析省事务）、INSERT ... SELECT（数据加工与造数，配 generate_series 几秒造 10 万行）、COPY（海量导入导出）。核心认知：循环单条插入的代价在'每条语句的固定开销×N'，合并语句是数量级优化。"

### Q5. `UPDATE` 不带 WHERE 会发生什么？生产环境有哪些防护手段？

> 我的回答：不带 WHERE 会命中所有行，数据都会受到影响。防护只知道事务回滚。
>
> 批改记录：第一问 ✅（2026-11-09）。第二问补全三层防护——个人纪律：先 SELECT 确认命中行再 UPDATE、WHERE 带主键/唯一键、手动操作 BEGIN 包住核对后 COMMIT；流程机制：变更审批双人复核、先备份/快照、脚本化；技术兜底：事务回滚（只救未提交！）、逻辑删除、从库 PITR、最小权限账号。核心认知：回滚救不了已提交的失误，备份和软删才是后悔药库存。
> 待重答：一句话版（会怎样 + 三层各一条）。
> ✅ 重答通过（2026-11-10）：影响无关行 + 五条防护（先SELECT/逻辑删除/审核/备份/写账号），三层归类准确。Q5 闭环。

### Q6. "存在则更新，不存在则插入"——应用层先查后插（SELECT 然后 INSERT/UPDATE）有什么问题？

（提示：两个请求同时到达，都查到"不存在"，然后都插入——会发生什么？）

> 我的回答：先查后插会出现并发问题——T0 时刻请求 A 和 B 都查到不存在，都准备插入，导致数据库执行出错。ON CONFLICT 在语句执行内判断冲突，已存在则执行内部逻辑（静默跳过或更新）。
>
> 批改记录：✅ 正确（2026-11-10）。补全：① 反模式学名 check-then-act 竞态（查与做之间的窗口）；② 事故两种形态——有唯一约束=撞键报错（23505，数据不脏但 UX 事故），无唯一约束=重复数据真落库；③ 加分点：应用层 catch 23505 再补救 = 手写 ON CONFLICT，多往返多分支。Q6 闭环。

### Q7. 结合主项目：收藏操作的幂等设计

往 collection_item 插入收藏关系时，用 ON CONFLICT 怎么保证"重复收藏同一资源"不产生重复数据？复合主键在这里起什么作用？

> 我的回答：使用联合主键 (collection_id, resource_id) 防止产生重复数据。联合主键确保唯一性约束。
>
> 批改记录：⚠️ 一半（2026-11-10）。复合主键 = 结构层"定义什么叫重复/不许重" ✅；缺 ON CONFLICT = 行为层"重了怎么办/不炸"。完整设计：INSERT ... ON CONFLICT (collection_id, resource_id) DO NOTHING。口诀：主键定边界，ON CONFLICT 定脾气；DO NOTHING 可平滑升级为 DO UPDATE SET created_at = now()（重复收藏置顶），结构不变。
> Q7-追问（2026-11-10）："列组合是唯一约束索引；顺序反了也能工作，因为前后位置不影响唯一性约束。" → ❌ 第二句错。唯一性**语义**顺序无关 ✅，但 ON CONFLICT 推断规则 = **按顺序精确匹配**已存在的唯一索引（复合主键底层是一棵定序 B-tree）；顺序反了报 `no unique or exclusion constraint matching`。根因：索引是物理结构，(a,b) 与 (b,a) 是两棵不同的树——预告 B3 最左前缀（索引 (a,b) 加速 a=? 与 a=? AND b=?，帮不了 b=?）。
> 修正版：列组合必须按顺序匹配唯一索引；语义无关序，结构有关序。

### Q8. 结合主项目：软删后重新收藏

resource 有逻辑删除 + 部分唯一索引 `UNIQUE(user_id, url) WHERE deleted_at IS NULL`。场景：用户收藏了 URL-X → 删除（软删）→ 又想重新收藏 URL-X。直接 INSERT 会发生什么？ON CONFLICT 在这里帮得上忙吗？

> 我的回答：① 直接 INSERT 会新创建一条新的收藏记录 ② 不需要 ON CONFLICT ③ 不新建收藏记录，直接在业务层将 resource 的 deleted_at 置为空。
>
> 批改记录：①② ✅（2026-11-10）。③ 方向对（UPDATE 复活成立）——**但 AI 前一轮给的"ON CONFLICT DO UPDATE 复活"方案被学习者抓出错误并正式纠正**：软删行不在部分索引收录范围 → 无冲突 → ON CONFLICT 永不触发（对复活场景是死代码）。核心原理：**ON CONFLICT 的触发范围 = 索引的收录范围**。三语义正确归宿：重复收藏活跃行→ON CONFLICT（DO NOTHING/UPDATE）；软删后重收→直接 INSERT 新行；复活旧行→显式动作按 id UPDATE（无竞态）。教训：AI 起草必须有人审——本次由学习者担任审查者并抓到错误。
> ✅ Q8 闭环（含纠错），题组 4 全部完成。

---

## 任务 2：验证实验（40 分钟，答完对应题目后做）

在 `sandbox` 库执行（SQL 可让 AI 生成），观察现象，写一句话结论。

### 实验 1：RETURNING 与 ON CONFLICT 幂等（对应 Q1–Q3、Q7）

```sql
CREATE TABLE IF NOT EXISTS fav (
  user_id int NOT NULL,
  res_id int NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, res_id)          -- 收藏关系：同一用户同一资源只能收藏一次
);

-- 模拟用户双击收藏：同一条 INSERT 连发两次
INSERT INTO fav (user_id, res_id) VALUES (1, 100);
INSERT INTO fav (user_id, res_id) VALUES (1, 100);
-- 预期：第二条报错，撞主键

-- 幂等写法：冲突就什么都不做
INSERT INTO fav (user_id, res_id) VALUES (1, 100)
ON CONFLICT (user_id, res_id) DO NOTHING;
INSERT INTO fav (user_id, res_id) VALUES (1, 100)
ON CONFLICT (user_id, res_id) DO NOTHING;
-- 预期：两次都成功（第二次静默跳过），表里仍只有 1 行

SELECT * FROM fav;
```

> 现象与结论：✅ 已验证（2026-11-09）：裸 INSERT 第二次报错 `duplicate key ... SQL state: 23505`（23505 = unique_violation，与 23514 check_violation 并列记忆）；ON CONFLICT DO NOTHING 第二次 `INSERT 0 0`（0 行受影响，语句成功）——幂等实证。

### 实验 2：ON CONFLICT DO UPDATE（对应 Q2）

```sql
CREATE TABLE IF NOT EXISTS vote (
  item_id int PRIMARY KEY,
  count int NOT NULL DEFAULT 0
);

-- 不存在则插入，存在则 +1——这就是原子级"计数累加"
INSERT INTO vote (item_id, count) VALUES (1, 1)
ON CONFLICT (item_id) DO UPDATE SET count = vote.count + 1;

INSERT INTO vote (item_id, count) VALUES (1, 1)
ON CONFLICT (item_id) DO UPDATE SET count = vote.count + 1;

SELECT * FROM vote;   -- 预期：count = 2（两次累加，没有丢失）
```

> 现象与结论：✅ 已验证（2026-11-09）：两次 DO UPDATE 累加后 count = 2——原子累加、无丢失更新的实锤（对照应用层"先查再改"的并发丢更新）。

### 实验 3：批量造数——10 万行（对应 Q4，为 B3 索引章节备料）

```sql
-- 在 knowledge_base 库执行（resource 表已在）
-- 先确保有一个用户：
INSERT INTO "user" (email, password_hash) VALUES ('seed@demo.com', 'x')
ON CONFLICT (email) DO NOTHING;

-- generate_series 批量插入 10 万条资源
INSERT INTO resource (user_id, title, url, note)
SELECT
  (SELECT id FROM "user" WHERE email = 'seed@demo.com'),
  '资源-' || i,
  'https://example.com/res/' || i,
  NULL
FROM generate_series(1, 100000) AS i;
-- 预期：几秒钟完成，INSERT 0 100000
```

> 现象与结论：✅ 已验证（2026-11-09）：10 万行插入成功，COUNT(*) = 100000（Messages 确认行数；耗时未抓取，EXPLAIN ANALYZE 工具 B3 再系统用）。B3 索引实验原料就位。

### 实验 4：UPDATE 灾难现场（对应 Q5，sandbox）

```sql
CREATE TABLE IF NOT EXISTS salary (
  name text PRIMARY KEY,
  amount numeric(10,2)
);
INSERT INTO salary VALUES ('张三', 10000), ('李四', 15000);

-- 灾难演习：BEGIN 包住，故意不带 WHERE，然后回滚
BEGIN;
UPDATE salary SET amount = 0;   -- 完了，全部清零
SELECT * FROM salary;           -- 观察：两行都变 0 了
ROLLBACK;                       -- 救命稻草：事务回滚
SELECT * FROM salary;           -- 观察：数据回来了
```

> 现象与结论：✅ 已验证（2026-11-09）：BEGIN 内全表清零可见 → ROLLBACK 后数据恢复。验证旧知识点：PG 的 DML 支持事务回滚（事务原子性 A 的日常形态；顺带呼应 Day 1 Q0——PG 的 DDL/DML 均在事务体系内，与 MySQL DDL 隐式提交相对）。

---

## 任务 3：种子数据脚本（20 分钟）

把实验 3 的造数整理成可重复执行的 `D:\person\backend\labs\module-b\seed.sql`：

- 用 `ON CONFLICT DO NOTHING` 保证重复执行不报错（幂等种子——和今天的主题呼应）；
- 内容：1 个种子用户 + 10 万条 resource；
- 文件头部写注释：用途（B3 索引实验数据）、可重复执行、执行方式。

## 当天交付物

- [x] Q1–Q8 回答 + 批改记录（本文件；含 Q1 三个追问、Q2 行锁追问的补记——2026-11-12 对聊天记录补录）
- [x] 实验 1–4 现象结论
- [x] `labs/module-b/seed.sql` 落盘（2026-11-12 补齐，见 Day 5 交付物记录）

## 验收标准

- Q3/Q6 能讲清"重复请求/并发下没有幂等设计会发生什么"。
- 实验 1 的 DO NOTHING 幂等效果亲眼验证（第二次执行 0 行受影响）。
- 实验 3 的 10 万行数据成功落库——B3 索引实验的全部原料。
- 实验 4 的 ROLLBACK 救命体验过一遍。
