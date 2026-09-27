import 'package:equatable/equatable.dart';

/// Domain entity representing a NumLab AI user.
class User extends Equatable {
  const User({
    required this.id,
    required this.email,
    required this.emailVerified,
    required this.createdAt,
    this.lastLoginAt,
    this.updatedAt,
  });

  /// Unique UUID of the user.
  final String id;

  /// User email address.
  final String email;

  /// Whether the user has verified their email address.
  final bool emailVerified;

  /// Account creation timestamp.
  final DateTime createdAt;

  /// Last login timestamp, or null if never logged in.
  final DateTime? lastLoginAt;

  /// Last profile update timestamp.
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [
    id,
    email,
    emailVerified,
    createdAt,
    lastLoginAt,
    updatedAt,
  ];
}
