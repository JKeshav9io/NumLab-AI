import 'package:equatable/equatable.dart';

/// Sealed hierarchy of all authentication events handled by AuthBloc.
sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched upon app startup to inspect persisted credentials and restore session.
final class AuthInitializeRequested extends AuthEvent {
  const AuthInitializeRequested();
}

/// Dispatched when a user attempts to log in with [email] and [password].
final class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

/// Dispatched when a user attempts to register with [email] and [password].
final class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

/// Dispatched to log out the current device session and revoke its refresh token.
final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Dispatched to log out all active sessions across all devices for the current user.
final class AuthLogoutAllRequested extends AuthEvent {
  const AuthLogoutAllRequested();
}

/// Dispatched to explicitly rotate session tokens.
final class AuthSessionRefreshRequested extends AuthEvent {
  const AuthSessionRefreshRequested();
}

/// Dispatched to re-fetch the latest authenticated user profile.
final class AuthGetCurrentUserRequested extends AuthEvent {
  const AuthGetCurrentUserRequested();
}

/// Dispatched when the network interceptor reports an invalid or revoked session.
final class AuthSessionRevoked extends AuthEvent {
  const AuthSessionRevoked();
}
