class ChipTransactionModel {
  final String id;
  final String groupId;
  final String userId;
  final double amount;
  final String operatorId;
  final String? note;
  final DateTime createdAt;

  const ChipTransactionModel({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.amount,
    required this.operatorId,
    this.note,
    required this.createdAt,
  });

  factory ChipTransactionModel.fromJson(Map<String, dynamic> json) {
    return ChipTransactionModel(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      operatorId: json['operator_id'] as String,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'user_id': userId,
      'amount': amount,
      'operator_id': operatorId,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
