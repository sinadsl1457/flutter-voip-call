import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voip_call/features/call/domain/entities/call_end_reason.dart';
import 'package:voip_call/features/call/domain/entities/call_session.dart';
import 'package:voip_call/features/call/domain/entities/call_signal.dart';
import 'package:voip_call/features/call/native/call_wire_payload.dart';
import 'package:voip_call/features/call/native/native_call_bridge.dart';
import 'package:voip_call/features/call/native/native_call_event.dart';
import 'package:voip_call/features/call/signaling/call_signal_hub.dart';
import 'package:voip_call/features/call/signaling/foreground_push_source.dart';

class _MockBridge extends Mock implements NativeCallBridge {}

class _FakePushSource implements ForegroundPushSource {
  final controller = StreamController<Map<String, Object?>>.broadcast();

  @override
  Stream<Map<String, Object?>> get messages => controller.stream;
}

void main() {
  late StreamController<NativeCallEvent> nativeEvents;
  late _FakePushSource push;
  late CallSignalHub hub;
  late List<CallSignal> received;

  NativeCallAnswered answered(String channelId, {int? callerId = 1}) =>
      NativeCallAnswered(
        CallWirePayload(
          type: CallPushType.start,
          channelId: channelId,
          callerId: callerId,
          calleeId: 2,
          callerName: '발신자',
          rtcToken: 'token',
        ),
        mediaOwner: MediaOwner.flutter,
      );

  setUp(() {
    nativeEvents = StreamController<NativeCallEvent>.broadcast();
    push = _FakePushSource();
    final bridge = _MockBridge();
    when(() => bridge.events).thenAnswer((_) => nativeEvents.stream);

    hub = CallSignalHub(bridge, push)..start();
    received = [];
    hub.signals.listen(received.add);
  });

  tearDown(() async {
    await hub.dispose();
    await nativeEvents.close();
    await push.controller.close();
  });

  test('같은 채널의 수락 이벤트가 두 번 와도 한 번만 내보낸다', () async {
    nativeEvents
      ..add(answered('ch-1'))
      ..add(answered('ch-1'));
    await pumpEventQueue();

    expect(received, hasLength(1));
    final session = (received.single as CallAnsweredLocally).session;
    expect(session.localUid, 2);
    expect(session.peerId, 1);
    expect(session.direction, CallDirection.incoming);
  });

  test('id 가 빠진 수락 이벤트는 버린다', () async {
    nativeEvents.add(answered('ch-1', callerId: null));
    await pumpEventQueue();

    expect(received, isEmpty);
  });

  test('네이티브와 FCM 으로 같은 종료가 오면 한 번만, 종료 이력은 남는다', () async {
    nativeEvents.add(const NativeCallEnded('ch-1', CallEndReason.remoteHangup));
    push.controller.add({'type': 'CALL_END', 'channelId': 'ch-1'});
    await pumpEventQueue();

    expect(received, hasLength(1));
    expect(hub.hasEnded('ch-1'), isTrue);
    expect(hub.hasEnded('ch-2'), isFalse);
  });

  test('FCM STOP_RINGING 은 기본 사유가 cancelled', () async {
    push.controller.add({'type': 'STOP_RINGING', 'channelId': 'ch-1'});
    await pumpEventQueue();

    expect((received.single as CallEnded).reason, CallEndReason.cancelled);
  });

  test('FCM STOP_RINGING 에 reason 이 있으면 그대로 쓴다', () async {
    push.controller.add({
      'type': 'STOP_RINGING',
      'channelId': 'ch-1',
      'reason': 'answeredElsewhere',
    });
    await pumpEventQueue();

    expect(
      (received.single as CallEnded).reason,
      CallEndReason.answeredElsewhere,
    );
  });

  test('CALL_ACCEPTED → CallAcceptedByPeer', () async {
    push.controller.add({'type': 'CALL_ACCEPTED', 'channelId': 'ch-9'});
    await pumpEventQueue();

    expect(received.single, isA<CallAcceptedByPeer>());
    expect(received.single.channelId, 'ch-9');
  });
}
