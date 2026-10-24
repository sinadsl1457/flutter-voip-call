import 'package:injectable/injectable.dart';

/// 빌드 타임 설정. 키와 서버 주소는 저장소에 두지 않고 `--dart-define` 으로 주입한다.
///
/// ```sh
/// flutter run --dart-define-from-file=env/dev.json
/// ```
@singleton
class AppConfig {
  const AppConfig();

  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _rtcAppId = String.fromEnvironment('AGORA_APP_ID');
  static const _isTestCall = bool.fromEnvironment(
    'IS_TEST_CALL',
    defaultValue: true,
  );
  static const _demoAccessToken = String.fromEnvironment('DEMO_ACCESS_TOKEN');
  static const _demoUserId = String.fromEnvironment('DEMO_USER_ID');

  String get apiBaseUrl => _apiBaseUrl;

  String get rtcAppId => _rtcAppId;

  /// 서버에서 테스트 통화로 집계(과금/통계 제외)할지 여부.
  bool get isTestCall => _isTestCall;

  String get demoAccessToken => _demoAccessToken;

  int? get demoUserId => int.tryParse(_demoUserId);

  /// 발신 후 상대가 받지 않을 때 자동 종료까지의 시간.
  /// 수신 측 링 타임아웃(네이티브 60초)보다 짧게 둬서, 발신자가 먼저 정리하고 STOP_RINGING 이 나가도록 한다.
  Duration get ringTimeout => const Duration(seconds: 45);
}
