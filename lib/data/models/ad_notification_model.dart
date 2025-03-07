import 'package:intl/intl.dart';

class AdNotificationModel {
  final String id;
  final String userId;
  final String groupId;
  final String? transactionId;
  final DateTime createdAt;
  final bool shown;
  final DateTime expiresAt;

  AdNotificationModel({
    required this.id,
    required this.userId,
    required this.groupId,
    this.transactionId,
    required this.createdAt,
    required this.shown,
    required this.expiresAt,
  });

  // JSONからモデルを作成
  factory AdNotificationModel.fromJson(Map<String, dynamic> json) {
    return AdNotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      groupId: json['group_id'] as String,
      transactionId: json['transaction_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      shown: json['shown'] as bool,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  // モデルからJSONを作成
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'group_id': groupId,
      'transaction_id': transactionId,
      'created_at': createdAt.toIso8601String(),
      'shown': shown,
      'expires_at': expiresAt.toIso8601String(),
    };
  }

  // 新規作成時のJSONを返す
  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'group_id': groupId,
      if (transactionId != null) 'transaction_id': transactionId,
      'shown': shown,
    };
  }

  // 更新用に表示済みフラグをtrueにしたコピーを作成
  AdNotificationModel copyWithShown() {
    return AdNotificationModel(
      id: id,
      userId: userId,
      groupId: groupId,
      transactionId: transactionId,
      createdAt: createdAt,
      shown: true,
      expiresAt: expiresAt,
    );
  }

  // 通知が有効かどうか
  bool get isValid => DateTime.now().isBefore(expiresAt);

  // フォーマットされた作成日時
  String get formattedCreatedAt => 
      DateFormat('yyyy/MM/dd HH:mm').format(createdAt);
}
