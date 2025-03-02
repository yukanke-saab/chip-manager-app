class UserProfileModel {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final DateTime createdAt;
  final bool isAnonymous;

  const UserProfileModel({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    required this.createdAt,
    this.isAnonymous = false,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isAnonymous: json['is_anonymous'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'is_anonymous': isAnonymous,
    };
  }

  UserProfileModel copyWith({
    String? displayName,
    String? avatarUrl,
    bool? isAnonymous,
  }) {
    return UserProfileModel(
      id: id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }
}
