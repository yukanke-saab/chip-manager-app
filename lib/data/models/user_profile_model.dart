class UserProfileModel {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final DateTime createdAt;

  const UserProfileModel({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    required this.createdAt,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserProfileModel copyWith({
    String? displayName,
    String? avatarUrl,
  }) {
    return UserProfileModel(
      id: id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
    );
  }
}
