-- user_profilesテーブルに匿名フラグを追加
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT FALSE;

-- 既存のトリガーを一旦削除
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- 新しいトリガー関数を作成
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- 既存のプロフィールがない場合のみ挿入
  INSERT INTO public.user_profiles (id, display_name, is_anonymous)
  VALUES (NEW.id, COALESCE(NEW.email, 'ゲストユーザー'), NEW.email LIKE 'anonymous-%@example.com')
  ON CONFLICT (id) DO NOTHING; -- IDが重複する場合は何もしない
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 新しいトリガーを作成
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Row Level Securityポリシーを更新
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- ユーザーは自分のプロフィールを見ることができる
CREATE POLICY "Users can view their own profile" ON user_profiles
  FOR SELECT USING (auth.uid() = id);

-- ユーザーは自分のプロフィールを更新できる
CREATE POLICY "Users can update their own profile" ON user_profiles
  FOR UPDATE USING (auth.uid() = id);

-- グループメンバーはお互いのプロフィールを見ることができる
CREATE POLICY "Group members can view other members' profiles" ON user_profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM group_members gm1
      WHERE gm1.user_id = auth.uid()
      AND EXISTS (
        SELECT 1 FROM group_members gm2
        WHERE gm2.group_id = gm1.group_id
        AND gm2.user_id = user_profiles.id
      )
    )
  );
