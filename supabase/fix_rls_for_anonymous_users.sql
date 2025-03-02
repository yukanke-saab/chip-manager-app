-- 匿名ユーザー向けのRLS（Row Level Security）ポリシーを修正

-- ------------------------------------------------
-- ユーザープロファイル関連のポリシー
-- ------------------------------------------------

-- ユーザープロファイルの読み取りポリシー - 誰でも読める
DROP POLICY IF EXISTS "Anyone can read user profiles" ON user_profiles;
CREATE POLICY "Anyone can read user profiles" ON user_profiles
  FOR SELECT USING (true);

-- 自分のプロファイルのみ編集可能
DROP POLICY IF EXISTS "Users can update their own profiles" ON user_profiles;
CREATE POLICY "Users can update their own profiles" ON user_profiles
  FOR UPDATE USING (auth.uid() = id);

-- 自分のプロファイルのみ削除可能
DROP POLICY IF EXISTS "Users can delete their own profiles" ON user_profiles;
CREATE POLICY "Users can delete their own profiles" ON user_profiles
  FOR DELETE USING (auth.uid() = id);

-- 自分のプロファイルのみ挿入可能
DROP POLICY IF EXISTS "Anyone can insert user profiles" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert their own profiles" ON user_profiles;
CREATE POLICY "Anyone can insert their own profiles" ON user_profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- ------------------------------------------------
-- グループ関連のポリシー
-- ------------------------------------------------

-- グループ作成ポリシー - 認証済みユーザーなら作成可能（匿名含む）
DROP POLICY IF EXISTS "Anyone can create groups" ON groups;
DROP POLICY IF EXISTS "Users can create groups" ON groups;
DROP POLICY IF EXISTS "Authenticated users can create groups" ON groups;
CREATE POLICY "Authenticated users can create groups" ON groups
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- グループオーナーのみ更新可能
DROP POLICY IF EXISTS "Group owners can update groups" ON groups;
CREATE POLICY "Group owners can update groups" ON groups
  FOR UPDATE USING (auth.uid() = owner_id);

-- グループオーナーのみ削除可能
DROP POLICY IF EXISTS "Group owners can delete groups" ON groups;
CREATE POLICY "Group owners can delete groups" ON groups
  FOR DELETE USING (auth.uid() = owner_id);

-- グループ閲覧ポリシー - メンバーのみ閲覧可能
DROP POLICY IF EXISTS "Members can view their groups" ON groups;
DROP POLICY IF EXISTS "Members can view their groups and public groups" ON groups;
CREATE POLICY "Members can view their groups" ON groups
  FOR SELECT USING (
    auth.uid() IN (
      SELECT user_id FROM group_members WHERE group_id = id
    )
  );

-- ------------------------------------------------
-- グループメンバー関連のポリシー
-- ------------------------------------------------

-- グループメンバー閲覧ポリシー - 同じグループのメンバーのみ閲覧可能
DROP POLICY IF EXISTS "Group members can view member list" ON group_members;
CREATE POLICY "Group members can view member list" ON group_members
  FOR SELECT USING (
    auth.uid() IN (
      SELECT user_id FROM group_members WHERE group_id = group_members.group_id
    )
  );

-- 自分自身をグループに追加できる（招待コード経由）
DROP POLICY IF EXISTS "Users can add themselves to groups" ON group_members;
DROP POLICY IF EXISTS "Anyone can add themselves to groups" ON group_members;
CREATE POLICY "Anyone can add themselves to groups" ON group_members
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
  );

-- 自分自身をグループから削除できる
DROP POLICY IF EXISTS "Users can remove themselves from groups" ON group_members;
CREATE POLICY "Users can remove themselves from groups" ON group_members
  FOR DELETE USING (
    auth.uid() = user_id
  );

-- オーナーはグループメンバーを管理できる
DROP POLICY IF EXISTS "Owners can manage group members" ON group_members;
CREATE POLICY "Owners can manage group members" ON group_members
  FOR ALL USING (
    auth.uid() IN (
      SELECT user_id FROM group_members 
      WHERE group_id = group_members.group_id 
      AND role = 'owner'
    )
  );

-- ------------------------------------------------
-- チップ取引関連のポリシー
-- ------------------------------------------------

-- チップ取引閲覧ポリシー - グループメンバーのみ閲覧可能
DROP POLICY IF EXISTS "Group members can view transactions" ON chip_transactions;
CREATE POLICY "Group members can view transactions" ON chip_transactions
  FOR SELECT USING (
    auth.uid() IN (
      SELECT user_id FROM group_members WHERE group_id = chip_transactions.group_id
    )
  );

-- チップ取引追加ポリシー - グループのオーナー/一時オーナーのみ追加可能
DROP POLICY IF EXISTS "Group members can add transactions" ON chip_transactions;
CREATE POLICY "Group owners can add transactions" ON chip_transactions
  FOR INSERT WITH CHECK (
    auth.uid() IN (
      SELECT user_id FROM group_members 
      WHERE group_id = chip_transactions.group_id 
      AND (role = 'owner' OR role = 'temporary_owner')
    )
  );

-- トリガー関数を修正して匿名ユーザーにも対応
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (id, display_name, is_anonymous)
  VALUES (
    NEW.id, 
    COALESCE(NEW.raw_user_meta_data->>'display_name', 'ゲストユーザー'),
    COALESCE((NEW.raw_user_meta_data->>'is_anonymous')::boolean, true)
  )
  ON CONFLICT (id) 
  DO UPDATE SET 
    display_name = EXCLUDED.display_name,
    is_anonymous = EXCLUDED.is_anonymous;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- トリガーを再作成
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
