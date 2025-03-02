-- ユーザー拡張情報テーブル（Supabaseの認証機能と連携）
CREATE TABLE IF NOT EXISTS user_profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  display_name TEXT NOT NULL,
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- グループテーブル
CREATE TABLE IF NOT EXISTS groups (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  chip_unit TEXT DEFAULT '1',
  invite_code TEXT UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  owner_id UUID REFERENCES auth.users(id) NOT NULL
);

-- グループメンバーテーブル
CREATE TABLE IF NOT EXISTS group_members (
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  role TEXT NOT NULL CHECK (role IN ('owner', 'temporary_owner', 'member')),
  temp_owner_until TIMESTAMP WITH TIME ZONE,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  PRIMARY KEY (group_id, user_id)
);

-- チップ取引テーブル
CREATE TABLE IF NOT EXISTS chip_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  amount DECIMAL NOT NULL,
  operator_id UUID REFERENCES auth.users(id),
  note TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- チップ残高ビュー（クエリ効率化用）
CREATE OR REPLACE VIEW chip_balances AS
SELECT 
  user_id,
  group_id,
  SUM(amount) AS balance
FROM chip_transactions
GROUP BY user_id, group_id;

-- Row Level Security ポリシー

-- グループメンバーのみがグループデータにアクセス可能
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Group members can view their groups" ON groups
  FOR SELECT USING (
    auth.uid() IN (
      SELECT user_id FROM group_members WHERE group_id = id
    )
  );

-- オーナーのみがグループを編集・削除可能
CREATE POLICY "Only owners can update groups" ON groups
  FOR UPDATE USING (
    auth.uid() = owner_id
  );

CREATE POLICY "Only owners can delete groups" ON groups
  FOR DELETE USING (
    auth.uid() = owner_id
  );

-- オーナーはグループを作成可能
CREATE POLICY "Users can create groups" ON groups
  FOR INSERT WITH CHECK (
    auth.uid() = owner_id
  );

-- グループメンバーテーブルのRLS
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;

-- グループメンバーは自分が所属するグループのメンバー情報を閲覧可能
CREATE POLICY "Group members can view member list" ON group_members
  FOR SELECT USING (
    auth.uid() IN (
      SELECT user_id FROM group_members WHERE group_id = group_members.group_id
    )
  );

-- オーナーのみがメンバーを追加・削除・更新可能
CREATE POLICY "Only owners can manage members" ON group_members
  FOR INSERT WITH CHECK (
    auth.uid() IN (
      SELECT user_id FROM group_members WHERE group_id = group_members.group_id AND role = 'owner'
    )
  );

CREATE POLICY "Only owners can update members" ON group_members
  FOR UPDATE USING (
    auth.uid() IN (
      SELECT user_id FROM group_members WHERE group_id = group_members.group_id AND role = 'owner'
    )
  );

CREATE POLICY "Only owners can delete members" ON group_members
  FOR DELETE USING (
    auth.uid() IN (
      SELECT user_id FROM group_members WHERE group_id = group_members.group_id AND role = 'owner'
    )
  );

-- ユーザーは自分自身をグループから退会可能
CREATE POLICY "Users can remove themselves from groups" ON group_members
  FOR DELETE USING (
    auth.uid() = user_id
  );

-- チップ取引テーブルのRLS
ALTER TABLE chip_transactions ENABLE ROW LEVEL SECURITY;

-- グループメンバーは取引履歴を閲覧可能
CREATE POLICY "Transactions visible to group members" ON chip_transactions
  FOR SELECT USING (
    auth.uid() IN (
      SELECT user_id FROM group_members WHERE group_id = chip_transactions.group_id
    )
  );

-- オーナーとテンポラリーオーナーのみが取引を追加可能
CREATE POLICY "Only owners can add transactions" ON chip_transactions
  FOR INSERT WITH CHECK (
    auth.uid() IN (
      SELECT user_id FROM group_members 
      WHERE group_id = chip_transactions.group_id 
      AND (role = 'owner' OR role = 'temporary_owner')
    )
  );

-- 取引は誰も編集・削除できない（履歴の不変性を保つ）

-- user_profilesテーブルのトリガー設定
-- ユーザーが作成された時にプロファイルを自動作成
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (id, display_name)
  VALUES (NEW.id, NEW.email);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- auth.usersテーブルに新しいユーザーが追加された時のトリガー
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
