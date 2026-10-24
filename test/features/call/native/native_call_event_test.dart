import 'package:flutter_test/flutter_test.dart';
import 'package:voip_call/features/call/domain/entities/call_end_reason.dart';
import 'package:voip_call/features/call/domain/entities/call_session.dart';
import 'package:voip_call/features/call/native/call_wire_payload.dart';
import 'package:voip_call/features/call/native/native_call_event.dart';

void main() {
  group('CallWirePayload.tryParse', () {
    test('Android FCM data — 숫자가 문자열로 온다', () {
      final payload = CallWirePayload.tryParse({
        'type': 'CALL_START',
        'channelId': 'ch-1',
        'callerId': '12',
        'calleeId': '34',
        'callerName': '김선생',
        'rtcToken': 'tok',
      });

      expect(payload, isNotNull);
      expect(payload!.callerId, 12);
      expect(payload.calleeId, 34);
      expect(payload.callerName, '김선생');
    });

    test('iOS APNs — 숫자가 숫자로 온다', () {
      final payload = CallWirePayload.tryParse({
        'type': 'CALL_START',
        'channelId': 'ch-1',
        'callerId': 12,
        'calleeId': 34.0,
      });

      expect(payload!.callerId, 12);
      expect(payload.calleeId, 34);
    });

    test('필수 필드가 없으면 null', () {
      expect(CallWirePayload.tryParse({'type': 'CALL_START'}), isNull);
      expect(CallWirePayload.tryParse({'channelId': 'ch-1'}), isNull);
      expect(CallWirePayload.tryParse({'type': '', 'channelId': 'ch-1'}), isNull);
    });
  });

  group('NativeCallEvent.parse', () {
    test('call_answered — 네이티브 미디어 + 연결 시각', () {
      final event = NativeCallEvent.parse({
        'event': 'call_answered',
        'data': {
          'type': 'CALL_START',
          'channelId': 'ch-1',
          'callerId': 1,
          'calleeId': 2,
          'mediaOwner': 'native',
          'connectedAtMs': 1700000000000,
        },
      });

      expect(event, isA<NativeCallAnswered>());
      final answered = event! as NativeCallAnswered;
      expect(answered.mediaOwner, MediaOwner.native);
      expect(
        answered.connectedAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
    });

    test('call_answered — mediaOwner 가 없으면 flutter', () {
      final event = NativeCallEvent.parse({
        'event': 'call_answered',
        'data': {'type': 'CALL_START', 'channelId': 'ch-1'},
      });

      expect((event! as NativeCallAnswered).mediaOwner, MediaOwner.flutter);
    });

    test('call_ended — reason 매핑, 모르는 값은 remoteHangup', () {
      final declined = NativeCallEvent.parse({
        'event': 'call_ended',
        'data': {'channelId': 'ch-1', 'reason': 'declined'},
      });
      final unknown = NativeCallEvent.parse({
        'event': 'call_ended',
        'data': {'channelId': 'ch-1', 'reason': 'something-new'},
      });

      expect((declined! as NativeCallEnded).reason, CallEndReason.declined);
      expect((unknown! as NativeCallEnded).reason, CallEndReason.remoteHangup);
    });

    test('voip_token — 무효화되면 null 토큰', () {
      final event = NativeCallEvent.parse({
        'event': 'voip_token',
        'data': {'token': null},
      });

      expect(event, isA<NativeVoipTokenUpdated>());
      expect((event! as NativeVoipTokenUpdated).token, isNull);
    });

    test('알 수 없는 이벤트 / 잘못된 형태는 무시', () {
      expect(NativeCallEvent.parse({'event': 'unknown', 'data': {}}), isNull);
      expect(NativeCallEvent.parse('not a map'), isNull);
      expect(NativeCallEvent.parse({'event': 'call_ended', 'data': {}}), isNull);
    });
  });
}
