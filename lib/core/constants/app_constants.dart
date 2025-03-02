class AppConstants {
  // プライベートコンストラクタでインスタンス化を防止
  AppConstants._();
  
  // アプリ情報
  static const String appName = 'Chip Manager';
  static const String appVersion = '1.0.0';
  
  // Supabase設定
  static const String supabaseUrl = 'https://xlhrouvprzbnrzlvskbj.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhsaHJvdXZwcnpibnJ6bHZza2JqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA4ODEwNzMsImV4cCI6MjA1NjQ1NzA3M30.V1H3oodJ9jYkITK1PIygBRa-PTP_nOHb7t6IKGoMxNQ';
  
  // ストレージキー
  static const String authTokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  
  // QRコード設定
  static const int qrCodeExpiryMinutes = 5; // QRコードの有効期限（分）
  static const int qrCodeSize = 200; // QRコードのサイズ（ピクセル）
  
  // エラーメッセージ
  static const String genericErrorMessage = 'エラーが発生しました。もう一度お試しください。';
  static const String networkErrorMessage = 'ネットワーク接続をご確認ください。';
  static const String authErrorMessage = '認証に失敗しました。もう一度お試しください。';
}
