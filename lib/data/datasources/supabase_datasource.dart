import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
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
  
  // セキュアストレージ
  final _secureStorage = const FlutterSecureStorage();
  
  // デバイスID用のキー
  static const String _deviceIdKey = 'device_id';
  
  // 現在のユーザーを取得
  User? get currentUser => client.auth.currentUser;
  
  // デバイスIDを取得（なければ生成）
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);
    
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString(_deviceIdKey, deviceId);
    }
    
    return deviceId;
  }
  
  // 匿名ユーザーかどうかを確認
  Future<bool> isAnonymousUser() async {
    final user = currentUser;
    if (user == null) return true;
    
    try {
      final userProfile = await getUserProfile(user.id);
      return userProfile['is_anonymous'] == true;
    } catch (e) {
      return true;
    }
  }
  
  // 匿名セッションを作成または取得
  Future<User?> getOrCreateAnonymousSession() async {
    final user = currentUser;
    if (user != null) return user;
    
    try {
      // デバイスIDをパスワードとして使用
      final deviceId = await getDeviceId();
      final email = '$deviceId@anonymous.user';
      final password = deviceId;
      
      try {
        // 既存の匿名ユーザーでログイン試行
        final response = await client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        return response.user;
      } catch (e) {
        // 存在しなければ新規作成
        final response = await client.auth.signUp(
          email: email,
          password: password,
        );
        
        final newUser = response.user;
        if (newUser != null) {
          // 匿名フラグを立てる
          await client.from('user_profiles').upsert({
            'id': newUser.id,
            'display_name': 'Anonymous User',
            'is_anonymous': true,
          });
        }
        
        return newUser;
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // ユーザーのサインアップ
  Future<User?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      // 現在のユーザー状態を確認
      final currentUser = client.auth.currentUser;
      final isAnonymous = currentUser != null ? await isAnonymousUser() : false;
      
      if (isAnonymous) {
        // 匿名ユーザーの場合は、本登録に切り替える
        await client.auth.updateUser(
          UserAttributes(
            email: email,
            password: password,
          ),
        );
        
        // プロフィールを更新
        await client.from('user_profiles').update({
          'display_name': displayName,
          'is_anonymous': false,
        }).eq('id', currentUser!.id);
        
        return client.auth.currentUser;
      } else {
        // 新規ユーザー登録
        final response = await client.auth.signUp(
          email: email,
          password: password,
        );
        
        final user = response.user;
        
        if (user != null) {
          // プロフィールを作成（トリガーでの自動作成に失敗する場合の対策）
          try {
            await client.from('user_profiles').upsert({
              'id': user.id,
              'display_name': displayName,
              'is_anonymous': false,
            });
          } catch (e) {
            // upsertなので既にデータがあれば上書き、なければ挿入
            print('Profile creation error: $e');
          }
        }
        
        return user;
      }
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
      // 匿名セッションを自動的に作成
      await getOrCreateAnonymousSession();
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
      // 匿名セッションがなければ作成
      final user = await getOrCreateAnonymousSession();
      if (user == null) {
        throw Exception('セッションの作成に失敗しました');
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
            'owner_id': user.id,
          })
          .select('id')
          .single();
      
      final groupId = response['id'] as String;
      
      // 作成者をオーナーとしてグループメンバーに追加
      await client
          .from('group_members')
          .insert({
            'group_id': groupId,
            'user_id': user.id,
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
      // 匿名セッションがなければ作成
      final user = await getOrCreateAnonymousSession();
      if (user == null) {
        throw Exception('セッションの作成に失敗しました');
      }
      
      final response = await client
          .from('group_members')
          .select('group_id, role, groups(*)')
          .eq('user_id', user.id);
      
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
      // 匿名セッションがなければ作成
      final user = await getOrCreateAnonymousSession();
      if (user == null) {
        throw Exception('セッションの作成に失敗しました');
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
            'user_id': user.id,
            'role': 'member',
          });
    } catch (e) {
      rethrow;
    }
  }

  // グループからの脱退
  Future<void> leaveGroup(String groupId) async {
    try {
      // 匿名セッションがなければ作成
      final user = await getOrCreateAnonymousSession();
      if (user == null) {
        throw Exception('セッションの作成に失敗しました');
      }
      
      await client
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', user.id);
    } catch (e) {
      rethrow;
    }
  }
  
  // メンバーのロール変更
  Future<void> updateMemberRole(String groupId, String userId, String newRole, {DateTime? tempOwnerUntil}) async {
    try {
      final Map<String, dynamic> updateData = {
        'role': newRole,
      };
      
      if (tempOwnerUntil != null) {
        updateData['temp_owner_until'] = tempOwnerUntil.toIso8601String();
      } else if (newRole != 'temporary_owner') {
        // 空文字列を使用
        updateData['temp_owner_until'] = '';
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
      // 匿名セッションがなければ作成
      final operator = await getOrCreateAnonymousSession();
      if (operator == null) {
        throw Exception('セッションの作成に失敗しました');
      }
      
      await client
          .from('chip_transactions')
          .insert({
            'group_id': groupId,
            'user_id': userId,
            'amount': amount,
            'operator_id': operator.id,
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
