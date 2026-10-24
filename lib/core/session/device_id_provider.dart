import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// 설치 단위 기기 식별자.
/// 발신 요청 시 함께 보내서, 같은 계정으로 로그인한 "내 다른 기기"에는 벨이 울리지 않게 서버가 거른다.
@lazySingleton
class DeviceIdProvider {
  DeviceIdProvider(this._prefs);

  static const _key = 'voip_call.device_uid';

  final SharedPreferences _prefs;

  String get deviceId {
    final saved = _prefs.getString(_key);
    if (saved != null && saved.isNotEmpty) return saved;

    final created = const Uuid().v4();
    unawaited(_prefs.setString(_key, created));
    return created;
  }
}
