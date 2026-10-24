/// 서버 푸시 타입. 서버 → 기기 푸시 payload 의 `type` 필드.
abstract final class CallPushType {
  static const start = 'CALL_START';
  static const accepted = 'CALL_ACCEPTED';
  static const stopRinging = 'STOP_RINGING';
  static const end = 'CALL_END';
}

/// 푸시 payload / 네이티브 이벤트 data 의 공통 필드.
///
/// 같은 필드라도 출처마다 타입이 다르다:
/// - Android FCM data 는 모든 값이 String (`"callerId": "12"`)
/// - iOS APNs payload 는 JSON 숫자 (`"callerId": 12`, NSNumber)
/// 그래서 숫자 필드는 관대하게 파싱한다.
class CallWirePayload {
  const CallWirePayload({
    required this.type,
    required this.channelId,
    this.callerId,
    this.calleeId,
    this.callerName,
    this.rtcToken,
    this.reason,
  });

  final String type;
  final String channelId;
  final int? callerId;
  final int? calleeId;
  final String? callerName;
  final String? rtcToken;
  final String? reason;

  static CallWirePayload? tryParse(Map<Object?, Object?> map) {
    final type = _string(map['type']);
    final channelId = _string(map['channelId']);
    if (type == null || channelId == null) return null;

    return CallWirePayload(
      type: type,
      channelId: channelId,
      callerId: parseInt(map['callerId']),
      calleeId: parseInt(map['calleeId']),
      callerName: _string(map['callerName']),
      rtcToken: _string(map['rtcToken']),
      reason: _string(map['reason']),
    );
  }

  static int? parseInt(Object? value) => switch (value) {
    final int v => v,
    final num v => v.toInt(),
    final String v => int.tryParse(v),
    _ => null,
  };

  static String? _string(Object? value) {
    final s = value?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }
}
