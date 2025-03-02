-- user_profilesテーブルにis_anonymousカラムがない場合は追加
ALTER TABLE IF EXISTS user_profiles ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT FALSE;

-- 既存のトリガー関数を修正
DROP FUNCTION IF EXISTS public.handle_new_user();
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (id, display_name, is_anonymous, avatar_url)
  VALUES (
    NEW.id, 
    COALESCE(NEW.raw_user_meta_data->>'display_name', 'ゲストユーザー'),
    COALESCE((NEW.raw_user_meta_data->>'is_anonymous')::boolean, NEW.email IS NULL),
    NULL
  )
  ON CONFLICT (id) DO UPDATE
  SET 
    display_name = COALESCE(NEW.raw_user_meta_data->>'display_name', EXCLUDED.display_name),
    is_anonymous = COALESCE((NEW.raw_user_meta_data->>'is_anonymous')::boolean, EXCLUDED.is_anonymous);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- トリガーを再作成
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 匿名ユーザーに対するRLSポリシーを更新
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- ユーザープロファイルの読み取りポリシー
DROP POLICY IF EXISTS "Anyone can read user profiles" ON user_profiles;
CREATE POLICY "Anyone can read user profiles" ON user_profiles
  FOR SELECT USING (true);

-- ユーザー自身のプロファイル更新ポリシー
DROP POLICY IF EXISTS "Users can update their own profiles" ON user_profiles;
CREATE POLICY "Users can update their own profiles" ON user_profiles
  FOR UPDATE USING (auth.uid() = id);

-- グループの公開可視性に関するポリシー
DROP POLICY IF EXISTS "Members can view their groups" ON groups;
CREATE POLICY "Members can view their groups" ON groups
  FOR SELECT USING (
    auth.uid() IN (
      SELECT user_id FROM group_members WHERE group_id = id
    )
  );

-- 匿名ユーザーもグループを作成できるようにする
DROP POLICY IF EXISTS "Users can create groups" ON groups;
CREATE POLICY "Users can create groups" ON groups
  FOR INSERT WITH CHECK (true);
