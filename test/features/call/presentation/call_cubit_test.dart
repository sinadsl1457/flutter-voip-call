import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voip_call/app/app_config.dart';
import 'package:voip_call/core/error/failure.dart';
import 'package:voip_call/core/permission/mic_permission.dart';
import 'package:voip_call/features/call/domain/entities/call_end_reason.dart';
import 'package:voip_call/features/call/domain/entities/call_session.dart';
import 'package:voip_call/features/call/domain/entities/call_signal.dart';
import 'package:voip_call/features/call/domain/entities/call_ticket.dart';
import 'package:voip_call/features/call/domain/usecases/accept_call_usecase.dart';
import 'package:voip_call/features/call/domain/usecases/end_call_usecase.dart';
import 'package:voip_call/features/call/domain/usecases/start_call_usecase.dart';
import 'package:voip_call/features/call/media/call_media.dart';
import 'package:voip_call/features/call/media/call_media_factory.dart';
import 'package:voip_call/features/call/native/native_call_bridge.dart';
import 'package:voip_call/features/call/presentation/cubit/call_cubit.dart';
import 'package:voip_call/features/call/signaling/call_signal_hub.dart';

class _MockStartCall extends Mock implements StartCallUseCase {}

class _MockAcceptCall extends Mock implements AcceptCallUseCase {}

class _MockEndCall extends Mock implements EndCallUseCase {}

class _MockMediaFactory extends Mock implements CallMediaFactory {}

class _MockHub extends Mock implements CallSignalHub {}

class _MockBridge extends Mock implements NativeCallBridge {}

class _MockMic extends Mock implements MicPermission {}

class _MockConfig extends Mock implements AppConfig {}

class _FakeMedia implements CallMedia {
  _FakeMedia(this.owner);

  @override
  final MediaOwner owner;

  final controller = StreamController<CallMediaEvent>.broadcast();
  bool joined = false;
  bool left = false;

  @override
  Stream<CallMediaEvent> get events => controller.stream;

  @override
  Future<void> join({
    required String channelId,
    required String token,
    required int uid,
  }) async => joined = true;

  @override
  Future<void> setMuted(bool muted) async =>
      controller.add(MediaMuteChanged(muted));

  @override
  Future<void> setSpeaker(bool enabled) async =>
      controller.add(MediaSpeakerChanged(enabled));

  @override
  Future<void> leave() async => left = true;
}

TypeMatcher<CallState> _phase(
  CallPhase phase, {
  CallEndReason? reason,
  CallError? error,
}) {
  var matcher = isA<CallState>().having((s) => s.phase, 'phase', phase);
  if (reason != null) {
    matcher = matcher.having((s) => s.endReason, 'endReason', reason);
  }
  if (error != null) {
    matcher = matcher.having((s) => s.error, 'error', error);
  }
  return matcher;
}

void main() {
  const ticket = CallTicket(channelId: 'ch-1', rtcToken: 'rtc-token');

  late _MockStartCall startCall;
  late _MockAcceptCall acceptCall;
  late _MockEndCall endCall;
  late _MockMediaFactory mediaFactory;
  late _MockHub hub;
  late _MockBridge bridge;
  late _MockMic mic;
  late _MockConfig config;
  late StreamController<CallSignal> signals;
  late _FakeMedia media;

  setUpAll(() {
    registerFallbackValue(const StartCallParams(calleeId: 0));
    registerFallbackValue(MediaOwner.flutter);
  });

  setUp(() {
    startCall = _MockStartCall();
    acceptCall = _MockAcceptCall();
    endCall = _MockEndCall();
    mediaFactory = _MockMediaFactory();
    hub = _MockHub();
    bridge = _MockBridge();
    mic = _MockMic();
    config = _MockConfig();
    signals = StreamController<CallSignal>.broadcast();
    media = _FakeMedia(MediaOwner.flutter);

    when(() => mic.request()).thenAnswer((_) async => true);
    when(() => startCall.call(any())).thenAnswer((_) async => const Right(ticket));
    when(() => acceptCall.call(any())).thenAnswer((_) async => const Right(unit));
    when(() => endCall.call(any())).thenAnswer((_) async => const Right(null));
    when(() => mediaFactory.create(any())).thenAnswer((_) => media);
    when(() => hub.signals).thenAnswer((_) => signals.stream);
    when(() => hub.hasEnded(any())).thenReturn(false);
    when(() => bridge.releaseCall(any())).thenAnswer((_) async {});
    when(() => config.ringTimeout).thenReturn(const Duration(seconds: 45));
  });

  tearDown(() => signals.close());

  CallCubit build() => CallCubit(
    startCall,
    acceptCall,
    endCall,
    mediaFactory,
    hub,
    bridge,
    mic,
    config,
  );

  Future<void> startOutgoing(CallCubit cubit) =>
      cubit.startOutgoing(peerId: 7, peerName: '상대', localUid: 1);

  CallSession incoming({MediaOwner owner = MediaOwner.flutter, DateTime? at}) =>
      CallSession(
        channelId: 'ch-1',
        localUid: 2,
        peerId: 1,
        peerName: '발신자',
        direction: CallDirection.incoming,
        mediaOwner: owner,
        rtcToken: 'rtc-token',
        connectedAt: at,
      );

  group('발신', () {
    blocTest<CallCubit, CallState>(
      '서버 응답 후 dialing, 상대가 RTC 에 들어오면 inCall',
      build: build,
      act: (cubit) async {
        await startOutgoing(cubit);
        media.controller.add(const RemoteJoined(7));
      },
      expect: () => [
        _phase(CallPhase.dialing)
            .having((s) => s.session?.channelId, 'channelId', 'ch-1'),
        _phase(CallPhase.inCall)
            .having((s) => s.connectedAt, 'connectedAt', isNotNull),
      ],
      verify: (_) => expect(media.joined, isTrue),
    );

    blocTest<CallCubit, CallState>(
      'CALL_ACCEPTED 푸시로도 inCall 전환 (RTC 이벤트보다 먼저 올 수 있음)',
      build: build,
      act: (cubit) async {
        await startOutgoing(cubit);
        signals.add(const CallAcceptedByPeer('ch-1'));
      },
      expect: () => [_phase(CallPhase.dialing), _phase(CallPhase.inCall)],
    );

    blocTest<CallCubit, CallState>(
      '마이크 권한이 없으면 서버 호출 없이 종료',
      setUp: () => when(() => mic.request()).thenAnswer((_) async => false),
      build: build,
      act: startOutgoing,
      expect: () => [
        _phase(
          CallPhase.ended,
          reason: CallEndReason.failed,
          error: CallError.micPermissionDenied,
        ),
      ],
      verify: (_) {
        verifyNever(() => startCall.call(any()));
        verifyNever(() => bridge.releaseCall(any()));
      },
    );

    blocTest<CallCubit, CallState>(
      '서버가 CALLER_TOKEN_NOT_FOUND 면 알림 권한 안내 에러',
      setUp: () => when(() => startCall.call(any())).thenAnswer(
        (_) async => const Left(
          ServerFailure('no token', code: 'CALLER_TOKEN_NOT_FOUND'),
        ),
      ),
      build: build,
      act: startOutgoing,
      expect: () => [
        _phase(CallPhase.ended, error: CallError.pushTokenMissing),
      ],
    );

    blocTest<CallCubit, CallState>(
      '호출 중 내가 끊으면 cancelled + 서버 종료 + 네이티브 정리',
      build: build,
      act: (cubit) async {
        await startOutgoing(cubit);
        await cubit.hangUp();
      },
      expect: () => [
        _phase(CallPhase.dialing),
        _phase(CallPhase.ended, reason: CallEndReason.cancelled),
      ],
      verify: (_) {
        verify(() => endCall.call('ch-1')).called(1);
        verify(() => bridge.releaseCall('ch-1')).called(1);
        expect(media.left, isTrue);
      },
    );

    blocTest<CallCubit, CallState>(
      '상대가 끊으면(CALL_END) 서버 종료 API 는 다시 부르지 않는다',
      build: build,
      act: (cubit) async {
        await startOutgoing(cubit);
        signals.add(const CallEnded('ch-1', CallEndReason.remoteHangup));
      },
      expect: () => [
        _phase(CallPhase.dialing),
        _phase(CallPhase.ended, reason: CallEndReason.remoteHangup),
      ],
      verify: (_) {
        verifyNever(() => endCall.call(any()));
        verify(() => bridge.releaseCall('ch-1')).called(1);
      },
    );

    blocTest<CallCubit, CallState>(
      '다른 채널의 신호는 무시',
      build: build,
      act: (cubit) async {
        await startOutgoing(cubit);
        signals.add(const CallEnded('other', CallEndReason.remoteHangup));
      },
      expect: () => [_phase(CallPhase.dialing)],
    );

    blocTest<CallCubit, CallState>(
      '응답이 없으면 링 타임아웃으로 noAnswer',
      setUp: () => when(() => config.ringTimeout)
          .thenReturn(const Duration(milliseconds: 50)),
      build: build,
      act: startOutgoing,
      wait: const Duration(milliseconds: 120),
      expect: () => [
        _phase(CallPhase.dialing),
        _phase(CallPhase.ended, reason: CallEndReason.noAnswer),
      ],
      verify: (_) => verify(() => endCall.call('ch-1')).called(1),
    );

    test('서버 응답 전에 취소하면, 늦게 생성된 채널도 서버에서 정리한다', () async {
      final pending = Completer<Either<Failure, CallTicket>>();
      when(() => startCall.call(any())).thenAnswer((_) => pending.future);
      final cubit = build();

      final started = startOutgoing(cubit);
      await pumpEventQueue();
      await cubit.hangUp();
      pending.complete(const Right(ticket));
      await started;

      expect(cubit.state.phase, CallPhase.ended);
      verify(() => endCall.call('ch-1')).called(1);
      expect(media.joined, isFalse);
      await cubit.close();
    });
  });

  group('수신', () {
    blocTest<CallCubit, CallState>(
      'iOS 네이티브 미디어: 바로 inCall, 수락 API·마이크 요청을 Flutter 가 하지 않는다',
      setUp: () => media = _FakeMedia(MediaOwner.native),
      build: build,
      act: (cubit) => cubit.attachAnswered(
        incoming(owner: MediaOwner.native, at: DateTime(2026, 1, 1, 9)),
      ),
      expect: () => [
        _phase(CallPhase.inCall).having(
          (s) => s.connectedAt,
          'connectedAt',
          DateTime(2026, 1, 1, 9),
        ),
      ],
      verify: (_) {
        verifyNever(() => acceptCall.call(any()));
        verifyNever(() => mic.request());
      },
    );

    blocTest<CallCubit, CallState>(
      'Android(Flutter 미디어): connecting → 수락 API → RTC join',
      build: build,
      act: (cubit) => cubit.attachAnswered(incoming()),
      expect: () => [_phase(CallPhase.connecting)],
      verify: (_) {
        verify(() => acceptCall.call('ch-1')).called(1);
        expect(media.joined, isTrue);
      },
    );

    blocTest<CallCubit, CallState>(
      '화면이 뜨기 전에 이미 끝난 통화면 바로 종료',
      setUp: () => when(() => hub.hasEnded('ch-1')).thenReturn(true),
      build: build,
      act: (cubit) => cubit.attachAnswered(incoming()),
      expect: () => [
        _phase(CallPhase.connecting),
        _phase(CallPhase.ended, reason: CallEndReason.remoteHangup),
      ],
      verify: (_) => verifyNever(() => acceptCall.call(any())),
    );

    blocTest<CallCubit, CallState>(
      '수락 API 실패 시 서버에 종료 통지',
      setUp: () => when(() => acceptCall.call(any()))
          .thenAnswer((_) async => const Left(NetworkFailure('timeout'))),
      build: build,
      act: (cubit) => cubit.attachAnswered(incoming()),
      expect: () => [
        _phase(CallPhase.connecting),
        _phase(
          CallPhase.ended,
          reason: CallEndReason.failed,
          error: CallError.network,
        ),
      ],
      verify: (_) => verify(() => endCall.call('ch-1')).called(1),
    );

    blocTest<CallCubit, CallState>(
      '음소거 상태는 미디어 이벤트로만 갱신 (CallKit UI 와 동기화)',
      setUp: () => media = _FakeMedia(MediaOwner.native),
      build: build,
      act: (cubit) async {
        await cubit.attachAnswered(incoming(owner: MediaOwner.native));
        await cubit.toggleMute();
      },
      expect: () => [
        _phase(CallPhase.inCall),
        _phase(CallPhase.inCall).having((s) => s.muted, 'muted', true),
      ],
    );
  });
}
