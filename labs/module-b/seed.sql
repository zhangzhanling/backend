-- ============================================================
-- seed.sql —— knowledge_base 幂等种子脚本（模块 B）
-- 用途：为 B3 索引章节准备实验原料（1 个种子用户 + 10 万条 resource）
-- 用法：在 pgAdmin 中连接到 knowledge_base 库后整文件执行
-- 幂等验收：重复执行不报错；第二次执行后 resource 总数不变
-- ============================================================

-- ① 种子用户：存在则跳过（ON CONFLICT 幂等）
INSERT INTO "user" (email, password_hash) VALUES ('seed@demo.com', 'x')
ON CONFLICT (email) DO NOTHING;


-- ② 10 万条 resource：generate_series 批量插入 + ON CONFLICT 幂等
-- 注意：resource_url_active_uq 是部分唯一索引（WHERE deleted_at IS NULL），
--       ON CONFLICT 的冲突目标必须显式带上同样的 WHERE 条件才能匹配它
INSERT INTO resource (user_id, title, url, note)
SELECT
  (SELECT id FROM "user" WHERE email = 'seed@demo.com'),
  '资源-' || i,
  'https://example.com/res/' || i,
  NULL
FROM generate_series(1, 100000) AS i
ON CONFLICT (user_id, url) WHERE deleted_at IS NULL DO NOTHING;


-- ③ 验证查询：本库已在 Day 4 实验 3 落过同批数据，
--    故两次执行均应为 INSERT 0 0，count 恒为 100000——这正是幂等的验收方式
SELECT count(*) AS resource_count FROM resource;
