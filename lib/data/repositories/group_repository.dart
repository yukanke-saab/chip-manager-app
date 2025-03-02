import '../datasources/supabase_datasource.dart';
import '../models/group_model.dart';
import '../models/user_profile_model.dart';

class GroupRepository {
  final SupabaseDataSource _dataSource;
  
  GroupRepository({SupabaseDataSource? dataSource}) 
      : _dataSource = dataSource ?? SupabaseDataSource();
  
  // グループの作成
  Future<String> createGroup({
    required String name,
    required String description,
    String? chipUnit,
  }) async {
    try {
      return await _dataSource.createGroup(
        name: name,
        description: description,
        chipUnit: chipUnit,
      );
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
      await _dataSource.updateGroup(
        groupId: groupId,
        name: name,
        description: description,
        chipUnit: chipUnit,
      );
    } catch (e) {
      rethrow;
    }
  }
  
  // グループの削除
  Future<void> deleteGroup(String groupId) async {
    try {
      await _dataSource.deleteGroup(groupId);
    } catch (e) {
      rethrow;
    }
  }
  
  // ユーザーが所属するグループの取得
  Future<List<GroupModel>> getUserGroups() async {
    try {
      final response = await _dataSource.getUserGroups();
      
      return response.map((item) {
        final groupData = item['groups'] as Map<String, dynamic>;
        return GroupModel.fromJson(groupData);
      }).toList();
    } catch (e) {
      return [];
    }
  }
  
  // グループ詳細の取得
  Future<GroupModel?> getGroupDetails(String groupId) async {
    try {
      final response = await _dataSource.getGroupDetails(groupId);
      return GroupModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }
  
  // グループメンバーの取得
  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    try {
      final response = await _dataSource.getGroupMembers(groupId);
      
      return response.map((item) {
        final profileData = item['user_profiles'] as Map<String, dynamic>;
        final profile = UserProfileModel.fromJson(profileData);
        
        return GroupMember(
          userId: item['user_id'] as String,
          role: item['role'] as String,
          tempOwnerUntil: item['temp_owner_until'] != null 
              ? DateTime.parse(item['temp_owner_until'] as String)
              : null,
          profile: profile,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }
  
  // グループへの参加（招待コード経由）
  Future<void> joinGroupByInviteCode(String inviteCode) async {
    try {
      await _dataSource.joinGroupByInviteCode(inviteCode);
    } catch (e) {
      rethrow;
    }
  }
  
  // グループからの脱退
  Future<void> leaveGroup(String groupId) async {
    try {
      await _dataSource.leaveGroup(groupId);
    } catch (e) {
      rethrow;
    }
  }
  
  // メンバーのロール変更
  Future<void> updateMemberRole(String groupId, String userId, String newRole, {DateTime? tempOwnerUntil}) async {
    try {
      await _dataSource.updateMemberRole(
        groupId,
        userId,
        newRole,
        tempOwnerUntil: tempOwnerUntil,
      );
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
      await _dataSource.addChipTransaction(
        groupId: groupId,
        userId: userId,
        amount: amount,
        note: note,
      );
    } catch (e) {
      rethrow;
    }
  }
  
  // グループの取引履歴取得
  Future<List<Map<String, dynamic>>> getGroupTransactions(String groupId) async {
    try {
      return await _dataSource.getGroupTransactions(groupId);
    } catch (e) {
      return [];
    }
  }
  
  // ユーザーのチップ残高取得
  Future<double> getUserBalance(String groupId, String userId) async {
    try {
      return await _dataSource.getUserBalance(groupId, userId);
    } catch (e) {
      return 0.0;
    }
  }
}

class GroupMember {
  final String userId;
  final String role;
  final DateTime? tempOwnerUntil;
  final UserProfileModel profile;
  
  GroupMember({
    required this.userId,
    required this.role,
    this.tempOwnerUntil,
    required this.profile,
  });
  
  bool get isOwner => role == 'owner';
  bool get isTemporaryOwner => role == 'temporary_owner';
  bool get isMember => role == 'member';
  
  // 一時的なオーナー権限が有効かどうか
  bool get isTempOwnerActive {
    if (role != 'temporary_owner' || tempOwnerUntil == null) return false;
    return tempOwnerUntil!.isAfter(DateTime.now());
  }
}
