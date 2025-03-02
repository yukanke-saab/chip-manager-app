-- 匿名ユーザー用の簡易修正SQL（初期対応用）
-- 2025-03-02実施

-- まず、user_profilesテーブルの権限を修正
DROP POLICY IF EXISTS "Users can insert their own profiles" ON user_profiles;
CREATE POLICY "Anyone can insert their own profiles" ON user_profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- グループ作成の権限を修正
DROP POLICY IF EXISTS "Users can create groups" ON groups;
CREATE POLICY "Anyone can create groups" ON groups 
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- 自分自身をグループに追加する権限
DROP POLICY IF EXISTS "Users can add themselves to groups" ON group_members;
CREATE POLICY "Anyone can add themselves to groups" ON group_members 
  FOR INSERT WITH CHECK (auth.uid() = user_id);
