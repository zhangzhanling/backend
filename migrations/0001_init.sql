-- ============================================================
-- 0001_init.sql — 个人 AI 知识库 · 初始建表脚本
-- 依据：notes/DATABASE_DESIGN.md v0.2（2026-11-06 审查定稿）
-- 目标库：knowledge_base
-- 约定：bigint identity 主键；timestamptz；小写蛇形
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- "user"：用户（user 是关键字，必须加引号——审查点 1）
-- ------------------------------------------------------------
CREATE TABLE "user" (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  email         text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- resource：资源（瘦表，正文在 resource_content）
-- ------------------------------------------------------------
CREATE TABLE resource (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id    bigint NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
  title      text NOT NULL,
  url        text,
  note       text,
  type       text NOT NULL DEFAULT 'article',
  deleted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  -- 审查点 2：行级完整性底线（url 与非空 note 至少其一）
  CONSTRAINT resource_has_content_chk
    CHECK (url IS NOT NULL OR btrim(COALESCE(note, '')) <> '')
);

-- 审查点 3：部分唯一索引——WHERE 子句不能写在表内 UNIQUE 约束里，
-- 必须独立 CREATE UNIQUE INDEX（表内 UNIQUE 只能等值全行唯一）
CREATE UNIQUE INDEX resource_url_active_uq
  ON resource (user_id, url)
  WHERE deleted_at IS NULL;

-- ------------------------------------------------------------
-- resource_content：1:1 冷热分离（FK²：共享主键 + 外键）
-- ------------------------------------------------------------
CREATE TABLE resource_content (
  resource_id bigint PRIMARY KEY REFERENCES resource(id) ON DELETE CASCADE,
  content     text NOT NULL
);

-- ------------------------------------------------------------
-- tag：每用户独立命名空间
-- ------------------------------------------------------------
CREATE TABLE tag (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id    bigint NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
  title      text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT tag_user_title_uq UNIQUE (user_id, title)
);

-- ------------------------------------------------------------
-- resource_tag：M:N 关联表（两外键 + 复合主键）
-- ------------------------------------------------------------
CREATE TABLE resource_tag (
  resource_id bigint NOT NULL REFERENCES resource(id) ON DELETE CASCADE,
  tag_id      bigint NOT NULL REFERENCES tag(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (resource_id, tag_id)
);

-- ------------------------------------------------------------
-- collection：收藏集
-- ------------------------------------------------------------
CREATE TABLE collection (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id    bigint NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
  title      text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- collection_item：M:N 关联表
-- 注意：resource 侧 2026-11-06 审查修订为 CASCADE（原 RESTRICT，
--       理由见 DATABASE_DESIGN.md 审查记录 C 组；未来支持收藏他人资源须重审）
-- ------------------------------------------------------------
CREATE TABLE collection_item (
  collection_id bigint NOT NULL REFERENCES collection(id) ON DELETE CASCADE,
  resource_id   bigint NOT NULL REFERENCES resource(id) ON DELETE CASCADE,
  created_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (collection_id, resource_id)
);

-- ------------------------------------------------------------
-- document：解析产物骨架（1:N 保留历史版本；状态机细化属 M4）
-- ------------------------------------------------------------
CREATE TABLE document (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  resource_id   bigint NOT NULL REFERENCES resource(id) ON DELETE CASCADE,
  status        text NOT NULL DEFAULT 'pending',
  result        jsonb,
  error_message text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

COMMIT;
