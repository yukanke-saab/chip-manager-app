import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';

class SupabaseDataSource {
  // シングルトンパターンを適用
  static final SupabaseDataSource _instance = SupabaseDataSource._internal();
  
  factory SupabaseDataSource() {
    return _instance;
  }
  
  SupabaseDataSource._internal();
  
  // Supabaseクライアントのゲッター
  SupabaseClient get client => Supabase.instance.client;
  
  // 現在のユーザーを取得
  User? get currentUser => client.auth.currentUser;
  
  // ユーザーのサインアップ
  Future<User?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await client.auth.signUp(
        email: email,
        password: password,
      );
      
      final user = response.user;
      
      if (user != null) {
        // ユーザープロファイルを作成
        await client.from('user_profiles').insert({
          'id': user.id,
          'display_name': displayName,
          'avatar_url': null,
        });
      }
      
      return user;
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
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      return response.user;
    } catch (e) {
      rethrow;
    }
  }
  
  // ユーザーのサインアウト
  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }
  
  // パスワードリセットメールの送信
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await client.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }
  
  // ユーザープロファイルの取得
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      final response = await client
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .single();
      
      return response;
    } catch (e) {
      rethrow;
    }
  }
  
  // ユーザープロファイルの更新
  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      await client
          .from('user_profiles')
          .update(data)
          .eq('id', userId);
    } catch (e) {
      rethrow;
    }
  }
  
  // グループの作成
  Future<String> createGroup({
    required String name,
    required String description,
    String? chipUnit,
  }) async {
    try {
      final userId = currentUser?.id;
      if (userId == null) {
        throw Exception('ユーザーが認証されていません');
      }
      
      // ランダムな招待コードを生成
      final inviteCode = _generateInviteCode();
      
      final response = await client
          .from('groups')
          .insert({
            'name': name,
            'description': description,
            'chip_unit': chipUnit ?? '1',
            'invite_code': inviteCode,
            'owner_id': userId,
          })
          .select('id')
          .single();
      
      final groupId = response['id'] as String;
      
      // 作成者をオーナーとしてグループメンバーに追加
      await client
          .from('group_members')
          .insert({
            'group_id': groupId,
            'user_id': userId,
            'role': 'owner',
          });
      
      return groupId;
    } catch (e) {
      rethrow;
    }
  }
  
  // グループの更新
  Future<void> updateGroup({
    required String groupId,
    String? name,
    String? description,
    String? chipUnit,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      
      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (chipUnit != null) updateData['chip_unit'] = chipUnit;
      
      if (updateData.isNotEmpty) {
        await client
            .from('groups')
            .update(updateData)
            .eq('id', groupId);
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // グループの削除
  Future<void> deleteGroup(String groupId) async {
    try {
      await client
          .from('groups')
          .delete()
          .eq('id', groupId);
    } catch (e) {
      rethrow;
    }
  }
  
  // ユーザーが所属するグループの取得
  Future<List<Map<String, dynamic>>> getUserGroups() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) {
        throw Exception('ユーザーが認証されていません');
      }
      
      final response = await client
          .from('group_members')
          .select('group_id, role, groups(*)')
          .eq('user_id', userId);
      
      return response;
    } catch (e) {
      rethrow;
    }
  }
  
  // グループ詳細の取得
  Future<Map<String, dynamic>> getGroupDetails(String groupId) async {
    try {
      final response = await client
          .from('groups')
          .select()
          .eq('id', groupId)
          .single();
      
      return response;
    } catch (e) {
      rethrow;
    }
  }
  
  // グループメンバーの取得
  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    try {
      final response = await client
          .from('group_members')
          .select('user_id, role, temp_owner_until, user_profiles(*)')
          .eq('group_id', groupId);
      
      return response;
    } catch (e) {
      rethrow;
    }
  }
  
  // グループへの参加（招待コード経由）
  Future<void> joinGroupByInviteCode(String inviteCode) async {
    try {
      final userId = currentUser?.id;
      if (userId == null) {
        throw Exception('ユーザーが認証されていません');
      }
      
      // グループIDを取得
      final groupResponse = await client
          .from('groups')
          .select('id')
          .eq('invite_code', inviteCode)
          .single();
      
      final groupId = groupResponse['id'] as String;
      
      // メンバーとして追加
      await client
          .from('group_members')
          .insert({
            'group_id': groupId,
            'user_id': userId,
            'role': 'member',
          });
    } catch (e) {
      rethrow;
    }
  }

  // グループからの脱退
  Future<void> leaveGroup(String groupId) async {
    try {
      final userId = currentUser?.id;
      if (userId == null) {
        throw Exception('ユーザーが認証されていません');
      }
      
      await client
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', userId);
    } catch (e) {
      rethrow;
    }
  }
  
  // メンバーのロール変更
  Future<void> updateMemberRole(String groupId, String userId, String newRole, {DateTime? tempOwnerUntil}) async {
    try {
      final updateData = {
        'role': newRole,
      };
      
      if (tempOwnerUntil != null) {
        updateData['temp_owner_until'] = tempOwnerUntil.toIso8601String();
      } else if (newRole != 'temporary_owner') {
        updateData['temp_owner_until'] = null;
      }
      
      await client
          .from('group_members')
          .update(updateData)
          .eq('group_id', groupId)
          .eq('user_id', userId);
    } catch (e) {
      rethrow;
    }
  }
  
  // チップ取引の作成
  Future<void> addChipTransaction({
    required String groupId,
    required String userId,
    required double amount,
    String? note,
  }) async {
    try {
      final operatorId = currentUser?.id;
      if (operatorId == null) {
        throw Exception('ユーザーが認証されていません');
      }
      
      await client
          .from('chip_transactions')
          .insert({
            'group_id': groupId,
            'user_id': userId,
            'amount': amount,
            'operator_id': operatorId,
            'note': note,
          });
    } catch (e) {
      rethrow;
    }
  }
  
  // ユーザーのチップ残高取得
  Future<double> getUserBalance(String groupId, String userId) async {
    try {
      final response = await client
          .from('chip_balances')
          .select('balance')
          .eq('group_id', groupId)
          .eq('user_id', userId)
          .maybeSingle();
      
      if (response == null) return 0.0;
      return (response['balance'] as num).toDouble();
    } catch (e) {
      return 0.0;
    }
  }
  
  // ユーザーの取引履歴取得
  Future<List<Map<String, dynamic>>> getUserTransactions(String groupId, String userId) async {
    try {
      final response = await client
          .from('chip_transactions')
          .select('*')
          .eq('group_id', groupId)
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      return response;
    } catch (e) {
      rethrow;
    }
  }
  
  // グループの取引履歴取得
  Future<List<Map<String, dynamic>>> getGroupTransactions(String groupId) async {
    try {
      final response = await client
          .from('chip_transactions')
          .select('*, user_profiles!inner(*)')
          .eq('group_id', groupId)
          .order('created_at', ascending: false);
      
      return response;
    } catch (e) {
      rethrow;
    }
  }
  
  // 招待コードの生成
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        6, // 6桁のコード
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }
}
