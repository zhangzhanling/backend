# 模块 B · Day 5：SQL 查询进阶

> 日期：2026-11-10 ｜ 阶段：B2 SQL 查询进阶 ｜ 预计用时：约 2.5 小时
> 学习模式：先凭理解作答（不查资料）→ AI 批改 → 追问/重答 → 验证实验
> 前置：题组 1–4 已完成；knowledge_base 有 10 万行 resource 数据；sandbox 可用

---

## 任务 1：题组 5 问答（80 分钟）

**作答要求**：凭当前理解答，不查资料；口语化、要点式均可；不确定标"不确定"。
**今日特别提醒**：今天的题全部关于**"查询执行的真相"**——执行顺序、逻辑陷阱、性能差异。答每题时先问自己："数据库实际先做什么、后做什么？"

---

### Q1. JOIN 全家族

INNER JOIN / LEFT JOIN / RIGHT JOIN / FULL OUTER JOIN / CROSS JOIN 各返回什么？业务中为什么 LEFT JOIN 最常用？

> 我的回答：无法准确描述，请讲解（2026-11-10 首答）。
>
> 概念讲解：核心视角"以谁为准"——INNER 只留两边都匹配的行（交集）；LEFT 左表全保留右表配不上填 NULL；RIGHT 对调方向；FULL 两边都保留（并集）；CROSS 无条件笛卡尔积（行数=两表行数相乘）。口诀：INNER 留匹配，LEFT 留左边，RIGHT 留右边，FULL 全留，CROSS 全配。
> LEFT 最常用原因：业务列表页默认形态 = "主实体 + 可选附加信息"（订单+用户、资源+正文），主实体一个不能少、附加信息可 NULL——正是 LEFT 语义；INNER 会悄悄丢掉主实体（没订单的用户从列表消失=事故）。
> 重答（2026-11-10）：五种 JOIN 口诀版全对（INNER 交集 / LEFT 左全保留右填 NULL / RIGHT 反向 / FULL 并集 / CROSS 笛卡尔积少用）；LEFT 常用理由 ✅（主表数据一个不能少，INNER 会丢主实体=事故）。→ ✅ Q1 闭环。
> 待验证：实验 1（A/B/C 三查询现象）。

### Q2. 经典陷阱：LEFT JOIN + WHERE

下面两条查询结果一样吗？为什么？

```sql
SELECT * FROM resource r
LEFT JOIN resource_content rc ON rc.resource_id = r.id
WHERE rc.content IS NOT NULL;

SELECT * FROM resource r
LEFT JOIN resource_content rc ON rc.resource_id = r.id
WHERE rc.resource_id IS NOT NULL;
```

（提示：先想 WHERE 在 JOIN 之后执行，再想想 NULL 的三值逻辑——Day 2 的债今天还。）

> 我的回答：一样，虽然一个查 content 一个查 resource_id，但这两个字段都是非空的。"找没有正文的资源"：FROM resource_content rc LEFT JOIN resource r。
>
> 批改记录：⚠️ 结论对、理由歪、第三问方向反（2026-11-10）。真实机制：① 执行顺序——LEFT JOIN 先执行，未匹配行右表整行填 NULL，WHERE 后执行；② `NULL IS NOT NULL` = FALSE（专用判空语法，非 UNKNOWN），未匹配行全被过滤 → LEFT 退化为 INNER。与列的 NOT NULL 约束无关。
> 第三问纠正：找"没有正文的资源"应以 resource 为左表 WHERE rc.resource_id IS NULL；原答案方向反了（查成"孤儿正文"）。三句口诀：① WHERE 过滤右表普通值 → LEFT 退化 INNER；② 保留左表全部 → 条件挪进 ON；③ 找没匹配上的 → 右表主键 IS NULL。
> 待重答：退化机制复述 + 默写正确查询。→ ✅ 修正版（2026-11-10）："WHERE 影响的是整个行数据，左表也会被影响到" —— 正确。Q2 闭环（经质疑-辩论-修正路径获得）。
> 学习者质疑（2026-11-10）："WHERE 只去掉右表 NULL 行，左表不受影响" → ❌ 已纠正：WHERE 过滤对象是 JOIN 后的**整行**（左右列拼接），判 FALSE 整行消失——左表未匹配的行正是通过"右表列为 NULL"被杀，实验 A 李四王五消失即证据。修正版：WHERE 引用右表列做值过滤 → LEFT 保留左表的语义失效（条件为 NULL 不成立时退化为 INNER；额外过滤匹配行时为 INNER+条件）。WHERE 只碰左表列时 LEFT 语义完好。

### Q3. 子查询：IN vs EXISTS

查"有打过标签的资源"，`IN` 和 `EXISTS` 两种写法什么区别？哪个更推荐？另外：`NOT IN` 有个致命 NULL 陷阱，是什么？

> 我的回答：知识盲区（2026-11-11 首答）。
>
> 概念讲解：IN = 名单比对（子查询产出全量结果集，外层逐行查 membership）；EXISTS = 存在性短路判断（对外层每行只问"有没有匹配"，找到第一行立即停止，不产名单）。判断存在与否推荐 EXISTS（语义贴查询意图、行为可预测、可自然表达相关子查询）。
> NOT IN NULL 炸弹：本质是逐条 != 比对链，子查询结果含一个 NULL → `id != NULL` = UNKNOWN → AND 链出现 UNKNOWN → 结果全非 TRUE → WHERE 全过滤 = 空结果，**不报错**。一个脏数据杀死整个查询。正确姿势：查"不存在"一律 NOT EXISTS（NULL 行不算"匹配"，安静躺过）。
> 重答（2026-11-11）：实验验证 ✅（NOT IN 空结果、NOT EXISTS 返回 2,3）；机制复述 ✅——"NOT IN 本质是 AND 链（`!= v1 AND != v2 AND ...`），链上 `!= NULL` 得 UNKNOWN，AND 链失 TRUE，WHERE 只留 TRUE 故全灭；IN 是 OR 链故不怕 NULL（TRUE OR UNKNOWN = TRUE）"；NOT EXISTS = 按主表行问子查询"有无匹配行"，NULL 行不算匹配，无炸弹。
> 延伸确认（2026-11-11）：学习者问"NOT IN 本质是与逻辑？" → ✅ 正确，IN 对应 OR 逻辑；AND/OR 对 UNKNOWN 的容忍度差异 = NOT IN 怕 NULL 而 IN 不怕的根源。
> ✅ Q3 闭环。

### Q4. SELECT 的执行顺序

一条 `SELECT ... FROM ... WHERE ... GROUP BY ... HAVING ... ORDER BY ... LIMIT` 子句，**数据库实际的执行顺序**是什么？由此解释：为什么 WHERE 里不能用 SELECT 里定义的列别名，而 ORDER BY 可以？

> 我的回答：知识盲区（2026-11-11 首答）。
>
> 概念讲解：执行顺序 = FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT（书写顺序以 SELECT 开头是给人看的）。别名生命周期：SELECT 阶段（第⑤步）才诞生；WHERE（第②步）执行时别名还没出生故报错；ORDER BY（第⑥步）时别名健在故可用。
> 推论三件套：① WHERE 不能引用聚合函数（分组未发生），聚合过滤归 HAVING；② 同 SELECT 内别名对兄弟表达式不可见；③ LIMIT 最后执行——无 ORDER BY 的 LIMIT 前 N 行不确定。
> 注脚：标准 SQL 仅 ORDER BY 可用别名；PG 扩展允许 GROUP BY 用别名。
> 待重答：执行顺序 + 别名生命周期解释。
> ✅ 重答正确（2026-11-11）：执行顺序链条 + "别名 SELECT 阶段才产生，之前不可用"。Q4 闭环。

### Q5. WHERE vs HAVING

两者都是"过滤"，分别在哪一步生效、各自能引用什么？（例：查"收藏数大于 3 的收藏集"该怎么写？）

> 我的回答：WHERE 在 FROM 确认数据库表之后执行，HAVING 在 GROUP BY 之后执行。WHERE 可以引用数据，HAVING 可以引用分组。应该写 HAVING。
>
> 批改记录：✅ 正确（2026-11-11）。时机与引用能力均对；补查询形态（GROUP BY + HAVING COUNT > 3）与性能习惯：行级条件下放 WHERE（分组前过滤省分组成本），HAVING 只过滤聚合结果。Q5 闭环。

### Q6. 窗口函数 vs GROUP BY

两者都能做"分组统计"，本质区别是什么？（提示：输出行数一样吗？）什么场景非用窗口函数不可？（例：每个用户的最新一条资源、分组内排名）

> 我的回答：请 AI 讲解（2026-11-11 首答）。
>
> 概念讲解：GROUP BY = 折叠（N 行压成每组 1 行，明细消失，回答"每组整体如何"）；窗口函数 OVER(PARTITION BY ...) = 挂标签（行数不变，每行追加组上下文，回答"每行细节+组环境"）。试金石：行数变不变。
> 语法：函数() OVER (PARTITION BY 分组列 ORDER BY 排序列)。常用族：ROW_NUMBER（连续编号）/RANK（同分跳名次）/LAG·LEAD（环比）/聚合+OVER。
> GROUP BY 做不到的三场景：①每组第一名/最新一条（ROW_NUMBER 取 rn=1——主项目实战："每个用户最新一条资源"）；②明细+组统计同屏（不折叠，列表可分页）；③组内排名/占比。
> 重答（2026-11-12）：实验验证 ✅（GROUP BY 2 行 / 窗口 4 行带平均分与组内排名；每组第一名只能用窗口函数）。本质区别复述 ✅——GROUP BY 折叠（每组一行，明细消失）；窗口函数挂标签（明细保留 + 追加组内信息；组内平均/第一条等需求只能用它）。
> ✅ Q6 闭环。

### Q7. 分页：OFFSET vs Keyset（游标分页）

OFFSET 分页的两个问题是什么？Keyset 分页怎么解决？Keyset 的代价（不能跳页、需要唯一排序列）是什么？

> 我的回答（2026-11-12，第一轮答"知识盲区"，以下为讲解后的重答）：
>
> OFFSET 存在的 2 个问题：
> 1. 性能：查询第 n+1 行数据，必须先查全部行数据，然后舍弃前 n 行数据。页码越深，查询越慢。而且在并发情况下，会污染缓存。
> 2. 稳定性：OFFSET 必须依赖唯一列，如主键 id，如果列字段值相同，就会出现数据漂移。
>
> Keyset 没有上面 2 个问题。它基于 WHERE id > x 的方式，直接通过聚簇索引跳转到第 n 页。不需要扫全量数据。但是代价是必须一页一页的查，不能跳页；而且必须提供唯一键或联合主键。
>
> 批改记录：
>
> ⚠️→✅ Q7 闭环（2026-11-12）。
> - 问题一（性能）✅ 正确，还主动带出了缓存污染这个隐性成本。
> - 问题二（稳定性）⚠️ 因果说反：OFFSET **不依赖**唯一列（它只数行号）；真正的因果是「ORDER BY 排序键不唯一 **+ 翻页期间有新数据写入**」→ 同值行次序漂移 → 重复/漏行。两个条件缺一不可，漏答了"翻页期间数据变化"这个触发条件。修复手段是 ORDER BY 加唯一列兜底（`ORDER BY created_at, id`），不是"OFFSET 要用唯一列"。
> - Keyset 部分 ✅ 基本正确。两处修正：①"必须提供唯一键或联合主键"表述收窄——准确是**排序列必须唯一**，唯一性可来自主键，也可用联合排序 `(created_at, id)` 兜底（id 只是兜底，不要求联合主键这种约束形态）；②术语瑕疵："聚簇索引"是 MySQL InnoDB 的说法，PostgreSQL 没有聚簇索引（堆表 + 截图中的 Index Scan using resource_pkey 是沿主键索引范围扫描再回表），面试说"走主键索引范围扫描"更稳。
> - 标准答案（背这个）：OFFSET 两问题：①性能——OFFSET 语义是"数到第 N 行"，须扫描并丢弃前 N 行，O(offset+n)，页深越深越慢，深分页大量读页污染 buffer pool；②稳定性——翻页期间有新数据写入且 ORDER BY 排序键不唯一时，同值行次序漂移，重复或漏行。Keyset 用上一页最后一条的唯一标识 `WHERE id > ?` 走主键索引范围扫描，O(n)、与页深无关且稳定。代价：不能跳页、排序列必须唯一（不唯一用 (排序列, id) 兜底）、请求间传游标（next_cursor）。
> - 前置追问已解答：①OFFSET 为何必须扫够全部行——"第 N 行"是排序结果的位置属性不是数据的物理属性，序号不存在索引里，只能现场数；OFFSET 要"位置"只能靠数，Keyset 要"边界"可靠索引定位。②created_at 精度相同=批量插入时 now() 产生大量完全相同的值，同值行次序无承诺。

### Q8. 综合应用：收藏夹列表查询

需求：某用户的收藏夹详情页，显示"收藏夹信息 + 里面的资源列表（标题、URL、收藏时间），按收藏时间倒序，每页 20 条"。

用今天学的知识描述查询方案：几张表 JOIN、怎么分页、分页方案选哪种、为什么。（不用写完整 SQL，说清结构即可。）

> 我的回答（2026-11-12）：
>
> 1. 3 张表 JOIN，分别是 collection、collection_item、resource；collection LEFT JOIN collection_item 查出所有 resource_id，再根据 resource_id 去 resource 里面查详情
> 2. 分页采用 OFFSET 方案，因为数据量不会太大，查询压力小
> 3. 收藏时间存在 collection_item 表。这个排序键如果是批量收藏就不是唯一的。需要 (created_at, resource_id) 保证唯一
> 4. 陷阱：查询 resource_id 时需要排除 NULL 值，但 WHERE rc.resource_id IS NOT NULL 可能会退化为 INNER
>
> 批改记录：
>
> ✅ Q8 闭环（2026-11-12）。
> - 第 1 点 ⚠️→✅：表对，但方案绕了。resource 删除是 RESTRICT（Day 3 设计评审定的）→ collection_item 的 resource 必然存在 → **INNER JOIN 一条 SQL 搞定，不存在 NULL 行，第 4 点的陷阱天然消失**。推论链应是：FK 策略 → JOIN 类型 → 无陷阱；学习者反过来了（LEFT JOIN 再防陷阱，带着盔甲打不存在的仗）。头部收藏夹信息单独查 1 行（带 user_id 做归属校验/对象级权限），与分页列表拆两次查询。
> - 第 2 点 ✅：OFFSET 决策理由好——**OFFSET vs Keyset 的正确决策姿势是看场景**：收藏夹几十到几百条无深分页之忧，OFFSET 简单够用；全站百万行 Feed 才换 Keyset。
> - 第 3 点 ✅，补充：兜底列应用 **collection_item.id（自增主键）而非 resource_id**——自增 id 单调，(collected_at DESC, id DESC) 与真实收藏次序一致；resource_id 大小与收藏时间无必然关系。生产标配写法：**时间排序 + 自增 id 兜底**。
> - 第 4 点 ✅（陷阱知识本身掌握扎实，实验 1 亲验），但本题 INNER JOIN 下不适用；面试建议加限定："仅当存在悬空引用风险（资源可删/FK 为 SET NULL）才需要 LEFT JOIN + 条件进 ON"。
> - 参考答案：头部 1 行 `SELECT ... FROM collection WHERE id=? AND user_id=?`（归属校验）；列表 `collection_item ci JOIN resource r ON r.id=ci.resource_id WHERE ci.collection_id=? ORDER BY ci.collected_at DESC, ci.id DESC LIMIT 20 OFFSET ?`；总数 `SELECT COUNT(*) FROM collection_item WHERE collection_id=?` 供头部显示。

---

## 任务 2：验证实验（40 分钟，答完对应题目后做）

### 实验 1：LEFT JOIN 陷阱实锤（对应 Q1、Q2，sandbox）

```sql
CREATE TABLE IF NOT EXISTS t_user (id int PRIMARY KEY, name text);
CREATE TABLE IF NOT EXISTS t_order (id int PRIMARY KEY, user_id int, amount int);

INSERT INTO t_user (id, name) VALUES (1,'张三'),(2,'李四'),(3,'王五') ON CONFLICT DO NOTHING;
INSERT INTO t_order (id, user_id, amount) VALUES (1,1,100),(2,1,200) ON CONFLICT DO NOTHING;
-- 李四、王五没有订单

-- 查询 A：LEFT JOIN 之后用 WHERE 过滤右表
SELECT u.name, o.amount FROM t_user u
LEFT JOIN t_order o ON o.user_id = u.id
WHERE o.amount > 0;
-- 预期：李四、王五消失——LEFT JOIN 被 WHERE 退化成了 INNER JOIN

-- 查询 B：把条件挪进 ON
SELECT u.name, o.amount FROM t_user u
LEFT JOIN t_order o ON o.user_id = u.id AND o.amount > 0;
-- 预期：5 行全在，没订单的显示 NULL

-- 查询 C：专门看"没有订单的人"（IS NULL 的合法用法）
SELECT u.name FROM t_user u
LEFT JOIN t_order o ON o.user_id = u.id
WHERE o.id IS NULL;
```

> 现象与结论：✅ 已验证（2026-11-10）：A 只查出张三（李四王五消失——LEFT 被 WHERE 退化为 INNER）；B 4 行全保留、无订单者填 NULL（条件进 ON，左表为准语义保住）；C 查出李四、王五（IS NULL 合法用法：找缺失/对账）。

### 实验 2：NOT IN 的 NULL 陷阱（对应 Q3，sandbox）

```sql
CREATE TABLE IF NOT EXISTS t_a (id int PRIMARY KEY);
CREATE TABLE IF NOT EXISTS t_b (id int);
INSERT INTO t_a VALUES (1),(2),(3) ON CONFLICT DO NOTHING;
INSERT INTO t_b VALUES (1),(NULL) ON CONFLICT DO NOTHING;   -- 注意 t_b 里有个 NULL

SELECT * FROM t_a WHERE id NOT IN (SELECT id FROM t_b);
-- 预期：空结果！——t_b 里那个 NULL 让整个 NOT IN 变成 UNKNOWN

-- 对比：NOT EXISTS 不受 NULL 影响
SELECT * FROM t_a a WHERE NOT EXISTS (SELECT 1 FROM t_b b WHERE b.id = a.id);
-- 预期：(2),(3)
```

> 现象与结论：✅ 已验证（2026-11-11）：NOT IN 查询返回**空结果**（t_b 中那个 NULL 让整个 != 比对链全变 UNKNOWN，WHERE 只留 TRUE → 全灭）；NOT EXISTS 返回 (2),(3)（NULL 行不算"匹配"，安静躺过）。（铁律实锤：NOT IN 遇到 NULL = 全灭）

### 实验 3：深分页性能实锤（对应 Q7，knowledge_base 的 10 万行）

```sql
-- OFFSET 深分页：翻到第 5000 页
EXPLAIN ANALYZE
SELECT id, title FROM resource
ORDER BY id LIMIT 20 OFFSET 99980;
-- 观察：actual rows（实际扫描行数）

-- Keyset 分页：拿着上一页最后一条的 id
EXPLAIN ANALYZE
SELECT id, title FROM resource
WHERE id > 99980 ORDER BY id LIMIT 20;
-- 观察：actual rows 对比

-- OFFSET 的稳定性问题演示：按 created_at 排序（10 万行几乎同一时间戳），
-- 两个接连执行的 OFFSET 查询，第二页可能重复或漏行
```

> 现象与结论：✅ 已验证（2026-11-12，knowledge_base，10 万行）：
>
> | 指标 | OFFSET 99980 | Keyset (id > 99980) |
> |---|---|---|
> | 实际扫描行数 actual rows | 100,000 | 20 |
> | Buffers: shared hit | 1,813 | 6 |
> | Execution Time | 23.188 ms | 0.066 ms |
>
> 约 350 倍差距。OFFSET 走主键索引但仍须沿索引从 id=1 数到 10 万（位置只能数，不能跳）；Keyset 的 `id > 99980` 条件进索引直接定位起点，只扫 20 行。Keyset 读页极少 → 缓存命中率近 100%，不挤占 buffer pool 热数据。深分页时 OFFSET 会随数据量劣化（秒级），Keyset 耗时只取决于 LIMIT n，与页深无关。

### 实验 4：窗口函数 vs GROUP BY（对应 Q6，sandbox）

```sql
DROP TABLE IF EXISTS t_score;
CREATE TABLE t_score (name text, subject text, score int);
INSERT INTO t_score VALUES
  ('张三','数学',90),('张三','英语',85),
  ('李四','数学',92),('李四','英语',78);

-- GROUP BY：行被压缩，每人一行
SELECT name, AVG(score) AS avg_score FROM t_score GROUP BY name;

-- 窗口函数：行保留，每行旁边挂上统计值
SELECT name, subject, score,
       AVG(score) OVER (PARTITION BY name) AS avg_score,
       ROW_NUMBER() OVER (PARTITION BY name ORDER BY score DESC) AS rank_in_user
FROM t_score;
-- 预期：4 行全保留，每行多了"该生平均分"和"该生内排名"

-- GROUP BY 做不到的事：取每组第一名
SELECT name, subject, score FROM (
  SELECT name, subject, score,
         ROW_NUMBER() OVER (PARTITION BY name ORDER BY score DESC) AS rn
  FROM t_score
) t WHERE rn = 1;
```

> 现象与结论：✅ 已验证（2026-11-12）：GROUP BY 显示 2 行（每人一行，明细消失）；窗口函数显示 4 行（明细保留，每行旁挂"该生平均分"和"组内排名"）。每组第一名只能用窗口函数（ROW_NUMBER 取 rn=1，GROUP BY 做不到）。本质：GROUP BY 折叠（每组一行）；窗口函数挂标签（明细 + 追加组内信息）。

---

## Day 5 收尾总结

### 进度

- Q1–Q8 全部闭环，实验 1–4 全部验证 ✅（Day 5 完成，至此题组 1–5 完成）
- Day 4 欠账 `labs/module-b/seed.sql` 已于 2026-11-12 补齐（见文末交付物）

### 焊点知识（必须形成条件反射）

1. **LEFT JOIN + WHERE 过滤右表 = 悄悄退化为 INNER JOIN**；条件挪进 ON 才是"以左表为准"；IS NULL 是合法用法（找缺失/对账）。
2. **NOT IN 遇到 NULL = 全灭**（逐行匹配 AND 语义，UNKNOWN 让 WHERE 全过滤）；反关联查询一律 NOT EXISTS。
3. **SQL 执行顺序**：FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT；别名 SELECT 阶段才产生，之前一律不能用。
4. **OFFSET 两宗罪**：O(offset+n) 深分页 + 排序键不唯一且翻页期间有写入时漂移；Keyset 用边界值 `WHERE id > ?` O(n) 稳定，代价是不能跳页、排序列必须唯一（不唯一用 (列, id) 兜底）、传游标。**决策看场景不看高级程度**。
5. **GROUP BY 折叠 vs 窗口函数挂标签**：每组第一名/最新一条、明细+组统计同屏、组内排名——GROUP BY 做不到，只能窗口函数。
6. 时间排序分页的标配写法：**ORDER BY 时间 DESC, 自增 id DESC**。

### 表现画像（Day 5）

- 优点：JOIN 语义复述精准（LEFT/INNER/RIGHT/FULL 边界全对）；实验结果与理论逐条对上；OFFSET 选型能给出"数据量小"的场景化理由；窗口函数实验后本质区别（折叠 vs 挂标签）总结到位。
- 盲区（本日新补）：分页体系整体是盲区，讲解后重答质量高（性能+稳定性+缓存污染全覆盖）；执行顺序的"阶段"视角第一次接触。
- 惯性问题：**因果链方向偶发反转**（Q7"OFFSET 必须依赖唯一列"、Q8"LEFT JOIN 再防陷阱"）——都是从结论倒推原因。修正方法：每道题先问"前提条件是什么（FK 策略/数据规模/并发模型），再推方案"。已加入薄弱项。

### 累计薄弱项清单（截至 Day 5，Day 6 模拟面试重考）

1. SET NULL 的方向感（Day 2 Q 外键题曾反，已纠正——再抽一题验证）
2. DEFAULT 触发时机（Day 2，已验证——抽变体）
3. CHECK vs WHERE 的三值逻辑差异（Day 2，已验证——抽变体）
4. ON CONFLICT 多列冲突目标的匹配语义（Day 4）
5. **因果链方向：由前提推方案，勿由结论倒推**（Day 5 新增，综合题抽测）
6. NOT IN NULL 陷阱（已亲验，Day 6 换业务场景考）

---

## 当天交付物

- [x] Q1–Q8 回答 + 批改记录（本文件）
- [x] 实验 1–4 现象结论
- [x] `labs/module-b/seed.sql` 幂等种子脚本（2026-11-12 补齐：学习者独立补全 `ON CONFLICT (user_id, url) WHERE deleted_at IS NULL DO NOTHING`，一次通过 ✅）

## 验收标准

- Q2（LEFT JOIN 陷阱）、Q3（NOT IN NULL 陷阱）的结论与实验现象对得上——今天两个焊点。
- Q4 能用"执行顺序"完整解释"WHERE 不能用别名、ORDER BY 能用"。
- 实验 3 的 OFFSET vs Keyset 扫描行数对比亲眼看到。
- 能用窗口函数写出"每组第一名"。
