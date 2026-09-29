import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/core/constants/api_constants.dart';
import 'package:numlab_frontend/core/network/dio_client.dart';
import 'package:numlab_frontend/core/storage/secure_storage_service.dart';

class _MockSecureStorageService implements SecureStorageService {
  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> clearTokens() async {}

  @override
  Future<bool> hasAccessToken() async => false;

  @override
  Future<bool> hasRefreshToken() async => false;
}

void main() {
  group('ApiConstants Configuration & Target Resolution', () {
    test('defines correct physical device host and base URL', () {
      expect(ApiConstants.physicalDeviceHost, equals('192.168.1.36'));
      expect(ApiConstants.defaultPort, equals(3000));
      expect(ApiConstants.apiPrefix, equals('/api/v1'));
      expect(
        ApiConstants.physicalDeviceBaseUrl,
        equals('http://192.168.1.36:3000/api/v1'),
      );
    });

    test('defines correct Android emulator host and base URL', () {
      expect(ApiConstants.emulatorHost, equals('10.0.2.2'));
      expect(
        ApiConstants.emulatorBaseUrl,
        equals('http://10.0.2.2:3000/api/v1'),
      );
    });

    test('defines correct localhost base URL', () {
      expect(ApiConstants.localhostHost, equals('localhost'));
      expect(
        ApiConstants.localhostBaseUrl,
        equals('http://localhost:3000/api/v1'),
      );
    });

    test('resolves full login endpoint correctly for physical Pixel 8 Pro', () {
      const physicalLoginUrl =
          '${ApiConstants.physicalDeviceBaseUrl}${ApiConstants.loginPath}';
      expect(
        physicalLoginUrl,
        equals('http://192.168.1.36:3000/api/v1/auth/login'),
      );
    });

    test('resolves full login endpoint correctly for Android emulator', () {
      const emulatorLoginUrl =
          '${ApiConstants.emulatorBaseUrl}${ApiConstants.loginPath}';
      expect(
        emulatorLoginUrl,
        equals('http://10.0.2.2:3000/api/v1/auth/login'),
      );
    });

    test('resolves route paths matching backend API specification', () {
      expect(ApiConstants.registerPath, equals('/auth/register'));
      expect(ApiConstants.loginPath, equals('/auth/login'));
      expect(ApiConstants.refreshPath, equals('/auth/refresh'));
      expect(ApiConstants.logoutPath, equals('/auth/logout'));
      expect(ApiConstants.logoutAllPath, equals('/auth/logout-all'));
      expect(ApiConstants.userMePath, equals('/users/me'));
      expect(ApiConstants.historyPath, equals('/users/me/history'));
      expect(ApiConstants.explainPath, equals('/explain'));
      expect(ApiConstants.reportsPath, equals('/reports'));
    });

    test('baseUrl alias matches defaultBaseUrl', () {
      expect(ApiConstants.baseUrl, equals(ApiConstants.defaultBaseUrl));
    });

    test('DioClient respects physical device base URL override', () {
      final mockStorage = _MockSecureStorageService();
      final dio = DioClient.create(
        secureStorageService: mockStorage,
        baseUrl: ApiConstants.physicalDeviceBaseUrl,
      );

      expect(dio.options.baseUrl, equals('http://192.168.1.36:3000/api/v1'));
    });

    test('DioClient respects emulator base URL override', () {
      final mockStorage = _MockSecureStorageService();
      final dio = DioClient.create(
        secureStorageService: mockStorage,
        baseUrl: ApiConstants.emulatorBaseUrl,
      );

      expect(dio.options.baseUrl, equals('http://10.0.2.2:3000/api/v1'));
    });

    test('defaultBaseUrl resolves according to current platform in test environment', () {
      final resolved = ApiConstants.defaultBaseUrl;
      if (kIsWeb) {
        expect(resolved, equals('http://localhost:3000/api/v1'));
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            expect(
              resolved,
              anyOf(
                equals('http://10.0.2.2:3000/api/v1'),
                equals('http://192.168.1.36:3000/api/v1'),
              ),
            );
          case TargetPlatform.iOS:
          case TargetPlatform.windows:
          case TargetPlatform.macOS:
          case TargetPlatform.linux:
          case TargetPlatform.fuchsia:
            expect(resolved, equals('http://localhost:3000/api/v1'));
        }
      }
    });
  });
}
