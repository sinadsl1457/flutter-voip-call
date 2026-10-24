import 'dart:async';

import 'package:injectable/injectable.dart';

import '../../../core/logging/log.dart';
import '../domain/entities/call_end_reason.dart';
import '../domain/entities/call_session.dart';
import '../domain/entities/call_signal.dart';
import '../native/call_wire_payload.dart';
import '../native/native_call_bridge.dart';
import '../native/native_call_event.dart';
import 'foreground_push_source.dart';

/// 통화 신호의 단일 진입점.
///
/// 같은 신호가 여러 경로로 들어올 수 있다:
/// - Android: 알림의 "수락" 버튼과 전체화면 Activity 의 "수락" 버튼이 거의 동시에 눌림,
///   콜드 스타트 시 네이티브 버퍼 flush
/// - iOS: 같은 CALL_END 가 VoIP 푸시와 일반 FCM 으로 모두 도착
///
/// 그래서 `(신호 종류, channelId)` 단위로 한 번만 내보낸다.
/// 또한 통화 화면이 뜨기 전에 끝나버린 통화를 판별할 수 있도록 종료된 channelId 를 기억한다.
@lazySingleton
class CallSignalHub {
  CallSignalHub(this._bridge, this._foregroundPush);

  static const _tag = 'CallSignalHub';

  final NativeCallBridge _bridge;
  final ForegroundPushSource _foregroundPush;

  final _controller = StreamController<CallSignal>.broadcast();
  final _emitted = _RecentKeys(64);
  final _ended = _RecentKeys(32);
  final _subscriptions = <StreamSubscription<Object?>>[];

  Stream<CallSignal> get signals => _controller.stream;

  bool hasEnded(String channelId) => _ended.contains(channelId);

  void start() {
    if (_subscriptions.isNotEmpty) return;
    _subscriptions
      ..add(_bridge.events.listen(_onNativeEvent))
      ..add(_foregroundPush.messages.listen(_onForegroundPush));
  }

  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await _controller.close();
  }

  void _onNativeEvent(NativeCallEvent event) {
    switch (event) {
      case final NativeCallAnswered answered:
        final session = _sessionFromAnswer(answered);
        if (session != null) _emit(CallAnsweredLocally(session));
      case NativePeerAccepted(:final channelId):
        _emit(CallAcceptedByPeer(channelId));
      case NativeCallEnded(:final channelId, :final reason):
        _emit(CallEnded(channelId, reason));
      case NativeCallIncoming() ||
          NativeVoipTokenUpdated() ||
          NativeMuteChanged() ||
          NativeSpeakerChanged():
        break;
    }
  }

  void _onForegroundPush(Map<String, Object?> data) {
    final payload = CallWirePayload.tryParse(data);
    if (payload == null) return;

    switch (payload.type) {
      case CallPushType.accepted:
        _emit(CallAcceptedByPeer(payload.channelId));
      case CallPushType.end:
        _emit(CallEnded(payload.channelId, CallEndReason.fromWire(payload.reason)));
      case CallPushType.stopRinging:
        _emit(
          CallEnded(
            payload.channelId,
            CallEndReason.fromWire(
              payload.reason,
              fallback: CallEndReason.cancelled,
            ),
          ),
        );
      default:
        // CALL_START 는 iOS 에서 VoIP 푸시(PushKit)로만 처리한다.
        break;
    }
  }

  CallSession? _sessionFromAnswer(NativeCallAnswered event) {
    final p = event.payload;
    final calleeId = p.calleeId;
    final callerId = p.callerId;
    if (calleeId == null || callerId == null) {
      Log.w(_tag, 'answered payload without ids: channel=${p.channelId}');
      return null;
    }
    return CallSession(
      channelId: p.channelId,
      localUid: calleeId,
      peerId: callerId,
      peerName: p.callerName ?? '알 수 없음',
      direction: CallDirection.incoming,
      mediaOwner: event.mediaOwner,
      rtcToken: p.rtcToken,
      connectedAt: event.connectedAt,
    );
  }

  void _emit(CallSignal signal) {
    final key = '${signal.runtimeType}:${signal.channelId}';
    if (!_emitted.add(key)) {
      Log.d(_tag, 'duplicate signal dropped: $key');
      return;
    }
    if (signal is CallEnded) _ended.add(signal.channelId);
    Log.i(_tag, 'signal: $key');
    _controller.add(signal);
  }
}

/// 최근 N 개만 기억하는 집합.
class _RecentKeys {
  _RecentKeys(this.capacity);

  final int capacity;
  final _keys = <String>{};

  bool contains(String key) => _keys.contains(key);

  /// 새로 추가되면 true, 이미 있으면 false.
  bool add(String key) {
    if (!_keys.add(key)) return false;
    if (_keys.length > capacity) _keys.remove(_keys.first);
    return true;
  }
}
