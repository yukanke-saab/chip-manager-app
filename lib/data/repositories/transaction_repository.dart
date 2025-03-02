import '../datasources/supabase_datasource.dart';
import '../models/chip_transaction_model.dart';
import '../models/user_profile_model.dart';

class TransactionRepository {
  final SupabaseDataSource _dataSource;
  
  TransactionRepository({SupabaseDataSource? dataSource}) 
      : _dataSource = dataSource ?? SupabaseDataSource();
  
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
  
  // ユーザーのチップ残高取得
  Future<double> getUserBalance(String groupId, String userId) async {
    try {
      return await _dataSource.getUserBalance(groupId, userId);
    } catch (e) {
      return 0.0;
    }
  }
  
  // ユーザーの取引履歴取得
  Future<List<ChipTransactionModel>> getUserTransactions(String groupId, String userId) async {
    try {
      final response = await _dataSource.getUserTransactions(groupId, userId);
      
      return response.map((item) => ChipTransactionModel.fromJson(item)).toList();
    } catch (e) {
      rethrow;
    }
  }
  
  // グループの取引履歴取得
  Future<List<TransactionWithUser>> getGroupTransactions(String groupId) async {
    try {
      final response = await _dataSource.getGroupTransactions(groupId);
      
      return response.map((item) {
        final profileData = item['user_profiles'] as Map<String, dynamic>;
        final profile = UserProfileModel.fromJson(profileData);
        final transaction = ChipTransactionModel.fromJson(item);
        
        return TransactionWithUser(
          transaction: transaction,
          userProfile: profile,
        );
      }).toList();
    } catch (e) {
      rethrow;
    }
  }
}

class TransactionWithUser {
  final ChipTransactionModel transaction;
  final UserProfileModel userProfile;
  
  TransactionWithUser({
    required this.transaction,
    required this.userProfile,
  });
}
