import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/logging/log.dart';
import '../../domain/repositories/call_repository.dart';
import '../../signaling/foreground_push_source.dart';

@LazySingleton(as: PushTokenProvider)
class FirebasePushTokenProvider implements PushTokenProvider {
  FirebasePushTokenProvider(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Future<String?> pushToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      Log.w('PushToken', 'getToken failed', e);
      return null;
    }
  }
}

/// 앱이 포그라운드일 때 받은 FCM data 메시지.
///
/// iOS 에서만 통화 제어 신호(CALL_ACCEPTED / STOP_RINGING / CALL_END)의 경로로 쓴다.
/// Android 는 네이티브 CallFcmService 가 통화 타입 메시지를 먼저 받아 EventChannel 로 넘기므로,
/// 여기서도 받으면 같은 신호가 두 번 들어온다 → Android 에서는 빈 스트림.
@LazySingleton(as: ForegroundPushSource)
class FirebaseForegroundPushSource implements ForegroundPushSource {
  @override
  Stream<Map<String, Object?>> get messages => Platform.isIOS
      ? FirebaseMessaging.onMessage.map((m) => m.data)
      : const Stream.empty();
}
