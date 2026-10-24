import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

import '../../../../app/app_config.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/logging/log.dart';
import '../../../../core/permission/mic_permission.dart';
import '../../domain/entities/call_end_reason.dart';
import '../../domain/entities/call_session.dart';
import '../../domain/entities/call_signal.dart';
import '../../domain/usecases/accept_call_usecase.dart';
import '../../domain/usecases/end_call_usecase.dart';
import '../../domain/usecases/start_call_usecase.dart';
import '../../media/call_media.dart';
import '../../media/call_media_factory.dart';
import '../../native/native_call_bridge.dart';
import '../../signaling/call_signal_hub.dart';

part 'call_cubit.freezed.dart';
part 'call_state.dart';

/// 통화 한 건의 상태 머신. 통화 화면 하나당 하나.
///
/// ```
/// 발신: preparing → dialing ──(CALL_ACCEPTED | 상대 RTC join)──→ inCall → ended
/// 수신(Android): connecting ──(상대 RTC join)──→ inCall → ended
/// 수신(iOS, 네이티브 미디어): inCall → ended
/// ```
///
/// 종료는 [_finish] 한 곳으로 모은다. 종료 경로(내가 끊음, 상대가 끊음, 타임아웃, 연결 실패,
/// 화면 dispose)가 겹쳐도 정리는 한 번만 일어난다.
@injectable
class CallCubit extends Cubit<CallState> {
  CallCubit(
    this._startCall,
    this._acceptCall,
    this._endCall,
    this._mediaFactory,
    this._hub,
    this._bridge,
    this._mic,
    this._config,
  ) : super(const CallState());

  static const _tag = 'CallCubit';

  final StartCallUseCase _startCall;
  final AcceptCallUseCase _acceptCall;
  final EndCallUseCase _endCall;
  final CallMediaFactory _mediaFactory;
  final CallSignalHub _hub;
  final NativeCallBridge _bridge;
  final MicPermission _mic;
  final AppConfig _config;

  CallMedia? _media;
  StreamSubscription<CallSignal>? _signalSub;
  StreamSubscription<CallMediaEvent>? _mediaSub;
  Timer? _ringTimer;
  bool _finishing = false;

  // ---------------------------------------------------------------------------
  // 진입점
  // ---------------------------------------------------------------------------

  Future<void> startOutgoing({
    required int peerId,
    required String peerName,
    required int localUid,
  }) async {
    if (!await _mic.request()) {
      return _finish(
        CallEndReason.failed,
        notifyServer: false,
        error: CallError.micPermissionDenied,
      );
    }

    final result = await _startCall(StartCallParams(calleeId: peerId));

    await result.fold(
      (failure) => _finish(
        CallEndReason.failed,
        notifyServer: false,
        error: _errorFrom(failure),
      ),
      (ticket) async {
        // 서버 응답을 기다리는 사이 사용자가 취소했다면, 방금 만들어진 채널을 정리해야
        // 상대 기기에서 벨이 계속 울리지 않는다.
        if (_finishing) {
          await _endCall(ticket.channelId);
          return;
        }

        final session = CallSession(
          channelId: ticket.channelId,
          localUid: localUid,
          peerId: peerId,
          peerName: peerName,
          direction: CallDirection.outgoing,
          mediaOwner: MediaOwner.flutter,
          rtcToken: ticket.rtcToken,
        );
        _emit(state.copyWith(session: session, phase: CallPhase.dialing));
        _listenSignals(session.channelId);

        _ringTimer = Timer(_config.ringTimeout, () {
          if (state.phase == CallPhase.dialing) {
            unawaited(_finish(CallEndReason.noAnswer, notifyServer: true));
          }
        });

        await _openMedia(session);
      },
    );
  }

  /// 네이티브 수신 UI 에서 사용자가 받은 통화를 이어받는다.
  Future<void> attachAnswered(CallSession session) async {
    final isNative = session.isNativeMedia;
    _emit(
      state.copyWith(
        session: session,
        phase: isNative ? CallPhase.inCall : CallPhase.connecting,
        connectedAt: isNative ? (session.connectedAt ?? DateTime.now()) : null,
      ),
    );
    _listenSignals(session.channelId);

    // 콜드 스타트에서 화면이 뜨기 전에 상대가 이미 끊은 경우.
    if (_hub.hasEnded(session.channelId)) {
      return _finish(CallEndReason.remoteHangup, notifyServer: false);
    }

    if (isNative) {
      // iOS: 수락 API 와 RTC join 은 CXAnswerCallAction 에서 네이티브가 이미 끝냈다.
      return _openMedia(session);
    }

    final micGranted = await _mic.request();
    // 권한 다이얼로그가 떠 있는 동안 상대가 끊었을 수 있다.
    if (_finishing) return;
    if (!micGranted) {
      return _finish(
        CallEndReason.failed,
        notifyServer: true,
        error: CallError.micPermissionDenied,
      );
    }

    final accepted = await _acceptCall(session.channelId);
    if (_finishing) return;
    final failure = accepted.fold((f) => f, (_) => null);
    if (failure != null) {
      return _finish(
        CallEndReason.failed,
        notifyServer: true,
        error: _errorFrom(failure),
      );
    }

    await _openMedia(session);
  }

  // ---------------------------------------------------------------------------
  // 사용자 액션
  // ---------------------------------------------------------------------------

  Future<void> hangUp() => _finish(
    state.phase == CallPhase.dialing
        ? CallEndReason.cancelled
        : CallEndReason.localHangup,
    notifyServer: true,
  );

  /// 상태는 미디어가 실제로 바뀐 뒤 이벤트로 갱신된다 (_onMediaEvent).
  Future<void> toggleMute() async => _media?.setMuted(!state.muted);

  Future<void> toggleSpeaker() async => _media?.setSpeaker(!state.speakerOn);

  // ---------------------------------------------------------------------------
  // 내부
  // ---------------------------------------------------------------------------

  Future<void> _openMedia(CallSession session) async {
    final media = _mediaFactory.create(session.mediaOwner);
    _media = media;
    _mediaSub = media.events.listen(_onMediaEvent);

    try {
      await media.join(
        channelId: session.channelId,
        token: session.rtcToken ?? '',
        uid: session.localUid,
      );
    } catch (e, st) {
      Log.e(_tag, 'media join failed', e, st);
      await _finish(
        CallEndReason.failed,
        notifyServer: true,
        error: CallError.media,
      );
    }
  }

  void _listenSignals(String channelId) {
    _signalSub = _hub.signals
        .where((signal) => signal.channelId == channelId)
        .listen((signal) {
          switch (signal) {
            case CallAcceptedByPeer():
              _markConnected();
            case CallEnded(:final reason):
              unawaited(_finish(reason, notifyServer: false));
            case CallAnsweredLocally():
              break;
          }
        });
  }

  void _onMediaEvent(CallMediaEvent event) {
    switch (event) {
      case RemoteJoined():
        _markConnected();
      case RemoteLeft():
        // 보통은 CALL_END 푸시가 먼저 오지만, 상대 앱이 죽거나 네트워크가 끊긴 경우를 대비.
        unawaited(_finish(CallEndReason.remoteHangup, notifyServer: false));
      case MediaConnectionLost():
        unawaited(_finish(CallEndReason.connectionLost, notifyServer: true));
      case MediaMuteChanged(:final muted):
        _emit(state.copyWith(muted: muted));
      case MediaSpeakerChanged(:final enabled):
        _emit(state.copyWith(speakerOn: enabled));
    }
  }

  void _markConnected() {
    if (state.phase == CallPhase.inCall || _finishing) return;
    _ringTimer?.cancel();
    _emit(
      state.copyWith(
        phase: CallPhase.inCall,
        connectedAt: state.connectedAt ?? DateTime.now(),
      ),
    );
  }

  Future<void> _finish(
    CallEndReason reason, {
    required bool notifyServer,
    CallError? error,
  }) async {
    if (_finishing) return;
    _finishing = true;
    _ringTimer?.cancel();

    final channelId = state.session?.channelId;
    Log.i(_tag, 'finish channel=$channelId reason=${reason.name} notifyServer=$notifyServer');

    // 화면부터 종료 상태로. 서버 응답을 기다리는 동안 "통화 중" 화면이 남아있지 않게 한다.
    _emit(
      state.copyWith(
        phase: CallPhase.ended,
        endReason: reason,
        error: error ?? state.error,
      ),
    );

    await _signalSub?.cancel();
    await _mediaSub?.cancel();
    final media = _media;
    _media = null;
    await media?.leave();

    if (channelId == null) return;
    if (notifyServer) {
      final result = await _endCall(channelId);
      result.fold((f) => Log.w(_tag, 'end api failed: $f'), (_) {});
    }
    await _bridge.releaseCall(channelId);
  }

  CallError _errorFrom(Failure failure) => switch (failure) {
    ServerFailure(code: 'CALLER_TOKEN_NOT_FOUND') => CallError.pushTokenMissing,
    NetworkFailure() => CallError.network,
    _ => CallError.server,
  };

  void _emit(CallState next) {
    if (!isClosed && !_disposing) emit(next);
  }

  bool _disposing = false;

  @override
  Future<void> close() async {
    // 정상 경로에서는 이미 ended. 화면이 예외적으로 닫힌 경우에도 통화가 남지 않도록 정리만 한다.
    // (닫히는 중이므로 상태는 내보내지 않는다)
    _disposing = true;
    if (!_finishing) {
      await _finish(CallEndReason.localHangup, notifyServer: true);
    }
    return super.close();
  }
}
