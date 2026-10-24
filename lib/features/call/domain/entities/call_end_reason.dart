/// 통화 종료 사유. 네이티브(Kotlin/Swift)와 문자열(`name`)로 주고받는다.
enum CallEndReason {
  /// 내가 끊음
  localHangup,

  /// 상대가 끊음 (CALL_END) 또는 상대가 RTC 채널에서 나감
  remoteHangup,

  /// 수신자가 거절
  declined,

  /// 발신자가 연결 전에 취소 (STOP_RINGING)
  cancelled,

  /// 같은 계정의 다른 기기에서 받음 (STOP_RINGING + reason)
  answeredElsewhere,

  /// 링 타임아웃
  noAnswer,

  /// RTC 연결 실패 (재연결 실패 포함)
  connectionLost,

  failed;

  static CallEndReason fromWire(
    Object? value, {
    CallEndReason fallback = CallEndReason.remoteHangup,
  }) {
    for (final reason in values) {
      if (reason.name == value) return reason;
    }
    return fallback;
  }

  String get label => switch (this) {
    localHangup || remoteHangup => '통화가 종료되었습니다',
    declined => '상대방이 통화를 거절했습니다',
    cancelled => '발신이 취소되었습니다',
    answeredElsewhere => '다른 기기에서 통화를 받았습니다',
    noAnswer => '상대방이 응답하지 않습니다',
    connectionLost => '연결이 끊어졌습니다',
    failed => '통화를 연결하지 못했습니다',
  };
}
