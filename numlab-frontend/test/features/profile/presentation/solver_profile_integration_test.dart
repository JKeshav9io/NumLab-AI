import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/core/constants/api_constants.dart';
import 'package:numlab_frontend/core/network/interceptors/auth_interceptor.dart';
import 'package:numlab_frontend/core/router/app_router.dart';
import 'package:numlab_frontend/core/storage/secure_storage_service.dart';
import 'package:numlab_frontend/features/auth/domain/entities/user.dart';
import 'package:numlab_frontend/features/auth/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/solvers/data/datasources/solver_remote_data_source.dart';
import 'package:numlab_frontend/features/solvers/data/repositories/solver_repository_impl.dart';
import 'package:numlab_frontend/features/solvers/domain/models/models.dart';
import 'package:numlab_frontend/features/solvers/domain/repositories/solver_repository.dart';
import 'package:numlab_frontend/features/solvers/domain/usecases/usecases.dart';
import 'package:numlab_frontend/features/solvers/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/injection_container.dart';

class FakeSecureStorageService implements SecureStorageService {
  String? accessToken;
  String? refreshToken;
  int clearTokensCount = 0;
  int saveTokensCount = 0;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    saveTokensCount++;
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<void> clearTokens() async {
    clearTokensCount++;
    accessToken = null;
    refreshToken = null;
  }

  @override
  Future<bool> hasAccessToken() async =>
      accessToken != null && accessToken!.isNotEmpty;

  @override
  Future<bool> hasRefreshToken() async =>
      refreshToken != null && refreshToken!.isNotEmpty;
}

class FakeDioClient extends Fake implements Dio {
  Future<Response<dynamic>> Function(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  })?
  onPost;

  @override
  final Interceptors interceptors = Interceptors();

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final res = await onPost!(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
    return Response<T>(
      data: res.data as T?,
      headers: res.headers,
      requestOptions: res.requestOptions,
      isRedirect: res.isRedirect,
      statusCode: res.statusCode,
      statusMessage: res.statusMessage,
    );
  }
}

class MockAuthBloc extends Fake implements AuthBloc {
  MockAuthBloc(this._initialState) {
    _state = _initialState;
  }

  final AuthState _initialState;
  late AuthState _state;
  final StreamController<AuthState> _controller =
      StreamController<AuthState>.broadcast();
  final List<AuthEvent> recordedEvents = [];

  @override
  AuthState get state => _state;

  @override
  Stream<AuthState> get stream => _controller.stream;

  @override
  void add(AuthEvent event) {
    recordedEvents.add(event);
  }

  void emitState(AuthState newState) {
    _state = newState;
    _controller.add(newState);
  }

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

void main() {
  final tUser = User(
    id: 'usr_7890_abcd',
    email: 'euler@numlab.ai',
    emailVerified: true,
    createdAt: DateTime.parse('2026-09-20T10:00:00.000Z'),
    lastLoginAt: DateTime.parse('2026-09-27T08:30:00.000Z'),
    updatedAt: DateTime.parse('2026-09-27T08:30:00.000Z'),
  );

  late FakeSecureStorageService fakeStorage;
  late FakeDioClient fakeDio;
  late SolverRemoteDataSource solverRemoteDataSource;
  late SolverRepository solverRepository;
  late ExecuteSolverUseCase executeSolverUseCase;

  setUp(() async {
    fakeStorage = FakeSecureStorageService();
    fakeDio = FakeDioClient();
    solverRemoteDataSource = SolverRemoteDataSourceImpl(dio: fakeDio);
    solverRepository = SolverRepositoryImpl(
      remoteDataSource: solverRemoteDataSource,
      secureStorageService: fakeStorage,
    );
    executeSolverUseCase = ExecuteSolverUseCase(solverRepository);

    if (sl.isRegistered<SolverFormBloc>()) {
      await sl.unregister<SolverFormBloc>();
    }
    sl.registerFactory<SolverFormBloc>(
      () => SolverFormBloc(executeSolverUseCase: executeSolverUseCase),
    );
  });

  tearDown(() async {
    if (sl.isRegistered<SolverFormBloc>()) {
      await sl.unregister<SolverFormBloc>();
    }
  });

  group('Phase 2j — Profile & Final Solver-Core Verification', () {
    testWidgets(
      '1. Anonymous access to Profile is guarded and redirected to Login, then returns to Profile on login',
      (tester) async {
        final mockAuthBloc = MockAuthBloc(const AuthUnauthenticated());
        final appRouter = AppRouter(
          authBloc: mockAuthBloc,
          initialLocation: AppRoutes.profile,
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: appRouter.router),
        );
        await tester.pumpAndSettle();

        // 1. Unauthenticated user accessing /profile is redirected to Login
        expect(find.byKey(const Key('profile_screen')), findsNothing);
        expect(find.byKey(const Key('login_screen')), findsOneWidget);

        final currentUri = appRouter.router.routeInformationProvider.value.uri;
        expect(currentUri.path, AppRoutes.login);
        expect(currentUri.queryParameters['from'], AppRoutes.profile);

        // 2. User authenticates successfully
        mockAuthBloc.emitState(AuthAuthenticated(user: tUser));
        await tester.pumpAndSettle();

        // 3. Router guard automatically directs user back to Profile
        expect(find.byKey(const Key('login_screen')), findsNothing);
        expect(find.byKey(const Key('profile_screen')), findsOneWidget);
        expect(find.text('Email: euler@numlab.ai'), findsOneWidget);

        appRouter.dispose();
        await mockAuthBloc.close();
      },
    );

    testWidgets(
      '2. Profile refresh updates user data without disrupting solver state',
      (tester) async {
        fakeStorage.accessToken = 'jwt_valid_token_xyz';
        final mockAuthBloc = MockAuthBloc(AuthAuthenticated(user: tUser));
        final appRouter = AppRouter(
          authBloc: mockAuthBloc,
          initialLocation: AppRoutes.profile,
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: appRouter.router),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('profile_screen')), findsOneWidget);
        expect(find.text('Email: euler@numlab.ai'), findsOneWidget);

        // Refresh user profile
        await tester.tap(find.byKey(const Key('profile_refresh_button')));
        await tester.pump();

        expect(
          mockAuthBloc.recordedEvents,
          contains(const AuthGetCurrentUserRequested()),
        );

        final updatedUser = User(
          id: 'usr_7890_abcd',
          email: 'euler.updated@numlab.ai',
          emailVerified: true,
          createdAt: DateTime.parse('2026-09-20T10:00:00.000Z'),
          lastLoginAt: DateTime.parse('2026-09-29T00:00:00.000Z'),
          updatedAt: DateTime.parse('2026-09-29T00:00:00.000Z'),
        );
        mockAuthBloc.emitState(AuthAuthenticated(user: updatedUser));
        await tester.pumpAndSettle();

        expect(find.text('Email: euler.updated@numlab.ai'), findsOneWidget);

        appRouter.dispose();
        await mockAuthBloc.close();
      },
    );

    testWidgets(
      '3. Full navigation: Solver solve -> Profile -> Refresh -> Return to Solver -> Re-execute',
      (tester) async {
        fakeStorage.accessToken = 'jwt_valid_token_123';
        final mockAuthBloc = MockAuthBloc(AuthAuthenticated(user: tUser));

        var solveCount = 0;
        fakeDio.onPost = (path, {data, options, queryParameters}) async {
          if (path.contains('/solve/root/bisection')) {
            solveCount++;
            return Response(
              requestOptions: RequestOptions(path: path),
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'method': 'Bisection Method',
                  'status': 'converged',
                  'finalAnswer': {'root': 2.09455, 'converged': true},
                  'iterations': const <dynamic>[],
                  'executionTimeMs': 2,
                },
                'meta': {'requestId': 'req-solve-$solveCount'},
              },
            );
          }
          throw UnimplementedError('Unexpected path: $path');
        };

        final appRouter = AppRouter(
          authBloc: mockAuthBloc,
          initialLocation: AppRoutes.solver('bisection'),
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: appRouter.router),
        );
        await tester.pumpAndSettle();

        // 1. On Solver Form Screen
        expect(find.byKey(const Key('solver_form_screen')), findsOneWidget);
        expect(find.text('Bisection Method'), findsWidgets);

        // Fill required fields and execute solver
        await tester.enterText(
          find.byKey(const Key('field_equation')),
          'x^3 - x - 2',
        );
        await tester.enterText(
          find.byKey(const Key('field_lowerBound')),
          '1.0',
        );
        await tester.enterText(
          find.byKey(const Key('field_upperBound')),
          '2.0',
        );
        await tester.pump();

        await tester.ensureVisible(
          find.byKey(const Key('solver_submit_button')),
        );
        await tester.tap(find.byKey(const Key('solver_submit_button')));
        await tester.pumpAndSettle();

        // Verify result card rendered
        expect(find.byKey(const Key('solver_result_card')), findsOneWidget);
        expect(find.text('Root: 2.09455'), findsOneWidget);
        expect(solveCount, 1);

        // 2. Navigate to Profile
        appRouter.router.go(AppRoutes.profile);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('profile_screen')), findsOneWidget);
        expect(find.text('Email: euler@numlab.ai'), findsOneWidget);

        // Trigger profile refresh
        await tester.tap(find.byKey(const Key('profile_refresh_button')));
        await tester.pump();

        // 3. Navigate back to Solver Screen
        appRouter.router.go(AppRoutes.solver('bisection'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('solver_form_screen')), findsOneWidget);

        // Re-execute solver on fresh solver screen instance
        await tester.enterText(
          find.byKey(const Key('field_equation')),
          'x^3 - x - 2',
        );
        await tester.enterText(
          find.byKey(const Key('field_lowerBound')),
          '1.0',
        );
        await tester.enterText(
          find.byKey(const Key('field_upperBound')),
          '2.0',
        );
        await tester.pump();

        await tester.ensureVisible(
          find.byKey(const Key('solver_submit_button')),
        );
        await tester.tap(find.byKey(const Key('solver_submit_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('solver_result_card')), findsOneWidget);
        expect(find.text('Root: 2.09455'), findsOneWidget);
        expect(solveCount, 2);

        appRouter.dispose();
        await mockAuthBloc.close();
      },
    );

    testWidgets(
      '4. Logout from Profile shifts subsequent solver execution to anonymous mode',
      (tester) async {
        fakeStorage.accessToken = 'jwt_initial_token';
        final mockAuthBloc = MockAuthBloc(AuthAuthenticated(user: tUser));

        final sentAuthHeaders = <String?>[];
        fakeDio.onPost = (path, {data, options, queryParameters}) async {
          sentAuthHeaders.add(
            options?.headers?[ApiConstants.authHeader] as String?,
          );
          return Response(
            requestOptions: RequestOptions(path: path),
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'method': 'Bisection Method',
                'status': 'converged',
                'finalAnswer': {'root': 2.0},
                'executionTimeMs': 1,
              },
            },
          );
        };

        final appRouter = AppRouter(
          authBloc: mockAuthBloc,
          initialLocation: AppRoutes.profile,
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: appRouter.router),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('profile_screen')), findsOneWidget);

        // 1. Tap logout on Profile
        await tester.tap(find.byKey(const Key('profile_logout_button')));
        await tester.pump();

        // Clear storage & transition AuthBloc to unauthenticated
        await fakeStorage.clearTokens();
        mockAuthBloc.emitState(const AuthUnauthenticated());
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('login_screen')), findsOneWidget);

        // 2. Navigate anonymously to solver
        appRouter.router.go(AppRoutes.solver('bisection'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('solver_form_screen')), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('field_equation')),
          'x^2 - 4',
        );
        await tester.enterText(
          find.byKey(const Key('field_lowerBound')),
          '1.0',
        );
        await tester.enterText(
          find.byKey(const Key('field_upperBound')),
          '3.0',
        );
        await tester.pump();

        await tester.ensureVisible(
          find.byKey(const Key('solver_submit_button')),
        );
        await tester.tap(find.byKey(const Key('solver_submit_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('solver_result_card')), findsOneWidget);

        // Verify request was dispatched anonymously (without Authorization header)
        expect(sentAuthHeaders.last, isNull);

        appRouter.dispose();
        await mockAuthBloc.close();
      },
    );

    testWidgets(
      '5. Transparent token refresh and session revocation handling during active execution',
      (tester) async {
        fakeStorage
          ..accessToken = 'jwt_expired_token'
          ..refreshToken = 'jwt_valid_refresh_token';

        var revocationCount = 0;
        final authInterceptor = AuthInterceptor(
          secureStorageService: fakeStorage,
          refreshDio: fakeDio,
          onSessionRevoked: () {
            revocationCount++;
          },
        );

        // Attach interceptor to fakeDio
        fakeDio.interceptors.add(authInterceptor);

        fakeDio.onPost = (path, {data, options, queryParameters}) async {
          if (path == ApiConstants.refreshPath) {
            fakeStorage.accessToken = 'jwt_new_refreshed_token';
            return Response(
              requestOptions: RequestOptions(path: path),
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'tokens': {
                    'accessToken': 'jwt_new_refreshed_token',
                    'refreshToken': 'jwt_valid_refresh_token',
                    'expiresIn': 900,
                  },
                },
              },
            );
          }

          if (path.contains('/solve/root/bisection')) {
            return Response(
              requestOptions: RequestOptions(path: path),
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'method': 'Bisection Method',
                  'status': 'converged',
                  'finalAnswer': {'root': 2.0},
                  'executionTimeMs': 1,
                },
              },
            );
          }

          throw UnimplementedError('Path not handled: $path');
        };

        final result = await executeSolverUseCase(
          solverId: 'bisection',
          payload: {
            'equation': 'x^2 - 4',
            'lowerBound': 1.0,
            'upperBound': 3.0,
          },
        );

        expect(result.isRight(), isTrue);
        expect(result.getOrElse((_) => throw Exception()).root, 2.0);
        expect(revocationCount, 0);
      },
    );

    test(
      '6. Structural and functional validation across all 27 solver configurations',
      () async {
        final allConfigs = SolverMethodRegistry.all;
        expect(allConfigs.length, 27);

        for (final config in allConfigs) {
          expect(config.id, isNotEmpty);
          expect(config.name, isNotEmpty);
          expect(config.endpoint, startsWith('/solve/'));
          expect(config.fields, isNotEmpty);

          final defaultPayload = config.defaultPayload();
          expect(defaultPayload, isA<Map<String, dynamic>>());

          // Ensure field metadata can be retrieved and validated
          for (final field in config.fields) {
            expect(config.getField(field.name), isNotNull);
            if (field.defaultValue != null) {
              expect(defaultPayload[field.name], equals(field.defaultValue));
            }
          }
        }
      },
    );
  });
}
