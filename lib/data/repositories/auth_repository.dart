import 'package:supabase_flutter/supabase_flutter.dart';
import '../datasources/supabase_datasource.dart';
import '../models/user_profile_model.dart';

class AuthRepository {
  final SupabaseDataSource _dataSource;
  
  AuthRepository({SupabaseDataSource? dataSource}) 
      : _dataSource = dataSource ?? SupabaseDataSource();
  
  // 現在のユーザーを取得
  User? get currentUser => _dataSource.currentUser;
  
  // 匿名ユーザーかどうかを確認
  Future<bool> isAnonymousUser() async {
    return await _dataSource.isAnonymousUser();
  }
  
  // 匿名セッションを作成または取得
  Future<User?> getOrCreateAnonymousSession() async {
    return await _dataSource.getOrCreateAnonymousSession();
  }
  
  // ユーザーのサインアップ
  Future<User?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      return await _dataSource.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
    } catch (e) {
      rethrow;
    }
  }
  
  // ユーザーのサインイン
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _dataSource.signIn(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }
  
  // ユーザーのサインアウト
  Future<void> signOut() async {
    try {
      await _dataSource.signOut();
    } catch (e) {
      rethrow;
    }
  }
  
  // パスワードリセットメールの送信
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _dataSource.sendPasswordResetEmail(email);
    } catch (e) {
      rethrow;
    }
  }
  
  // ユーザープロファイルの取得
  Future<UserProfileModel?> getUserProfile([String? userId]) async {
    try {
      if (currentUser == null && userId == null) {
        return null;
      }
      
      final id = userId ?? currentUser!.id;
      final response = await _dataSource.getUserProfile(id);
      return UserProfileModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }
  
  // ユーザープロファイルの更新
  Future<void> updateUserProfile({
    required String userId,
    String? displayName,
    String? avatarUrl,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      
      if (displayName != null) updateData['display_name'] = displayName;
      if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;
      
      if (updateData.isNotEmpty) {
        await _dataSource.updateUserProfile(userId, updateData);
      }
    } catch (e) {
      rethrow;
    }
  }
}
