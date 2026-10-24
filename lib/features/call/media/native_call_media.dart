import 'dart:async';

import '../domain/entities/call_session.dart';
import '../native/native_call_bridge.dart';
import '../native/native_call_event.dart';
import 'call_media.dart';

/// iOS CallKit 으로 받은 통화. 채널은 이미 네이티브(NativeRtcSession)가 들어가 있다.
///
/// - 음소거: Flutter → CallKit(CXSetMutedCallAction) → 네이티브 Agora → `mute_changed` 이벤트
///   이렇게 CallKit 을 거쳐야 잠금화면 통화 UI 의 음소거 버튼과 Flutter 화면이 어긋나지 않는다.
/// - 상대가 나간 경우는 네이티브가 CallKit 통화를 끝내고 `call_ended` 를 보내므로
///   여기서는 따로 RemoteLeft 를 내지 않는다.
class NativeCallMedia implements CallMedia {
  NativeCallMedia(this._bridge) {
    _subscription = _bridge.events.listen(_onNativeEvent);
  }

  final NativeCallBridge _bridge;
  final _events = StreamController<CallMediaEvent>.broadcast();
  late final StreamSubscription<NativeCallEvent> _subscription;

  @override
  MediaOwner get owner => MediaOwner.native;

  @override
  Stream<CallMediaEvent> get events => _events.stream;

  @override
  Future<void> join({
    required String channelId,
    required String token,
    required int uid,
  }) async {
    // CXAnswerCallAction 에서 이미 join 완료.
  }

  @override
  Future<void> setMuted(bool muted) => _bridge.setMuted(muted);

  @override
  Future<void> setSpeaker(bool enabled) => _bridge.setSpeaker(enabled);

  /// 실제 정리(CallKit 종료 + 네이티브 leave)는 NativeCallBridge.releaseCall 에서 한다.
  @override
  Future<void> leave() async {
    await _subscription.cancel();
    await _events.close();
  }

  void _onNativeEvent(NativeCallEvent event) {
    if (_events.isClosed) return;
    switch (event) {
      case NativeMuteChanged(:final muted):
        _events.add(MediaMuteChanged(muted));
      case NativeSpeakerChanged(:final enabled):
        _events.add(MediaSpeakerChanged(enabled));
      default:
        break;
    }
  }
}
