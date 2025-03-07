-- 広告通知用テーブル
CREATE TABLE IF NOT EXISTS ad_notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  transaction_id UUID REFERENCES chip_transactions(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  shown BOOLEAN NOT NULL DEFAULT false,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '30 minutes')
);

-- インデックス
CREATE INDEX IF NOT EXISTS ad_notifications_user_id_idx ON ad_notifications(user_id);
CREATE INDEX IF NOT EXISTS ad_notifications_shown_idx ON ad_notifications(shown);

-- ポリシー
ALTER TABLE ad_notifications ENABLE ROW LEVEL SECURITY;

-- 自分の通知のみ参照可能
CREATE POLICY "ユーザーは自分の通知のみ参照可能" ON ad_notifications
  FOR SELECT USING (auth.uid() = user_id);

-- 自分の通知のみ更新可能
CREATE POLICY "ユーザーは自分の通知のみ更新可能" ON ad_notifications
  FOR UPDATE USING (auth.uid() = user_id);

-- 認証済みユーザーは通知を作成可能（他のユーザー宛ての通知も作成できる）
CREATE POLICY "認証済みユーザーは通知を作成可能" ON ad_notifications
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- 有効期限切れの通知を削除するトリガー
CREATE OR REPLACE FUNCTION clean_expired_ad_notifications() RETURNS trigger AS $$
BEGIN
  DELETE FROM ad_notifications WHERE expires_at < now();
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER clean_expired_ad_notifications_trigger
  AFTER INSERT ON ad_notifications
  EXECUTE PROCEDURE clean_expired_ad_notifications();
