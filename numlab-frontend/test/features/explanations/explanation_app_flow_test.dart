import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/app.dart';
import 'package:numlab_frontend/core/constants/api_constants.dart';
import 'package:numlab_frontend/core/network/dio_client.dart';
import 'package:numlab_frontend/core/router/app_router.dart';
import 'package:numlab_frontend/core/storage/secure_storage_service.dart';
import 'package:numlab_frontend/features/auth/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/injection_container.dart';

class FlowStorage implements SecureStorageService {
  String? access;
  String? refresh;
  @override
  Future<String?> getAccessToken() async => access;
  @override
  Future<String?> getRefreshToken() async => refresh;
  @override
  Future<bool> hasAccessToken() async => access != null;
  @override
  Future<bool> hasRefreshToken() async => refresh != null;
  @override
  Future<void> clearTokens() async {
    access = null;
    refresh = null;
  }

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    access = accessToken;
    refresh = refreshToken;
  }
}

typedef PendingExplanation = ({
  RequestOptions options,
  RequestInterceptorHandler handler,
});

class FlowTransport {
  final requests = <RequestOptions>[];
  final pending = <PendingExplanation>[];
  static const user = <String, dynamic>{
    'id': 'flow-user',
    'email': 'flow@example.com',
    'emailVerified': true,
    'createdAt': '2026-10-27T00:00:00.000Z',
  };

  List<RequestOptions> get explanations =>
      requests.where((r) => r.path == ApiConstants.explainPath).toList();

  void handle(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add(options);
    if (options.path == ApiConstants.explainPath) {
      pending.add((options: options, handler: handler));
      return;
    }
    final Object data;
    if (options.path.startsWith('/solve/')) {
      data = <String, dynamic>{
        'method': 'Bisection Method',
        'status': 'converged',
        'input': options.data,
        'finalAnswer': {'root': 2.0, 'converged': true},
        'iterations': <Object?>[],
        'warnings': <String>[],
        'executionTimeMs': 1,
      };
    } else if (options.path == ApiConstants.loginPath) {
      data = <String, dynamic>{'user': user, 'tokens': tokens(rotated: false)};
    } else if (options.path == ApiConstants.refreshPath) {
      data = <String, dynamic>{'tokens': tokens(rotated: true)};
    } else if (options.path == ApiConstants.historyPath) {
      data = <String, dynamic>{
        'runs': <Object?>[],
        'pagination': {'total': 0, 'limit': 20, 'offset': 0, 'hasMore': false},
      };
    } else {
      data = user;
    }
    handler.resolve(
      Response<Map<String, dynamic>>(
        requestOptions: options,
        statusCode: 200,
        data: {'success': true, 'data': data},
      ),
      true,
    );
  }

  Map<String, dynamic> tokens({required bool rotated}) => {
    'accessToken': rotated ? 'rotated-access' : 'flow-access',
    'refreshToken': rotated ? 'rotated-refresh' : 'flow-refresh',
    'expiresIn': 900,
  };

  void succeed({
    bool cached = false,
    String text = 'A **verified** explanation.',
  }) {
    raw({
      'success': true,
      'data': {
        'explanation': text,
        'cached': cached,
        'focus': 'steps',
        'model': cached ? 'cached' : 'flow-model',
      },
    });
  }

  void raw(Object? body) {
    final request = pending.removeAt(0);
    request.handler.resolve(
      Response<dynamic>(
        requestOptions: request.options,
        statusCode: 200,
        data: body,
      ),
      true,
    );
  }

  void fail({
    int? status,
    DioExceptionType type = DioExceptionType.badResponse,
    String code = 'AI_SERVICE_ERROR',
    String message = 'Provider failed',
  }) {
    final request = pending.removeAt(0);
    request.handler.reject(
      DioException(
        requestOptions: request.options,
        type: type,
        response: status == null
            ? null
            : Response<Map<String, dynamic>>(
                requestOptions: request.options,
                statusCode: status,
                data: {
                  'success': false,
                  'error': {
                    'code': code,
                    'message': message,
                    if (status == 429) 'details': {'retryAfterSeconds': 45},
                  },
                },
              ),
      ),
      true,
    );
  }
}

void main() {
  late FlowStorage storage;
  late FlowTransport transport;
  late Dio dio;
  late Dio refreshDio;

  Future<void> flush(WidgetTester tester) async {
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  Future<void> boot(WidgetTester tester) async {
    await initDependencies();
    storage = FlowStorage();
    transport = FlowTransport();
    refreshDio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'));
    refreshDio.interceptors.add(
      InterceptorsWrapper(onRequest: transport.handle),
    );
    dio = DioClient.create(
      secureStorageService: storage,
      baseUrl: 'http://localhost/api/v1',
      refreshDio: refreshDio,
    );
    dio.interceptors.add(InterceptorsWrapper(onRequest: transport.handle));
    await sl.unregister<SecureStorageService>();
    sl.registerSingleton<SecureStorageService>(storage);
    await sl.unregister<Dio>();
    sl.registerSingleton<Dio>(dio);
    sl<AuthBloc>().add(const AuthInitializeRequested());
    await tester.pumpWidget(const NumLabApp());
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await flush(tester);
  }

  Future<void> solve(WidgetTester tester) async {
    sl<AppRouter>().router.go(AppRoutes.workspace('root-finding', 'bisection'));
    await tester.pumpAndSettle();
    for (final entry in {
      'equation': 'x^2 - 4',
      'lowerBound': '0',
      'upperBound': '3',
    }.entries) {
      final finder = find.byKey(Key('field_${entry.key}'));
      await tester.ensureVisible(finder);
      await tester.enterText(finder, entry.value);
    }
    await tester.pumpAndSettle();
    await tap(tester, 'solver_submit_button');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('solver_result_root')), findsOneWidget);
  }

  void appTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        while (transport.pending.isNotEmpty) {
          transport.succeed();
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await flush(tester);
      }
    });
  }

  setUp(() async => sl.reset());
  tearDown(() async {
    while (transport.pending.isNotEmpty) {
      transport.succeed();
    }
    sl<AppRouter>().dispose();
    await sl<AuthBloc>().close();
    dio.close(force: true);
    refreshDio.close(force: true);
    await sl.reset();
  });

  appTest(
    'real app DI: guest solve, slow explanation, rendering, and backend cache evidence',
    (tester) async {
      await boot(tester);
      expect(find.byKey(const Key('home_screen')), findsOneWidget);
      await tap(tester, 'category_tile_root-finding');
      expect(find.byKey(const Key('solver_workspace_screen')), findsOneWidget);
      await solve(tester);
      await tap(tester, 'explain_with_ai_button');
      expect(
        find.byKey(const Key('explanation_loading_indicator')),
        findsOneWidget,
      );
      expect(transport.explanations, hasLength(1));
      final request = transport.explanations.single;
      expect(request.method, 'POST');
      expect(request.receiveTimeout, const Duration(seconds: 60));
      expect(request.headers, isNot(contains('Authorization')));
      final payload = request.data as Map<String, dynamic>;
      expect(payload['focus'], 'steps');
      expect((payload['solverResult'] as Map)['method'], 'Bisection Method');
      expect(payload, isNot(contains('solverRunId')));
      await tester.pump(const Duration(seconds: 5));
      await flush(tester);
      expect(find.byKey(const Key('explanation_slow_message')), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(
        find.byKey(const Key('explanation_loading_indicator')),
        findsOneWidget,
      );
      expect(transport.explanations, hasLength(1));
      transport.succeed();
      await tester.pumpAndSettle();
      expect(find.text('A verified explanation.'), findsOneWidget);
      expect(find.text('Fresh'), findsOneWidget);
      await tap(tester, 'solver_reset_button');
      expect(find.byKey(const Key('explanation_fresh_chip')), findsNothing);
      await solve(tester);
      await tap(tester, 'explain_with_ai_button');
      transport.succeed(cached: true);
      await tester.pumpAndSettle();
      expect(find.text('Cached'), findsOneWidget);
      expect(transport.explanations, hasLength(2));
    },
  );

  for (final error in [
    'rate',
    'timeout',
    'network',
    'server',
    'malformed',
    'malformed-text',
    'malformed-list',
  ]) {
    appTest('real app recovers from $error only after manual retry', (
      tester,
    ) async {
      await boot(tester);
      await solve(tester);
      await tap(tester, 'explain_with_ai_button');
      switch (error) {
        case 'rate':
          transport.fail(
            status: 429,
            code: 'RATE_LIMIT_EXCEEDED',
            message: 'Quota reached',
          );
        case 'timeout':
          transport.fail(type: DioExceptionType.receiveTimeout);
        case 'network':
          transport.fail(type: DioExceptionType.connectionError);
        case 'server':
          transport.fail(status: 502);
        case 'malformed':
          transport.raw({
            'success': true,
            'data': {'explanation': 42},
          });
        case 'malformed-text':
          transport.raw('<html>Unexpected gateway response</html>');
        case 'malformed-list':
          transport.raw(<Object?>[]);
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('explanation_failure_view')), findsOneWidget);
      expect(
        find.byKey(const Key('explanation_loading_indicator')),
        findsNothing,
      );
      if (error == 'rate') {
        expect(find.textContaining('45 seconds'), findsOneWidget);
      }
      if (error.startsWith('malformed')) {
        expect(
          find.textContaining('Malformed AI explanation response'),
          findsOneWidget,
        );
      }
      await tester.pump(const Duration(seconds: 60));
      expect(transport.explanations, hasLength(1));
      final retry = find.byKey(const Key('explanation_retry_button'));
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.tap(retry);
      await flush(tester);
      expect(transport.explanations, hasLength(2));
      expect(transport.pending, hasLength(1));
      transport.succeed();
      await tester.pumpAndSettle();
      expect(find.text('A verified explanation.'), findsOneWidget);
    });
  }

  appTest(
    'reset and leaving a route invalidate pending UI; returning creates a fresh BLoC',
    (tester) async {
      await boot(tester);
      await solve(tester);
      await tap(tester, 'explain_with_ai_button');
      await tap(tester, 'solver_reset_button');
      transport.succeed(text: 'Stale result');
      await tester.pumpAndSettle();
      expect(find.text('Stale result'), findsNothing);
      await solve(tester);
      await tap(tester, 'explain_with_ai_button');
      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await flush(tester);
      expect(find.byKey(const Key('home_screen')), findsOneWidget);
      await solve(tester);
      await tap(tester, 'explain_with_ai_button');
      expect(transport.pending, hasLength(2));
      transport.succeed(text: 'Old route response');
      await flush(tester);
      expect(find.text('Old route response'), findsNothing);
      expect(
        find.byKey(const Key('explanation_loading_indicator')),
        findsOneWidget,
      );
      transport.succeed(text: 'Current route response');
      await tester.pumpAndSettle();
      expect(find.text('Current route response'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  appTest(
    'login returns to profile; explanation refresh replay retains timeout and current token',
    (tester) async {
      await boot(tester);
      sl<AppRouter>().router.go(AppRoutes.profile);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login_screen')), findsOneWidget);
      expect(
        sl<AppRouter>()
            .router
            .routeInformationProvider
            .value
            .uri
            .queryParameters['from'],
        '/profile',
      );
      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'flow@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'test-password-123',
      );
      await tap(tester, 'login_submit_button');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile_screen')), findsOneWidget);
      await tap(tester, 'profile_history_view_all_button');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history_screen')), findsOneWidget);
      await solve(tester);
      await tap(tester, 'explain_with_ai_button');
      expect(
        transport.explanations.single.headers['Authorization'],
        'Bearer flow-access',
      );
      transport.fail(
        status: 401,
        code: 'TOKEN_EXPIRED',
        message: 'Expired token',
      );
      await flush(tester);
      expect(
        transport.requests.where((r) => r.path == ApiConstants.refreshPath),
        hasLength(1),
      );
      expect(transport.explanations, hasLength(2));
      expect(
        transport.explanations.last.headers['Authorization'],
        'Bearer rotated-access',
      );
      expect(
        transport.explanations.last.receiveTimeout,
        const Duration(seconds: 60),
      );
      expect(storage.access, 'rotated-access');
      transport.succeed();
      await tester.pumpAndSettle();
      expect(find.text('A verified explanation.'), findsOneWidget);
    },
  );
}
