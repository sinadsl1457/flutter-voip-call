import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../../../core/logging/log.dart';
import '../domain/entities/call_session.dart';
import 'call_media.dart';

/// Dart(agora_rtc_engine)가 채널을 소유하는 경우. 발신 통화 전체 + Android 수신 통화.
class AgoraCallMedia implements CallMedia {
  AgoraCallMedia({required String appId}) : _appId = appId;

  static const _tag = 'AgoraCallMedia';

  final String _appId;
  final _events = StreamController<CallMediaEvent>.broadcast();
  RtcEngine? _engine;
  bool _released = false;

  @override
  MediaOwner get owner => MediaOwner.flutter;

  @override
  Stream<CallMediaEvent> get events => _events.stream;

  @override
  Future<void> join({
    required String channelId,
    required String token,
    required int uid,
  }) async {
    if (_appId.isEmpty) {
      throw StateError('AGORA_APP_ID is not set (--dart-define)');
    }

    final engine = createAgoraRtcEngine();
    _engine = engine;

    await engine.initialize(
      RtcEngineContext(
        appId: _appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          Log.d(_tag, 'joined ${connection.channelId} uid=${connection.localUid} (${elapsed}ms)');
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          Log.d(_tag, 'remote joined uid=$remoteUid');
          _add(RemoteJoined(remoteUid));
        },
        onUserOffline: (connection, remoteUid, reason) {
          Log.d(_tag, 'remote offline uid=$remoteUid reason=$reason');
          _add(RemoteLeft(remoteUid));
        },
        onConnectionStateChanged: (connection, state, reason) {
          Log.d(_tag, 'connection $state ($reason)');
          // reconnecting 은 SDK 가 알아서 재시도한다. failed 가 되어야 끝난 것으로 본다.
          if (state == ConnectionStateType.connectionStateFailed) {
            _add(const MediaConnectionLost());
          }
        },
        onError: (err, msg) {
          // onError 중 다수는 경고성이라 여기서 통화를 끊지 않는다. 연결 상태 콜백으로 판단.
          Log.w(_tag, 'agora error $err: $msg');
        },
      ),
    );

    await engine.enableAudio();
    await engine.disableVideo();
    await engine.setDefaultAudioRouteToSpeakerphone(false);

    await engine.joinChannel(
      token: token,
      channelId: channelId,
      uid: uid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
      ),
    );
  }

  @override
  Future<void> setMuted(bool muted) async {
    final engine = _engine;
    if (engine == null) return;
    await engine.muteLocalAudioStream(muted);
    _add(MediaMuteChanged(muted));
  }

  @override
  Future<void> setSpeaker(bool enabled) async {
    final engine = _engine;
    if (engine == null) return;
    await engine.setEnableSpeakerphone(enabled);
    _add(MediaSpeakerChanged(enabled));
  }

  @override
  Future<void> leave() async {
    if (_released) return;
    _released = true;

    final engine = _engine;
    _engine = null;
    if (engine != null) {
      try {
        await engine.leaveChannel();
      } catch (e) {
        Log.w(_tag, 'leaveChannel failed', e);
      }
      try {
        await engine.release();
      } catch (e) {
        Log.w(_tag, 'release failed', e);
      }
    }
    await _events.close();
  }

  void _add(CallMediaEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}
