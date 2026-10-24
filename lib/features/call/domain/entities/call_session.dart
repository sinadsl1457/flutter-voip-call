import 'package:freezed_annotation/freezed_annotation.dart';

part 'call_session.freezed.dart';

enum CallDirection { outgoing, incoming }

/// 통화 오디오(Agora RTC 채널)를 누가 들고 있는가.
///
/// - [flutter]: Dart 의 agora_rtc_engine 이 채널에 들어간다. (발신 전체, Android 수신)
/// - [native] : iOS 에서 CallKit 으로 받은 수신 통화. CXAnswerCallAction 시점에는
///              Flutter 엔진이 아직 안 떠 있을 수 있으므로 네이티브 Agora SDK 가 채널에 들어가고,
///              Flutter 화면은 MethodChannel 로 음소거/스피커만 제어한다.
///
/// 원칙: **미디어를 소유한 쪽이 수락 API 를 호출한다.**
enum MediaOwner {
  flutter,
  native;

  static MediaOwner fromWire(Object? value) =>
      value == 'native' ? MediaOwner.native : MediaOwner.flutter;
}

@freezed
abstract class CallSession with _$CallSession {
  const CallSession._();

  const factory CallSession({
    required String channelId,
    required int localUid,
    required int peerId,
    required String peerName,
    required CallDirection direction,
    required MediaOwner mediaOwner,

    /// Agora 채널 토큰. 네이티브가 미디어를 소유한 통화에서는 Flutter 가 쓰지 않는다.
    String? rtcToken,

    /// 네이티브에서 이미 연결된 채 넘어온 통화의 연결 시각 (통화 시간 표시 기준).
    DateTime? connectedAt,
  }) = _CallSession;

  bool get isNativeMedia => mediaOwner == MediaOwner.native;
}
