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
      if (user.email == null) {
        // メールアドレスが設定されていない = 匿名ユーザー
        return true;
      }
      
      // プロファイルで匿名フラグをチェック
      try {
        final profile = await getUserProfile(user.id);
        return profile['is_anonymous'] == true;
      } catch (e) {
        return true;
      }
    } catch (e) {
      return true;
    }
  }
  
  // 匿名セッションを作成または取得
  Future<User?> getOrCreateAnonymousSession() async {
    final user = currentUser;
    if (user != null) {
      // 既存ユーザーがいる場合はそれを返す
      final isAnon = await isAnonymousUser();
      if (isAnon) {
        return user; // 既に匿名ユーザー
      }
      return user; // 登録済みユーザー
    }
    
    try {
      // Supabaseの匿名認証を使用
      final response = await client.auth.signInAnonymously();
      
      final newUser = response.user;
      if (newUser != null) {
        // ユーザープロファイルを作成
        try {
          await client.from('user_profiles').upsert({
            'id': newUser.id,
            'display_name': 'ゲストユーザー',
            'is_anonymous': true,
          });
        } catch (e) {
          // プロファイル作成エラーは無視（すでに存在する場合など）
          print('Profile creation error: $e');
        }
      }
      
      return newUser;
    } catch (e) {
      print('匿名ログインエラー: $e');
      // エラーが発生しても処理を続行するためにnullを返す
      return null;
    }
  }
  
  // ユーザーのサインアップ
  Future<User?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final isAnonymous = await isAnonymousUser();
      
      if (isAnonymous && currentUser != null) {
        // 匿名ユーザーを実ユーザーに変換
        await client.auth.updateUser(
          UserAttributes(
            email: email,
            password: password,
            data: {
              'is_anonymous': false,
              'display_name': displayName,
            },
          ),
        );
        
        // プロフィールを更新
        await client.from('user_profiles').upsert({
          'id': currentUser!.id,
          'display_name': displayName,
          'is_anonymous': false,
        });
        
        return currentUser;
      } else {
        // 新規ユーザー登録
        final response = await client.auth.signUp(
          email: email,
          password: password,
          data: {
            'display_name': displayName,
            'is_anonymous': false,
          },
        );
        
        final user = response.user;
        if (user != null) {
          try {
            await client.from('user_profiles').insert({
              'id': user.id,
              'display_name': displayName,
              'is_anonymous': false,
            });
          } catch (e) {
            // プロファイル作成エラーは無視
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
  
  // ユーザーのサインアウト後、匿名セッションを作成
  Future<void> signOut() async {
    try {
      await client.auth.signOut();
      // 匿名セッションに切り替え
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
      // プロファイルが存在しなければ作成
      if (userId == currentUser?.id) {
        final userData = currentUser!.userMetadata ?? {};
        final displayName = userData['display_name'] as String? ?? 'ゲストユーザー';
        
        try {
          await client.from('user_profiles').insert({
            'id': userId,
            'display_name': displayName,
            'is_anonymous': userData['is_anonymous'] as bool? ?? true,
          });
          
          return {
            'id': userId,
            'display_name': displayName,
            'is_anonymous': userData['is_anonymous'] as bool? ?? true,
            'created_at': DateTime.now().toIso8601String(),
          };
        } catch (e) {
          rethrow;
        }
      }
      
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
      // 現在のユーザーを取得
      User? user = currentUser;
      String? userId;
      
      if (user != null) {
        userId = user.id;
      } else {
        try {
          // 匿名セッションを試行
          user = await getOrCreateAnonymousSession();
          if (user != null) {
            userId = user.id;
          }
        } catch (e) {
          print('匿名セッション作成中のエラー: $e');
          // 大事なのはグループ作成なので継続
        }
      }
      
      // デバイスIDを取得してフォールバックとして使用
      final deviceId = await getDeviceId();
      
      // ランダムな招待コードを生成
      final inviteCode = _generateInviteCode();
      
      // グループ作成データを準備
      final groupData = {
        'name': name,
        'description': description,
        'chip_unit': chipUnit ?? '1',
        'invite_code': inviteCode,
        // ユーザーIDがない場合はデバイスIDを使用
        'owner_id': userId ?? deviceId,
      };
      
      final response = await client
          .from('groups')
          .insert(groupData)
          .select('id')
          .single();
      
      final groupId = response['id'] as String;
      
      // 作成者をオーナーとしてグループメンバーに追加
      final memberData = {
        'group_id': groupId,
        'user_id': userId ?? deviceId,
        'role': 'owner',
      };
      
      await client
          .from('group_members')
          .insert(memberData);
      
      // デバイスIDをローカルストレージに保存
      final prefs = await SharedPreferences.getInstance();
      final ownedGroups = prefs.getStringList('owned_groups') ?? [];
      ownedGroups.add(groupId);
      await prefs.setStringList('owned_groups', ownedGroups);
      
      print('作成したグループID: $groupId');
      print('ローカル保存済みグループIDs: $ownedGroups');
      
      return groupId;
    } catch (e) {
      print('グループ作成中のエラー: $e');
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
      // 現在のユーザーを取得
      String? userId;
      User? user = currentUser;
      
      if (user != null) {
        userId = user.id;
        print('ユーザーIDで検索: $userId');
      } else {
        try {
          // 匿名セッションを試行
          user = await getOrCreateAnonymousSession();
          if (user != null) {
            userId = user.id;
            print('匿名ユーザーIDで検索: $userId');
          }
        } catch (e) {
          print('匿名セッション作成中のエラー: $e');
          // 継続する
        }
      }
      
      // デバイスIDを取得
      final deviceId = await getDeviceId();
      print('デバイスID: $deviceId');
      
      // ユーザーIDがあればそれで、なければデバイスIDでグループを検索
      final targetId = userId ?? deviceId;
      print('グループ検索用ID: $targetId');
      
      List<Map<String, dynamic>> result = [];
      
      // グループメンバーテーブルからグループを検索
      try {
        final response = await client
            .from('group_members')
            .select('group_id, role, groups(*)')
            .eq('user_id', targetId);
        
        print('メンバーテーブルから取得したグループ数: ${response.length}');
        result.addAll(response);
      } catch (e) {
        print('メンバーテーブルからの取得エラー: $e');
      }
      
      // ローカルに保存されている所有グループを取得
      final prefs = await SharedPreferences.getInstance();
      final ownedGroups = prefs.getStringList('owned_groups') ?? [];
      print('ローカル保存グループ数: ${ownedGroups.length}');
      if (ownedGroups.isNotEmpty) {
        print('ローカル保存グループIDs: $ownedGroups');
      }
      
      // デバイスIDのみで作成したグループに対して追加取得
      if (ownedGroups.isNotEmpty) {
        try {
          // ここではシンプルなアプローチとして、すべてのグループを取得
          final allGroups = await client
              .from('groups')
              .select('*');
          
          // ローカルに保存されたグループのみをフィルタリング
          final filteredGroups = allGroups.where((group) => 
              ownedGroups.contains(group['id'].toString())).toList();
          
          print('ローカル保存グループの取得数: ${filteredGroups.length}');
          
          // 結果に追加
          result.addAll(filteredGroups.map((group) => {
            'group_id': group['id'],
            'role': 'owner',
            'groups': group,
          }));
        } catch (e) {
          print('ローカルグループ取得エラー: $e');
        }
      }
      
      // グループがうまく取得できない場合に、すべてのグループを取得するフォールバック
      if (result.isEmpty) {
        try {
          print('バックアップ: すべてのグループを取得');
          final allGroups = await client
              .from('groups')
              .select('*');
          
          print('すべてのグループ数: ${allGroups.length}');
          result.addAll(allGroups.map((group) => {
            'group_id': group['id'],
            'role': 'member',
            'groups': group,
          }));
        } catch (e) {
          print('すべてのグループ取得エラー: $e');
        }
      }
      
      print('最終的なグループ数: ${result.length}');
      return result;
    } catch (e) {
      print('グループ一覧取得エラー: $e');
      return [];
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
      // 現在のユーザーを取得
      User? user = currentUser;
      String? userId;
      
      if (user != null) {
        userId = user.id;
      } else {
        try {
          // 匿名セッションを試行
          user = await getOrCreateAnonymousSession();
          if (user != null) {
            userId = user.id;
          }
        } catch (e) {
          print('匿名セッション作成中のエラー: $e');
        }
      }
      
      // デバイスIDをフォールバックとして使用
      final deviceId = await getDeviceId();
      final targetId = userId ?? deviceId;
      
      // グループIDを取得
      final groupResponse = await client
          .from('groups')
          .select('id')
          .eq('invite_code', inviteCode)
          .single();
      
      final groupId = groupResponse['id'] as String;
      
      // 既に参加済みか確認
      final memberCheck = await client
          .from('group_members')
          .select('id')
          .eq('group_id', groupId)
          .eq('user_id', targetId)
          .maybeSingle();
      
      if (memberCheck != null) {
        // 既に参加済み
        throw Exception('既にこのグループに参加しています');
      }
      
      // メンバーとして追加
      await client
          .from('group_members')
          .insert({
            'group_id': groupId,
            'user_id': targetId,
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
