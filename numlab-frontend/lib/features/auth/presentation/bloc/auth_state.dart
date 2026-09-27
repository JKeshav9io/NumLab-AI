import 'package:equatable/equatable.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/auth/domain/entities/user.dart';

/// Sealed hierarchy of all authentication states emitted by AuthBloc.
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any authentication or session restoration checks have started.
final class AuthInitial extends AuthState {
  const AuthInitial();
}

/// State emitted while an asynchronous auth action (login, register, logout, init) is executing.
final class AuthLoading extends AuthState {
  const AuthLoading({this.message});

  final String? message;

  @override
  List<Object?> get props => [message];
}

/// State representing an active, authenticated user session.
final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({required this.user});

  final User user;

  @override
  List<Object?> get props => [user];
}

/// State representing an unauthenticated session (e.g. logged out, revoked, or uninitialized).
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.message});

  final String? message;

  @override
  List<Object?> get props => [message];
}

/// State representing an authentication failure (e.g. invalid credentials, network error).
final class AuthError extends AuthState {
  const AuthError({required this.failure});

  final Failure failure;

  /// Convenience accessor for the error message derived from [failure].
  String get message => failure.message;

  @override
  List<Object?> get props => [failure];
}
