import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';

import '../../../../app/app_config.dart';
import '../../../../app/navigation.dart';
import '../../../../core/logging/log.dart';
import '../../../../core/session/session_store.dart';
import '../../domain/entities/call_signal.dart';
import '../../native/native_call_bridge.dart';
import '../../native/native_call_event.dart';
import '../../signaling/call_signal_hub.dart';
import '../pages/call_page.dart';

/// 앱 전역에서 통화 화면 진입을 담당한다.
///
/// - 네이티브 수신 UI 에서 받은 통화 → 통화 화면 push
/// - 앱 화면에서 발신 → 통화 화면 push
/// - 동시에 두 개의 통화 화면이 뜨지 않도록 막는다
///
/// 콜드 스타트(알림 수락 → 앱 실행)에서는 수락 이벤트가 MaterialApp 의 Navigator 보다 먼저
/// 도착할 수 있다. 고정 지연으로 기다리지 않고, Navigator 가 준비될 때까지 보류했다가 다음 프레임에 연다.
@lazySingleton
class CallCoordinator {
  CallCoordinator(this._hub, this._bridge, this._session, this._config);

  static const _tag = 'CallCoordinator';

  final CallSignalHub _hub;
  final NativeCallBridge _bridge;
  final SessionStore _session;
  final AppConfig _config;

  /// iOS VoIP 토큰. 실제 앱에서는 기기 등록 API 로 서버에 올린다. (데모 화면에 표시)
  final ValueNotifier<String?> voipToken = ValueNotifier(null);

  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _callScreenOpen = false;
  CallPageArgs? _pending;

  Future<void> start() async {
    await _bridge.configure(
      apiBaseUrl: _config.apiBaseUrl,
      rtcAppId: _config.rtcAppId,
      isTestCall: _config.isTestCall,
    );
    await _bridge.syncSession(accessToken: _session.accessToken);

    // 아래 세 구독 사이에 await 를 두지 않는다.
    // 첫 구독 시점에 네이티브가 버퍼를 flush 하는데, 그 이벤트는 다음 이벤트 루프에서 들어오므로
    // 같은 동기 구간 안에서 등록된 리스너는 모두 받는다.
    _subscriptions
      ..add(_hub.signals.listen(_onSignal))
      ..add(_bridge.events.listen(_onNativeEvent))
      ..add(
        _session.tokenChanges.listen(
          (token) => unawaited(_bridge.syncSession(accessToken: token)),
        ),
      );
    _hub.start();

    voipToken.value = await _bridge.voipToken();
  }

  void startOutgoing({required int peerId, required String peerName}) {
    final myUserId = _session.userId;
    if (myUserId == null) {
      Log.w(_tag, 'startOutgoing: no user id');
      return;
    }
    _open(
      OutgoingCallArgs(peerId: peerId, peerName: peerName, localUid: myUserId),
    );
  }

  void _onSignal(CallSignal signal) {
    switch (signal) {
      case CallAnsweredLocally(:final session):
        _open(AnsweredCallArgs(session));
      case CallEnded(:final channelId):
        final pending = _pending;
        if (pending is AnsweredCallArgs &&
            pending.session.channelId == channelId) {
          Log.i(_tag, 'pending call ended before screen opened: $channelId');
          _pending = null;
        }
      case CallAcceptedByPeer():
        break;
    }
  }

  void _onNativeEvent(NativeCallEvent event) {
    if (event is NativeVoipTokenUpdated) voipToken.value = event.token;
  }

  void _open(CallPageArgs args) {
    if (_callScreenOpen) {
      Log.w(_tag, 'call screen already open — ignore $args');
      return;
    }

    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) {
      Log.d(_tag, 'navigator not ready — defer $args');
      _pending = args;
      WidgetsBinding.instance
        ..addPostFrameCallback((_) => _drainPending())
        ..ensureVisualUpdate();
      return;
    }

    _callScreenOpen = true;
    unawaited(
      navigator.push(CallPage.route(args)).whenComplete(() {
        _callScreenOpen = false;
      }),
    );
  }

  void _drainPending() {
    final args = _pending;
    _pending = null;
    if (args != null) _open(args);
  }
}
