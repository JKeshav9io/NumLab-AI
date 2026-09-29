import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/core/constants/api_constants.dart';
import 'package:numlab_frontend/core/network/interceptors/auth_interceptor.dart';
import 'package:numlab_frontend/core/router/app_router.dart';
import 'package:numlab_frontend/core/storage/secure_storage_service.dart';
import 'package:numlab_frontend/features/auth/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/solvers/data/datasources/solver_remote_data_source.dart';
import 'package:numlab_frontend/features/solvers/data/repositories/solver_repository_impl.dart';
import 'package:numlab_frontend/features/solvers/domain/models/models.dart';
import 'package:numlab_frontend/features/solvers/domain/repositories/solver_repository.dart';
import 'package:numlab_frontend/features/solvers/domain/usecases/usecases.dart';
import 'package:numlab_frontend/features/solvers/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/solvers/presentation/screens/screens.dart';
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
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  })?
  onPost;

  Future<Response<dynamic>> Function(RequestOptions options)? onFetch;

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
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
    return Response<T>(
      data: res.data as T?,
      headers: res.headers,
      requestOptions: res.requestOptions,
      isRedirect: res.isRedirect,
      statusCode: res.statusCode,
      statusMessage: res.statusMessage,
      redirects: res.redirects,
      extra: res.extra,
    );
  }

  @override
  Future<Response<T>> fetch<T>(RequestOptions requestOptions) async {
    final res = await onFetch!(requestOptions);
    return Response<T>(
      data: res.data as T?,
      headers: res.headers,
      requestOptions: res.requestOptions,
      isRedirect: res.isRedirect,
      statusCode: res.statusCode,
      statusMessage: res.statusMessage,
      redirects: res.redirects,
      extra: res.extra,
    );
  }
}

class TestErrorHandler extends ErrorInterceptorHandler {
  DioException? nextError;
  Response<dynamic>? resolvedResponse;
  DioException? rejectedError;

  @override
  void next(DioException err) {
    nextError = err;
  }

  @override
  void resolve(Response<dynamic> response) {
    resolvedResponse = response;
  }

  @override
  void reject(
    DioException err, [
    bool callFollowingErrorInterceptor = false,
  ]) {
    rejectedError = err;
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

  @override
  AuthState get state => _state;

  @override
  Stream<AuthState> get stream => _controller.stream;

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

void main() {
  group('Phase 2h — Anonymous vs Authenticated Solver Execution', () {
    late FakeSecureStorageService storage;
    late FakeDioClient fakeDio;
    late SolverRemoteDataSource remoteDataSource;
    late SolverRepository solverRepository;
    late ExecuteSolverUseCase executeSolverUseCase;

    setUp(() async {
      storage = FakeSecureStorageService();
      fakeDio = FakeDioClient();
      remoteDataSource = SolverRemoteDataSourceImpl(dio: fakeDio);
      solverRepository = SolverRepositoryImpl(
        remoteDataSource: remoteDataSource,
        secureStorageService: storage,
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

    test(
      '1. Anonymous solver execution: sends request with no Authorization header and renders result',
      () async {
        storage
          ..accessToken = null
          ..refreshToken = null;

        Options? capturedOptions;
        fakeDio.onPost =
            (
              path, {
              data,
              options,
              cancelToken,
              onReceiveProgress,
              onSendProgress,
              queryParameters,
            }) async {
              capturedOptions = options;
              return Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: path),
                statusCode: 200,
                data: const {
                  'success': true,
                  'data': {
                    'method': 'Bisection Method',
                    'status': 'converged',
                    'input': {
                      'equation': 'x^2 - 4',
                      'lowerBound': 0,
                      'upperBound': 3,
                    },
                    'finalAnswer': {'root': 2.0, 'converged': true},
                  },
                },
              );
            };

        final bloc = SolverFormBloc(executeSolverUseCase: executeSolverUseCase)
          ..add(const SolverFormLoadStarted(solverId: 'bisection'));
        await pumpEventQueue();

        bloc
          ..add(
            const SolverFormFieldChanged(
              fieldName: 'equation',
              value: 'x^2 - 4',
            ),
          )
          ..add(
            const SolverFormFieldChanged(fieldName: 'lowerBound', value: 0.0),
          )
          ..add(
            const SolverFormFieldChanged(fieldName: 'upperBound', value: 3.0),
          )
          ..add(
            const SolverFormFieldChanged(
              fieldName: 'tolerance',
              value: 0.0001,
            ),
          )
          ..add(
            const SolverFormFieldChanged(
              fieldName: 'maxIterations',
              value: 100,
            ),
          )
          ..add(const SolverFormSubmitted());
        await pumpEventQueue();

        expect(bloc.state.status, SolverFormStatus.success);
        expect(bloc.state.result?.root, 2.0);
        expect(capturedOptions?.headers?[ApiConstants.authHeader], isNull);

        await bloc.close();
      },
    );

    test(
      '2. Authenticated solver execution: automatically injects Authorization Bearer token',
      () async {
        storage
          ..accessToken = 'jwt_access_token_xyz'
          ..refreshToken = 'jwt_refresh_token_abc';

        Options? capturedOptions;
        fakeDio.onPost =
            (
              path, {
              data,
              options,
              cancelToken,
              onReceiveProgress,
              onSendProgress,
              queryParameters,
            }) async {
              capturedOptions = options;
              return Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: path),
                statusCode: 200,
                data: const {
                  'success': true,
                  'data': {
                    'method': 'Bisection Method',
                    'status': 'converged',
                    'finalAnswer': {'root': 2.0},
                  },
                },
              );
            };

        final bloc = SolverFormBloc(executeSolverUseCase: executeSolverUseCase)
          ..add(const SolverFormLoadStarted(solverId: 'bisection'));
        await pumpEventQueue();

        bloc
          ..add(
            const SolverFormFieldChanged(
              fieldName: 'equation',
              value: 'x^2 - 4',
            ),
          )
          ..add(
            const SolverFormFieldChanged(fieldName: 'lowerBound', value: 0.0),
          )
          ..add(
            const SolverFormFieldChanged(fieldName: 'upperBound', value: 3.0),
          )
          ..add(
            const SolverFormFieldChanged(
              fieldName: 'tolerance',
              value: 0.0001,
            ),
          )
          ..add(
            const SolverFormFieldChanged(
              fieldName: 'maxIterations',
              value: 100,
            ),
          )
          ..add(const SolverFormSubmitted());
        await pumpEventQueue();

        expect(bloc.state.status, SolverFormStatus.success);
        expect(
          capturedOptions?.headers?[ApiConstants.authHeader],
          'Bearer jwt_access_token_xyz',
        );

        await bloc.close();
      },
    );

    test(
      '3. Missing token in storage: falls back seamlessly to anonymous solve',
      () async {
        storage.accessToken = '';

        Options? capturedOptions;
        fakeDio.onPost =
            (
              path, {
              data,
              options,
              cancelToken,
              onReceiveProgress,
              onSendProgress,
              queryParameters,
            }) async {
              capturedOptions = options;
              return Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: path),
                statusCode: 200,
                data: const {
                  'success': true,
                  'data': {
                    'method': 'Bisection Method',
                    'finalAnswer': {'root': 2.0},
                  },
                },
              );
            };

        final result = await solverRepository.solve(
          config: SolverMethodRegistry.bisection,
          payload: const {
            'equation': 'x^2 - 4',
            'lowerBound': 0,
            'upperBound': 3,
          },
        );

        expect(result.isRight(), isTrue);
        expect(capturedOptions?.headers?[ApiConstants.authHeader], isNull);
      },
    );

    test(
      '4. Access-token refresh during solver execution: handles 401 TOKEN_EXPIRED and retries successfully',
      () async {
        storage
          ..accessToken = 'expired_access_token_123'
          ..refreshToken = 'valid_refresh_token_456';

        final fakeRefreshDio = FakeDioClient();
        final fakeRetryDio = FakeDioClient();

        var refreshCalled = false;
        fakeRefreshDio.onPost =
            (
              path, {
              data,
              options,
              cancelToken,
              onReceiveProgress,
              onSendProgress,
              queryParameters,
            }) async {
              expect(path, ApiConstants.refreshPath);
              if (data is Map<String, dynamic>) {
                expect(data['refreshToken'], 'valid_refresh_token_456');
              }
              refreshCalled = true;

              return Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: path),
                statusCode: 200,
                data: const {
                  'success': true,
                  'data': {
                    'tokens': {
                      'accessToken': 'fresh_access_token_789',
                      'refreshToken': 'fresh_refresh_token_999',
                      'expiresIn': 900,
                    },
                  },
                },
              );
            };

        var retriedWithToken = '';
        fakeRetryDio.onFetch = (requestOptions) async {
          retriedWithToken =
              requestOptions.headers[ApiConstants.authHeader] as String? ?? '';
          return Response<Map<String, dynamic>>(
            requestOptions: requestOptions,
            statusCode: 200,
            data: const {
              'success': true,
              'data': {
                'method': 'Bisection Method',
                'finalAnswer': {'root': 2.0},
              },
            },
          );
        };

        final interceptor = AuthInterceptor(
          secureStorageService: storage,
          refreshDio: fakeRefreshDio,
          retryDio: fakeRetryDio,
        );

        final expiredError = DioException(
          requestOptions: RequestOptions(
            path: '/solve/root/bisection',
            headers: <String, dynamic>{
              ApiConstants.authHeader: 'Bearer expired_access_token_123',
            },
          ),
          response: Response(
            statusCode: 401,
            requestOptions: RequestOptions(path: '/solve/root/bisection'),
            data: const <String, dynamic>{
              'success': false,
              'error': <String, dynamic>{
                'code': 'TOKEN_EXPIRED',
                'message': 'Access token has expired',
              },
            },
          ),
        );

        final handler = TestErrorHandler();
        await interceptor.onError(expiredError, handler);

        expect(refreshCalled, isTrue);
        expect(retriedWithToken, 'Bearer fresh_access_token_789');
        expect(storage.accessToken, 'fresh_access_token_789');
        expect(storage.refreshToken, 'fresh_refresh_token_999');
        expect(handler.resolvedResponse?.statusCode, 200);
      },
    );

    test(
      '5. Revoked / invalid session during solver execution: clears tokens, notifies onSessionRevoked, and returns AuthFailure',
      () async {
        storage
          ..accessToken = 'expired_access_token'
          ..refreshToken = 'revoked_refresh_token';

        var sessionRevokedNotified = false;

        final fakeRefreshDio = FakeDioClient()
          ..onPost =
              (
                path, {
                data,
                options,
                cancelToken,
                onReceiveProgress,
                onSendProgress,
                queryParameters,
              }) async {
                throw DioException(
                  requestOptions: RequestOptions(path: path),
                  response: Response(
                    requestOptions: RequestOptions(path: path),
                    statusCode: 401,
                    data: const {
                      'success': false,
                      'error': {
                        'code': 'TOKEN_REVOKED',
                        'message': 'Refresh token has been revoked',
                      },
                    },
                  ),
                  type: DioExceptionType.badResponse,
                );
              };

        final interceptor = AuthInterceptor(
          secureStorageService: storage,
          refreshDio: fakeRefreshDio,
          retryDio: fakeDio,
          onSessionRevoked: () {
            sessionRevokedNotified = true;
          },
        );

        final expiredError = DioException(
          requestOptions: RequestOptions(
            path: '/solve/root/bisection',
            headers: <String, dynamic>{
              ApiConstants.authHeader: 'Bearer expired_access_token',
            },
          ),
          response: Response(
            statusCode: 401,
            requestOptions: RequestOptions(path: '/solve/root/bisection'),
            data: const <String, dynamic>{
              'success': false,
              'error': <String, dynamic>{
                'code': 'TOKEN_EXPIRED',
                'message': 'Access token has expired',
              },
            },
          ),
        );

        final handler = TestErrorHandler();
        await interceptor.onError(expiredError, handler);

        expect(sessionRevokedNotified, isTrue);
        expect(storage.accessToken, isNull);
        expect(storage.refreshToken, isNull);
        expect(handler.nextError, expiredError);
      },
    );

    test(
      '6. Logout transition: solver execution shifts from authenticated to anonymous',
      () async {
        storage
          ..accessToken = 'authenticated_token_111'
          ..refreshToken = 'refresh_token_111';

        final headersUsed = <String?>[];
        fakeDio.onPost =
            (
              path, {
              data,
              options,
              cancelToken,
              onReceiveProgress,
              onSendProgress,
              queryParameters,
            }) async {
              headersUsed.add(
                options?.headers?[ApiConstants.authHeader] as String?,
              );
              return Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: path),
                statusCode: 200,
                data: const {
                  'success': true,
                  'data': {'method': 'Bisection Method'},
                },
              );
            };

        // 1st Solve while logged in
        await solverRepository.solve(
          config: SolverMethodRegistry.bisection,
          payload: const {'equation': 'x^2 - 4'},
        );
        expect(headersUsed.last, 'Bearer authenticated_token_111');

        // User logs out
        await storage.clearTokens();

        // 2nd Solve after logout
        await solverRepository.solve(
          config: SolverMethodRegistry.bisection,
          payload: const {'equation': 'x^2 - 4'},
        );
        expect(headersUsed.last, isNull);
      },
    );

    test(
      '7. Login transition: solver execution shifts from anonymous to authenticated',
      () async {
        storage
          ..accessToken = null
          ..refreshToken = null;

        final headersUsed = <String?>[];
        fakeDio.onPost =
            (
              path, {
              data,
              options,
              cancelToken,
              onReceiveProgress,
              onSendProgress,
              queryParameters,
            }) async {
              headersUsed.add(
                options?.headers?[ApiConstants.authHeader] as String?,
              );
              return Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: path),
                statusCode: 200,
                data: const {
                  'success': true,
                  'data': {'method': 'Bisection Method'},
                },
              );
            };

        // 1st Solve as guest
        await solverRepository.solve(
          config: SolverMethodRegistry.bisection,
          payload: const {'equation': 'x^2 - 4'},
        );
        expect(headersUsed.last, isNull);

        // User logs in
        await storage.saveTokens(
          accessToken: 'new_login_access_token',
          refreshToken: 'new_login_refresh_token',
        );

        // 2nd Solve after login
        await solverRepository.solve(
          config: SolverMethodRegistry.bisection,
          payload: const {'equation': 'x^2 - 4'},
        );
        expect(headersUsed.last, 'Bearer new_login_access_token');
      },
    );

    test(
      '8. Representative solvers across categories execute seamlessly in both anonymous and authenticated modes',
      () async {
        final configs = [
          SolverMethodRegistry.bisection, // Root Finding
          SolverMethodRegistry.jacobi, // Linear Systems
          SolverMethodRegistry.lagrangeInterpolation, // Interpolation
          SolverMethodRegistry.simpson13, // Numerical Integration
          SolverMethodRegistry.euler, // Differential Equations
        ];

        final payloads = <String, Map<String, dynamic>>{
          'bisection': {
            'equation': 'x^2 - 4',
            'lowerBound': 0,
            'upperBound': 3,
            'tolerance': 0.0001,
            'maxIterations': 100,
          },
          'jacobi': {
            'matrix': [
              [4.0, 1.0],
              [1.0, 3.0],
            ],
            'constants': [1.0, 2.0],
          },
          'lagrange_interpolation': {
            'points': [
              {'x': 1.0, 'y': 2.0},
              {'x': 2.0, 'y': 4.0},
            ],
            'targetX': 1.5,
          },
          'simpson_1_3': {
            'equation': 'x^2',
            'lowerBound': 0.0,
            'upperBound': 1.0,
            'subintervals': 4,
          },
          'euler': {
            'differentialEquation': 'x + y',
            'x0': 0.0,
            'y0': 1.0,
            'targetX': 1.0,
            'stepSize': 0.1,
          },
        };

        for (final config in configs) {
          // A) Test Anonymous
          storage.accessToken = null;
          Options? anonOptions;
          fakeDio.onPost =
              (
                path, {
                data,
                options,
                cancelToken,
                onReceiveProgress,
                onSendProgress,
                queryParameters,
              }) async {
                anonOptions = options;
                return Response<Map<String, dynamic>>(
                  requestOptions: RequestOptions(path: path),
                  statusCode: 200,
                  data: {
                    'success': true,
                    'data': {'method': config.name},
                  },
                );
              };

          final anonResult = await solverRepository.solve(
            config: config,
            payload: payloads[config.id] ?? {},
          );
          expect(
            anonResult.isRight(),
            isTrue,
            reason: '${config.name} anon execution failed',
          );
          expect(anonOptions?.headers?[ApiConstants.authHeader], isNull);

          // B) Test Authenticated
          storage.accessToken = 'bearer_token_for_${config.id}';
          Options? authOptions;
          fakeDio.onPost =
              (
                path, {
                data,
                options,
                cancelToken,
                onReceiveProgress,
                onSendProgress,
                queryParameters,
              }) async {
                authOptions = options;
                return Response<Map<String, dynamic>>(
                  requestOptions: RequestOptions(path: path),
                  statusCode: 200,
                  data: {
                    'success': true,
                    'data': {'method': config.name},
                  },
                );
              };

          final authResult = await solverRepository.solve(
            config: config,
            payload: payloads[config.id] ?? {},
          );
          expect(
            authResult.isRight(),
            isTrue,
            reason: '${config.name} auth execution failed',
          );
          expect(
            authOptions?.headers?[ApiConstants.authHeader],
            'Bearer bearer_token_for_${config.id}',
          );
        }
      },
    );

    testWidgets(
      '9. Anonymous user remains on solver flow without login redirect and can execute solver',
      (tester) async {
        final mockAuthBloc = MockAuthBloc(const AuthUnauthenticated());

        final router = AppRouter(
          authBloc: mockAuthBloc,
          initialLocation: '/solver/bisection',
        );

        fakeDio.onPost =
            (
              path, {
              data,
              options,
              cancelToken,
              onReceiveProgress,
              onSendProgress,
              queryParameters,
            }) async {
              return Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: path),
                statusCode: 200,
                data: const {
                  'success': true,
                  'data': {
                    'method': 'Bisection Method',
                    'status': 'converged',
                    'input': {
                      'equation': 'x^2 - 4',
                      'lowerBound': 0,
                      'upperBound': 3,
                    },
                    'finalAnswer': {'root': 2.0},
                  },
                },
              );
            };

        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router.router,
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify user is on solver workspace screen and NOT redirected to login
        expect(find.byType(SolverWorkspaceScreen), findsOneWidget);
        expect(find.byKey(const Key('login_screen')), findsNothing);
        expect(find.text('Bisection Method'), findsWidgets);

        // 2. Fill required fields
        await tester.enterText(
          find.byKey(const Key('field_equation')),
          'x^2 - 4',
        );
        await tester.enterText(find.byKey(const Key('field_lowerBound')), '0');
        await tester.enterText(find.byKey(const Key('field_upperBound')), '3');
        await tester.pump();

        // 3. Submit form as anonymous user
        await tester.ensureVisible(
          find.byKey(const Key('solver_submit_button')),
        );
        await tester.tap(find.byKey(const Key('solver_submit_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // 4. Calculation result rendered successfully on solver screen
        expect(find.byKey(const Key('solver_result_card')), findsOneWidget);
        expect(find.text('Root: 2.0'), findsOneWidget);

        router.dispose();
        await mockAuthBloc.close();
      },
    );
  });
}
