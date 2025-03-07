import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ad_notification_model.dart';

class AdNotificationRepository {
  // Supabaseクライアント
  final _supabase = Supabase.instance.client;
  
  // テーブル名
  static const _tableName = 'ad_notifications';
  
  // 現在のユーザーID
  String? get _currentUserId => _supabase.auth.currentUser?.id;
  
  // 新しい広告通知を作成
  Future<String?> createAdNotification({
    required String targetUserId,
    required String groupId,
    String? transactionId,
  }) async {
    try {
      // ユーザーが認証されていない場合はnullを返す
      if (_currentUserId == null) return null;
      
      // 通知データを作成
      final notificationData = {
        'user_id': targetUserId,
        'group_id': groupId,
        if (transactionId != null) 'transaction_id': transactionId,
        'shown': false,
      };
      
      // DBに挿入
      final response = await _supabase
          .from(_tableName)
          .insert(notificationData)
          .select()
          .single();
      
      // 作成された通知のIDを返す
      return response['id'] as String;
    } catch (e) {
      print('広告通知の作成に失敗しました: $e');
      return null;
    }
  }
  
  // 未表示の広告通知を取得
  Future<List<AdNotificationModel>> getUnshownNotifications() async {
    try {
      // ユーザーが認証されていない場合は空のリストを返す
      if (_currentUserId == null) return [];
      
      // 有効期限内で未表示の通知を取得
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('user_id', _currentUserId)
          .eq('shown', false)
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);
      
      // 通知モデルに変換
      return (response as List<dynamic>)
          .map((json) => AdNotificationModel.fromJson(json))
          .toList();
    } catch (e) {
      print('広告通知の取得に失敗しました: $e');
      return [];
    }
  }
  
  // 通知を表示済みにする
  Future<bool> markAsShown(String notificationId) async {
    try {
      // ユーザーが認証されていない場合はfalseを返す
      if (_currentUserId == null) return false;
      
      // 通知を表示済みに更新
      await _supabase
          .from(_tableName)
          .update({'shown': true})
          .eq('id', notificationId)
          .eq('user_id', _currentUserId);
      
      return true;
    } catch (e) {
      print('広告通知の更新に失敗しました: $e');
      return false;
    }
  }
  
  // リアルタイム更新を購読
  Stream<List<AdNotificationModel>> subscribeToNotifications() {
    // ユーザーが認証されていない場合は空のストリームを返す
    if (_currentUserId == null) {
      return Stream.value([]);
    }
    
    // リアルタイム更新を購読
    return _supabase
        .from(_tableName)
        .stream(primaryKey: ['id'])
        .eq('user_id', _currentUserId)
        .eq('shown', false)
        .map((data) => 
            data.map((json) => AdNotificationModel.fromJson(json)).toList());
  }
}
