class AppConstants {
  // プライベートコンストラクタでインスタンス化を防止
  AppConstants._();
  
  // アプリ情報
  static const String appName = 'Chip Manager';
  static const String appVersion = '1.0.0';
  
  // Supabase設定
  // TODO: 実際の値に変更する
  static const String supabaseUrl = 'https://your-project-url.supabase.co';
  static const String supabaseAnonKey = 'your-anon-key';
  
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
