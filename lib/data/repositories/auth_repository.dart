import 'package:supabase_flutter/supabase_flutter.dart';
import '../datasources/supabase_datasource.dart';
import '../models/user_profile_model.dart';

class AuthRepository {
  final SupabaseDataSource _dataSource;
  
  AuthRepository({SupabaseDataSource? dataSource}) 
      : _dataSource = dataSource ?? SupabaseDataSource();
  
  // 現在のユーザーを取得
  User? get currentUser => _dataSource.currentUser;
  
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
  Future<UserProfileModel> getUserProfile(String userId) async {
    try {
      final response = await _dataSource.getUserProfile(userId);
      return UserProfileModel.fromJson(response);
    } catch (e) {
      rethrow;
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
