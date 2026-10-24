import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

import '../../../core/logging/log.dart';
import 'native_call_event.dart';

/// Flutter ↔ 네이티브(Kotlin/Swift) 통화 채널.
///
/// - EventChannel: 네이티브 → Dart. 네이티브는 Dart 리스너가 붙기 전에 발생한 이벤트를
///   버퍼에 쌓아두었다가 onListen 시점에 flush 한다 (콜드 스타트 대응).
/// - MethodChannel: Dart → 네이티브. 설정/세션 동기화, 네이티브 통화 정리, iOS 네이티브 미디어 제어.
@lazySingleton
class NativeCallBridge {
  static const _tag = 'NativeCallBridge';
  static const eventChannelName = 'voip_call/events';
  static const methodChannelName = 'voip_call/methods';

  static const _eventChannel = EventChannel(eventChannelName);
  static const _methodChannel = MethodChannel(methodChannelName);

  /// broadcast 스트림. 여러 곳에서 listen 해도 네이티브 onListen 은 한 번만 호출된다.
  late final Stream<NativeCallEvent> events = _eventChannel
      .receiveBroadcastStream()
      .handleError((Object e) => Log.e(_tag, 'event stream error', e))
      .map(NativeCallEvent.parse)
      .where((event) => event != null)
      .cast<NativeCallEvent>();

  /// 네이티브가 Flutter 없이 API 를 호출할 때 쓸 설정.
  Future<void> configure({
    required String apiBaseUrl,
    required String rtcAppId,
    required bool isTestCall,
  }) => _invoke('configure', {
    'apiBaseUrl': apiBaseUrl,
    'rtcAppId': rtcAppId,
    'isTestCall': isTestCall,
  });

  /// null 이면 네이티브 저장소의 토큰을 지운다(로그아웃).
  Future<void> syncSession({String? accessToken}) =>
      _invoke('syncSession', {'accessToken': accessToken});

  /// 통화가 끝난 뒤 네이티브 쪽 잔여 상태 정리.
  /// Android: 벨/알림/전체화면 Activity, 잠금화면 표시 플래그. iOS: CallKit 통화 종료, 네이티브 Agora leave.
  /// 서버 종료 API 는 호출하지 않는다 (Dart 가 이미 호출했거나, 상대가 끊은 경우).
  Future<void> releaseCall(String channelId) =>
      _invoke('releaseCall', {'channelId': channelId});

  /// iOS 네이티브 미디어 전용. Android 에서는 no-op.
  Future<void> setMuted(bool muted) => _invoke('setMuted', {'muted': muted});

  /// iOS 네이티브 미디어 전용. Android 에서는 no-op.
  Future<void> setSpeaker(bool enabled) =>
      _invoke('setSpeaker', {'enabled': enabled});

  /// iOS PushKit VoIP 토큰. Android 는 항상 null.
  Future<String?> voipToken() async {
    try {
      return await _methodChannel.invokeMethod<String>('getVoipToken');
    } on PlatformException catch (e) {
      Log.w(_tag, 'getVoipToken failed', e);
      return null;
    }
  }

  /// Android 14+ 는 전체화면 인텐트 권한이 기본 거부일 수 있다.
  /// false 면 잠금화면에서 수신 화면 대신 heads-up 알림만 뜬다.
  Future<bool> canUseFullScreenIntent() async {
    try {
      return await _methodChannel.invokeMethod<bool>(
            'canUseFullScreenIntent',
          ) ??
          true;
    } on PlatformException {
      return true;
    }
  }

  Future<void> _invoke(String method, [Map<String, Object?>? args]) async {
    try {
      await _methodChannel.invokeMethod<void>(method, args);
    } on PlatformException catch (e) {
      Log.e(_tag, '$method failed: ${e.code} ${e.message}', e);
    } on MissingPluginException {
      Log.w(_tag, '$method: no native handler (unsupported platform?)');
    }
  }
}
