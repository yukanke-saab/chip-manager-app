class GroupModel {
  final String id;
  final String name;
  final String description;
  final String chipUnit;
  final String inviteCode;
  final String ownerId;
  final DateTime createdAt;

  const GroupModel({
    required this.id,
    required this.name,
    required this.description,
    required this.chipUnit,
    required this.inviteCode,
    required this.ownerId,
    required this.createdAt,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      chipUnit: json['chip_unit'] as String,
      inviteCode: json['invite_code'] as String,
      ownerId: json['owner_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'chip_unit': chipUnit,
      'invite_code': inviteCode,
      'owner_id': ownerId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  GroupModel copyWith({
    String? name,
    String? description,
    String? chipUnit,
    String? inviteCode,
  }) {
    return GroupModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      chipUnit: chipUnit ?? this.chipUnit,
      inviteCode: inviteCode ?? this.inviteCode,
      ownerId: ownerId,
      createdAt: createdAt,
    );
  }
}
