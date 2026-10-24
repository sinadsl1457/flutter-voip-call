part of 'call_cubit.dart';

enum CallPhase {
  /// 마이크 권한 확인, 발신 API 요청 중
  preparing,

  /// 발신 — 상대 기기에서 벨이 울리는 중
  dialing,

  /// 수신 수락 후 RTC 채널 연결 중 (Android)
  connecting,

  inCall,
  ended,
}

enum CallError {
  micPermissionDenied,

  /// 서버에 내 푸시 토큰이 없음 — 상대가 받아도 CALL_ACCEPTED 를 못 받는다. 알림 권한 유도.
  pushTokenMissing,
  network,
  server,
  media,
}

@freezed
abstract class CallState with _$CallState {
  const CallState._();

  const factory CallState({
    @Default(CallPhase.preparing) CallPhase phase,
    CallSession? session,
    @Default(false) bool muted,
    @Default(false) bool speakerOn,
    DateTime? connectedAt,
    CallEndReason? endReason,
    CallError? error,
  }) = _CallState;

  bool get isEnded => phase == CallPhase.ended;
}
