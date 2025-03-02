-- 匿名ユーザーを含む全てのユーザーが自分のプロファイルを挿入できるようにする
CREATE POLICY "Anyone can insert user profiles" ON user_profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- 匿名ユーザーを含む全てのユーザーが自分のプロファイルを更新できるようにする
CREATE POLICY "Anyone can update their own profiles" ON user_profiles
  FOR UPDATE USING (auth.uid() = id);

-- 匿名認証が機能しない場合の対策として、トリガー関数を修正
-- 新しいユーザーが作成されたときに自動的にプロファイルを作成する
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (id, display_name, is_anonymous)
  VALUES (
    NEW.id, 
    COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.email, 'ゲストユーザー'),
    COALESCE(NEW.raw_user_meta_data->>'is_anonymous', false)
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 既存のトリガーを一度削除して再作成
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
