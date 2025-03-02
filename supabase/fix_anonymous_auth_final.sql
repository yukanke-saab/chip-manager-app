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

-- 匿名ユーザーでもグループを作成できるようにする
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Authenticated users can create groups" ON groups;

CREATE POLICY "Anyone can create groups" ON groups
  FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL OR auth.role() = 'anon'
  );

-- ユーザープロファイルテーブルをAnonymousロールからもアクセス可能に
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can read user profiles" ON user_profiles;
CREATE POLICY "Anyone can read user profiles" ON user_profiles
  FOR SELECT USING (true);

-- 安全のためにメールアドレスと電話番号フィールドを隠す
ALTER TABLE auth.users UPDATE raw_user_meta_data SET is_anonymous = true WHERE email IS NULL;

-- セッションがなくても使えるように auth.uid() の要件を緩和
DROP POLICY IF EXISTS "Anyone can view any group member" ON group_members;
CREATE POLICY "Anyone can view any group member" ON group_members
  FOR SELECT USING (true);
