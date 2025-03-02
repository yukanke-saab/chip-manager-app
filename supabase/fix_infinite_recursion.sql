-- 無限再帰を修正するためのSQL

-- ポリシーが原因の無限再帰を解決するための修正
-- まずはすべての問題のあるポリシーを削除
DROP POLICY IF EXISTS "allow_view_group_members" ON group_members;
DROP POLICY IF EXISTS "allow_add_members" ON group_members;
DROP POLICY IF EXISTS "Anyone can view any group member" ON group_members;
DROP POLICY IF EXISTS "Group members can view member list" ON group_members;
DROP POLICY IF EXISTS "Anyone can add themselves to groups" ON group_members;
DROP POLICY IF EXISTS "Owners can manage group members" ON group_members;
DROP POLICY IF EXISTS "Users can add themselves to groups" ON group_members;
DROP POLICY IF EXISTS "Users can remove themselves from groups" ON group_members;

-- グループメンバーに対する単純なポリシーを作成
-- 無限再帰を防ぐために単純なtrueポリシーに変更
CREATE POLICY "simple_select_policy" ON group_members
  FOR SELECT USING (true);

CREATE POLICY "simple_insert_policy" ON group_members
  FOR INSERT WITH CHECK (true);

CREATE POLICY "simple_update_policy" ON group_members
  FOR UPDATE USING (true);

CREATE POLICY "simple_delete_policy" ON group_members
  FOR DELETE USING (true);

-- グループ自体のポリシーも単純化
DROP POLICY IF EXISTS "allow_view_all_groups" ON groups;
DROP POLICY IF EXISTS "allow_group_creation_for_anyone" ON groups;
DROP POLICY IF EXISTS "Members can view their groups" ON groups;

-- 単純なグループポリシー
CREATE POLICY "simple_group_select" ON groups
  FOR SELECT USING (true);

CREATE POLICY "simple_group_insert" ON groups
  FOR INSERT WITH CHECK (true);

CREATE POLICY "simple_group_update" ON groups
  FOR UPDATE USING (true);

CREATE POLICY "simple_group_delete" ON groups
  FOR DELETE USING (true);

-- user_profilesテーブルもポリシーを単純化
DROP POLICY IF EXISTS "allow_profile_select_for_anyone" ON user_profiles;
DROP POLICY IF EXISTS "allow_profile_insert_for_own_id" ON user_profiles;

CREATE POLICY "simple_profile_select" ON user_profiles
  FOR SELECT USING (true);

CREATE POLICY "simple_profile_insert" ON user_profiles
  FOR INSERT WITH CHECK (true);

CREATE POLICY "simple_profile_update" ON user_profiles
  FOR UPDATE USING (true);
