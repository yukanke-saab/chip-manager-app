-- group_membersテーブルにIDカラムを追加
ALTER TABLE group_members ADD COLUMN IF NOT EXISTS id UUID DEFAULT uuid_generate_v4() PRIMARY KEY;

-- 既存のgroup_membersテーブルのプライマリキー制約を変更
-- 注意: これは慎重に行う必要があります
ALTER TABLE group_members DROP CONSTRAINT IF EXISTS group_members_pkey;
ALTER TABLE group_members ADD CONSTRAINT group_members_unique_group_user UNIQUE (group_id, user_id);
