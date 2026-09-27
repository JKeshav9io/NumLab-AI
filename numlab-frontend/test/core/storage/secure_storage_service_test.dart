import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/core/storage/secure_storage_service.dart';

class FakeFlutterSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> store = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      store[key] = value;
    } else {
      store.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return store[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    store.remove(key);
  }
}

void main() {
  group('SecureStorageServiceImpl', () {
    late FakeFlutterSecureStorage fakeStorage;
    late SecureStorageServiceImpl storageService;

    setUp(() {
      fakeStorage = FakeFlutterSecureStorage();
      storageService = SecureStorageServiceImpl(storage: fakeStorage);
    });

    test('saveTokens persists both access and refresh tokens', () async {
      await storageService.saveTokens(
        accessToken: 'access_123',
        refreshToken: 'refresh_456',
      );

      expect(fakeStorage.store['numlab_access_token'], 'access_123');
      expect(fakeStorage.store['numlab_refresh_token'], 'refresh_456');
    });

    test('getAccessToken retrieves stored access token or null', () async {
      expect(await storageService.getAccessToken(), isNull);

      fakeStorage.store['numlab_access_token'] = 'jwt.access.token';
      expect(await storageService.getAccessToken(), 'jwt.access.token');
    });

    test('getRefreshToken retrieves stored refresh token or null', () async {
      expect(await storageService.getRefreshToken(), isNull);

      fakeStorage.store['numlab_refresh_token'] = 'jwt.refresh.token';
      expect(await storageService.getRefreshToken(), 'jwt.refresh.token');
    });

    test('clearTokens deletes both access and refresh tokens', () async {
      fakeStorage.store['numlab_access_token'] = 'acc_token';
      fakeStorage.store['numlab_refresh_token'] = 'ref_token';

      await storageService.clearTokens();

      expect(fakeStorage.store.containsKey('numlab_access_token'), isFalse);
      expect(fakeStorage.store.containsKey('numlab_refresh_token'), isFalse);
      expect(await storageService.getAccessToken(), isNull);
      expect(await storageService.getRefreshToken(), isNull);
    });

    test(
      'hasAccessToken returns true only when access token exists and non-empty',
      () async {
        expect(await storageService.hasAccessToken(), isFalse);

        fakeStorage.store['numlab_access_token'] = '';
        expect(await storageService.hasAccessToken(), isFalse);

        fakeStorage.store['numlab_access_token'] = 'valid.token';
        expect(await storageService.hasAccessToken(), isTrue);
      },
    );

    test(
      'hasRefreshToken returns true only when refresh token exists and non-empty',
      () async {
        expect(await storageService.hasRefreshToken(), isFalse);

        fakeStorage.store['numlab_refresh_token'] = '';
        expect(await storageService.hasRefreshToken(), isFalse);

        fakeStorage.store['numlab_refresh_token'] = 'valid.refresh';
        expect(await storageService.hasRefreshToken(), isTrue);
      },
    );
  });
}
