import 'dart:async';

import 'package:injectable/injectable.dart';

import '../../app/app_config.dart';

/// 로그인 세션(access token, user id) 보관소.
///
/// 실제 앱에서는 로그인/토큰 갱신 시점에 [setAccessToken] 이 호출된다.
/// 이 데모는 인증 기능이 없으므로 `--dart-define` 으로 받은 값을 초기값으로 쓴다.
///
/// 토큰이 바뀌면 [tokenChanges] 로 알리고, CallCoordinator 가 이를 네이티브 저장소
/// (iOS Keychain / Android SharedPreferences)에 동기화한다.
/// → 앱이 죽어 있는 상태에서 수신 거절/수락 API 를 네이티브가 직접 호출할 수 있게 하기 위함.
@lazySingleton
class SessionStore {
  SessionStore(AppConfig config)
    : _accessToken = config.demoAccessToken.isEmpty
          ? null
          : config.demoAccessToken,
      _userId = config.demoUserId;

  String? _accessToken;
  int? _userId;
  final _tokenChanges = StreamController<String?>.broadcast();

  String? get accessToken => _accessToken;

  int? get userId => _userId;

  Stream<String?> get tokenChanges => _tokenChanges.stream;

  void setAccessToken(String? token) {
    if (token == _accessToken) return;
    _accessToken = token;
    _tokenChanges.add(token);
  }

  void setUserId(int? userId) => _userId = userId;

  void clear() {
    _userId = null;
    setAccessToken(null);
  }
}
