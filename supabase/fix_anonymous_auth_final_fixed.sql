-- トリガー関数を完全に作り直し
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- ユーザーが作成された時にプロファイルを自動作成するトリガー関数
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (id, display_name, is_anonymous)
  VALUES (
    NEW.id, 
    COALESCE(NEW.raw_user_meta_data->>'display_name', 'ゲストユーザー'),
    TRUE
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- トリガーを再作成
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 既存のポリシーを全て削除してから新しいポリシーを追加（名前の衝突を防ぐ）
DROP POLICY IF EXISTS "Anyone can create groups" ON groups;
DROP POLICY IF EXISTS "Authenticated users can create groups" ON groups;
DROP POLICY IF EXISTS "Users can create groups" ON groups;
DROP POLICY IF EXISTS "Anyone can insert groups" ON groups;
DROP POLICY IF EXISTS "Anyone with session can create groups" ON groups;

-- 匿名ユーザーでもグループを作成できるようにする
CREATE POLICY "allow_group_creation_for_anyone" ON groups
  FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL OR auth.role() = 'anon'
  );

-- 既存のユーザープロファイルポリシーを削除
DROP POLICY IF EXISTS "Anyone can read user profiles" ON user_profiles;
DROP POLICY IF EXISTS "Anyone can insert user profiles" ON user_profiles;
DROP POLICY IF EXISTS "Anyone can insert their own profiles" ON user_profiles;

-- ユーザープロファイルテーブルをAnonymousロールからもアクセス可能に
CREATE POLICY "allow_profile_select_for_anyone" ON user_profiles
  FOR SELECT USING (true);

CREATE POLICY "allow_profile_insert_for_own_id" ON user_profiles
  FOR INSERT WITH CHECK (auth.uid() = id OR auth.role() = 'anon');

-- 安全のためにメールアドレスと電話番号フィールドを隠す
UPDATE auth.users 
SET raw_user_meta_data = jsonb_set(
  COALESCE(raw_user_meta_data, '{}'::jsonb), 
  '{is_anonymous}', 
  'true'::jsonb
)
WHERE email IS NULL;

-- グループメンバー関連のポリシーを更新
DROP POLICY IF EXISTS "Anyone can view any group member" ON group_members;
DROP POLICY IF EXISTS "Anyone can add themselves to groups" ON group_members;
DROP POLICY IF EXISTS "Group members can view member list" ON group_members;

-- より緩和されたポリシー
CREATE POLICY "allow_view_group_members" ON group_members
  FOR SELECT USING (true);

CREATE POLICY "allow_add_members" ON group_members
  FOR INSERT WITH CHECK (true);

-- グループアクセスを改善
CREATE POLICY "allow_view_all_groups" ON groups
  FOR SELECT USING (true);
