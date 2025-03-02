-- user_profilesテーブルの更新
-- is_anonymousカラムがない場合は追加
ALTER TABLE IF EXISTS user_profiles ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT FALSE;

-- RLSポリシーを更新
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- パブリックアクセスポリシー - 誰でも読み取り可能（グループメンバーなら）
CREATE POLICY IF NOT EXISTS "Anyone can read user profiles" ON user_profiles
  FOR SELECT USING (true);

-- ユーザー自身の更新のみ許可
CREATE POLICY IF NOT EXISTS "Users can update their own profiles" ON user_profiles
  FOR UPDATE USING (auth.uid() = id);

-- ユーザー自身の削除のみ許可
CREATE POLICY IF NOT EXISTS "Users can delete their own profiles" ON user_profiles
  FOR DELETE USING (auth.uid() = id);

-- ユーザー自身の挿入のみ許可（または管理者）
CREATE POLICY IF NOT EXISTS "Users can insert their own profiles" ON user_profiles
  FOR INSERT WITH CHECK (auth.uid() = id OR auth.uid() IN (SELECT id FROM auth.users WHERE role = 'service_role'));

-- groupsテーブル更新 - パブリックフラグ追加
ALTER TABLE IF EXISTS groups ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT FALSE;

-- 認証ユーザーはグループを作成可能
CREATE POLICY IF NOT EXISTS "Authenticated users can create groups" ON groups
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- グループオーナーのみが更新可能
CREATE POLICY IF NOT EXISTS "Group owners can update groups" ON groups
  FOR UPDATE USING (auth.uid() = owner_id);

-- グループオーナーのみが削除可能
CREATE POLICY IF NOT EXISTS "Group owners can delete groups" ON groups
  FOR DELETE USING (auth.uid() = owner_id);

-- メンバーはグループを閲覧可能、公開グループは誰でも閲覧可能
CREATE POLICY IF NOT EXISTS "Members can view their groups and public groups" ON groups
  FOR SELECT USING (
    is_public = TRUE OR 
    auth.uid() IN (
      SELECT user_id FROM group_members WHERE group_id = id
    )
  );

-- 匿名ユーザーに対するポリシー
-- 匿名ユーザーもトランザクションを作成可能（グループメンバーであれば）
CREATE POLICY IF NOT EXISTS "Group members can add transactions" ON chip_transactions
  FOR INSERT WITH CHECK (
    auth.uid() IN (
      SELECT user_id FROM group_members 
      WHERE group_id = chip_transactions.group_id 
      AND (role = 'owner' OR role = 'temporary_owner')
    )
  );

-- すべてのグループメンバーはトランザクションを閲覧可能
CREATE POLICY IF NOT EXISTS "Group members can view transactions" ON chip_transactions
  FOR SELECT USING (
    auth.uid() IN (
      SELECT user_id FROM group_members WHERE group_id = chip_transactions.group_id
    )
  );

-- グループメンバーはメンバーリストを閲覧可能
CREATE POLICY IF NOT EXISTS "Group members can view member list" ON group_members
  FOR SELECT USING (
    auth.uid() IN (
      SELECT user_id FROM group_members WHERE group_id = group_members.group_id
    )
  );

-- ユーザーは自分自身をグループに追加可能（招待コード経由）
CREATE POLICY IF NOT EXISTS "Users can add themselves to groups" ON group_members
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
  );

-- ユーザーは自分自身をグループから削除可能
CREATE POLICY IF NOT EXISTS "Users can remove themselves from groups" ON group_members
  FOR DELETE USING (
    auth.uid() = user_id
  );

-- オーナーはメンバーを追加・削除・更新可能
CREATE POLICY IF NOT EXISTS "Owners can manage group members" ON group_members
  FOR ALL USING (
    auth.uid() IN (
      SELECT user_id FROM group_members 
      WHERE group_id = group_members.group_id 
      AND role = 'owner'
    )
  );
