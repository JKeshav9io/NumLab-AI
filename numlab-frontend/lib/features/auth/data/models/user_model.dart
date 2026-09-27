import 'package:numlab_frontend/features/auth/domain/entities/user.dart';

/// Immutable representation of an authenticated user in NumLab AI.
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.emailVerified,
    required super.createdAt,
    super.lastLoginAt,
    super.updatedAt,
  });

  /// Factory constructor to parse from backend user JSON map.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      emailVerified: json['emailVerified'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Parses user from backend response data envelope, supporting both
  /// direct data payload `{ id: ..., email: ... }` and nested `{ user: { ... } }`.
  factory UserModel.fromResponseData(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data.containsKey('user') && data['user'] is Map<String, dynamic>) {
        return UserModel.fromJson(data['user'] as Map<String, dynamic>);
      }
      return UserModel.fromJson(data);
    }
    throw const FormatException('Expected Map<String, dynamic> for user data');
  }

  /// Constructs a [UserModel] from a domain [User] entity.
  factory UserModel.fromEntity(User user) {
    return UserModel(
      id: user.id,
      email: user.email,
      emailVerified: user.emailVerified,
      createdAt: user.createdAt,
      lastLoginAt: user.lastLoginAt,
      updatedAt: user.updatedAt,
    );
  }

  /// Converts this data model to a domain [User] entity.
  User toEntity() {
    return User(
      id: id,
      email: email,
      emailVerified: emailVerified,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'email': email,
      'emailVerified': emailVerified,
      'createdAt': createdAt.toIso8601String(),
      if (lastLoginAt != null) 'lastLoginAt': lastLoginAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }
}
