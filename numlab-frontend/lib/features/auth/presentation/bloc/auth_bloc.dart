import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/core/storage/secure_storage_service.dart';
import 'package:numlab_frontend/features/auth/domain/usecases/usecases.dart';
import 'package:numlab_frontend/features/auth/presentation/bloc/auth_event.dart';
import 'package:numlab_frontend/features/auth/presentation/bloc/auth_state.dart';

/// BLoC managing application-wide authentication state and token lifecycles.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required SecureStorageService secureStorageService,
    required LoginUseCase loginUseCase,
    required RegisterUseCase registerUseCase,
    required RefreshTokenUseCase refreshTokenUseCase,
    required LogoutUseCase logoutUseCase,
    required LogoutAllUseCase logoutAllUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
  }) : _secureStorageService = secureStorageService,
       _loginUseCase = loginUseCase,
       _registerUseCase = registerUseCase,
       _refreshTokenUseCase = refreshTokenUseCase,
       _logoutUseCase = logoutUseCase,
       _logoutAllUseCase = logoutAllUseCase,
       _getCurrentUserUseCase = getCurrentUserUseCase,
       super(const AuthInitial()) {
    on<AuthInitializeRequested>(_onInitializeRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthLogoutAllRequested>(_onLogoutAllRequested);
    on<AuthSessionRefreshRequested>(_onSessionRefreshRequested);
    on<AuthGetCurrentUserRequested>(_onGetCurrentUserRequested);
    on<AuthSessionRevoked>(_onSessionRevoked);
  }

  final SecureStorageService _secureStorageService;
  final LoginUseCase _loginUseCase;
  final RegisterUseCase _registerUseCase;
  final RefreshTokenUseCase _refreshTokenUseCase;
  final LogoutUseCase _logoutUseCase;
  final LogoutAllUseCase _logoutAllUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;

  Future<void> _onInitializeRequested(
    AuthInitializeRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final hasRefreshToken = await _secureStorageService.hasRefreshToken();
    if (!hasRefreshToken) {
      emit(const AuthUnauthenticated());
      return;
    }

    final userResult = await _getCurrentUserUseCase();
    await userResult.fold(
      (failure) async {
        if (failure is AuthFailure) {
          await _secureStorageService.clearTokens();
          emit(const AuthUnauthenticated());
        } else {
          emit(AuthError(failure: failure));
        }
      },
      (user) async {
        emit(AuthAuthenticated(user: user));
      },
    );
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _loginUseCase(
      email: event.email,
      password: event.password,
    );

    await result.fold(
      (failure) async {
        emit(AuthError(failure: failure));
      },
      (authResult) async {
        await _secureStorageService.saveTokens(
          accessToken: authResult.tokens.accessToken,
          refreshToken: authResult.tokens.refreshToken,
        );
        emit(AuthAuthenticated(user: authResult.user));
      },
    );
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _registerUseCase(
      email: event.email,
      password: event.password,
    );

    await result.fold(
      (failure) async {
        emit(AuthError(failure: failure));
      },
      (authResult) async {
        await _secureStorageService.saveTokens(
          accessToken: authResult.tokens.accessToken,
          refreshToken: authResult.tokens.refreshToken,
        );
        emit(AuthAuthenticated(user: authResult.user));
      },
    );
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final refreshToken = await _secureStorageService.getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _logoutUseCase(refreshToken: refreshToken);
    }

    await _secureStorageService.clearTokens();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onLogoutAllRequested(
    AuthLogoutAllRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final accessToken = await _secureStorageService.getAccessToken();
    await _logoutAllUseCase(accessToken: accessToken);

    await _secureStorageService.clearTokens();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onSessionRefreshRequested(
    AuthSessionRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final refreshToken = await _secureStorageService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _secureStorageService.clearTokens();
      emit(const AuthUnauthenticated());
      return;
    }

    final tokenResult = await _refreshTokenUseCase(
      refreshToken: refreshToken,
    );

    await tokenResult.fold(
      (failure) async {
        if (failure is AuthFailure) {
          await _secureStorageService.clearTokens();
          emit(const AuthUnauthenticated());
        } else {
          emit(AuthError(failure: failure));
        }
      },
      (token) async {
        await _secureStorageService.saveTokens(
          accessToken: token.accessToken,
          refreshToken: token.refreshToken,
        );

        final userResult = await _getCurrentUserUseCase();
        userResult.fold(
          (failure) {
            emit(AuthError(failure: failure));
          },
          (user) {
            emit(AuthAuthenticated(user: user));
          },
        );
      },
    );
  }

  Future<void> _onGetCurrentUserRequested(
    AuthGetCurrentUserRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final userResult = await _getCurrentUserUseCase();
    await userResult.fold(
      (failure) async {
        if (failure is AuthFailure) {
          await _secureStorageService.clearTokens();
          emit(const AuthUnauthenticated());
        } else {
          emit(AuthError(failure: failure));
        }
      },
      (user) async {
        emit(AuthAuthenticated(user: user));
      },
    );
  }

  Future<void> _onSessionRevoked(
    AuthSessionRevoked event,
    Emitter<AuthState> emit,
  ) async {
    await _secureStorageService.clearTokens();
    emit(const AuthUnauthenticated());
  }
}
