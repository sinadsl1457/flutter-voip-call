import '../domain/entities/call_end_reason.dart';
import '../domain/entities/call_session.dart';
import 'call_wire_payload.dart';

/// 네이티브 → Dart 이벤트. EventChannel 로 `{event: String, data: Map}` 형태로 들어온다.
/// 이벤트 이름은 Kotlin `CallContract.Event` / Swift `CallContract.Event` 와 일치해야 한다.
sealed class NativeCallEvent {
  const NativeCallEvent();

  static const voipToken = 'voip_token';
  static const incoming = 'call_incoming';
  static const answered = 'call_answered';
  static const peerAccepted = 'call_peer_accepted';
  static const ended = 'call_ended';
  static const muteChanged = 'mute_changed';
  static const speakerChanged = 'speaker_changed';

  static NativeCallEvent? parse(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['event'];
    final data = raw['data'] is Map ? raw['data'] as Map : const {};

    switch (name) {
      case voipToken:
        return NativeVoipTokenUpdated(data['token'] as String?);

      case incoming:
        final payload = CallWirePayload.tryParse(data);
        return payload == null ? null : NativeCallIncoming(payload);

      case answered:
        final payload = CallWirePayload.tryParse(data);
        if (payload == null) return null;
        final connectedAtMs = CallWirePayload.parseInt(data['connectedAtMs']);
        return NativeCallAnswered(
          payload,
          mediaOwner: MediaOwner.fromWire(data['mediaOwner']),
          connectedAt: connectedAtMs == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(connectedAtMs),
        );

      case peerAccepted:
        final channelId = data['channelId'] as String?;
        return channelId == null ? null : NativePeerAccepted(channelId);

      case ended:
        final channelId = data['channelId'] as String?;
        if (channelId == null) return null;
        return NativeCallEnded(
          channelId,
          CallEndReason.fromWire(data['reason']),
        );

      case muteChanged:
        return NativeMuteChanged(data['muted'] == true);

      case speakerChanged:
        return NativeSpeakerChanged(data['enabled'] == true);

      default:
        return null;
    }
  }
}

final class NativeVoipTokenUpdated extends NativeCallEvent {
  const NativeVoipTokenUpdated(this.token);

  /// 토큰이 무효화되면 null.
  final String? token;
}

final class NativeCallIncoming extends NativeCallEvent {
  const NativeCallIncoming(this.payload);

  final CallWirePayload payload;
}

final class NativeCallAnswered extends NativeCallEvent {
  const NativeCallAnswered(
    this.payload, {
    required this.mediaOwner,
    this.connectedAt,
  });

  final CallWirePayload payload;
  final MediaOwner mediaOwner;
  final DateTime? connectedAt;
}

final class NativePeerAccepted extends NativeCallEvent {
  const NativePeerAccepted(this.channelId);

  final String channelId;
}

final class NativeCallEnded extends NativeCallEvent {
  const NativeCallEnded(this.channelId, this.reason);

  final String channelId;
  final CallEndReason reason;
}

/// iOS: CallKit UI(잠금화면 등)에서 음소거를 바꾼 경우에도 들어온다.
final class NativeMuteChanged extends NativeCallEvent {
  const NativeMuteChanged(this.muted);

  final bool muted;
}

/// iOS: 실제 오디오 라우트 변경(AVAudioSession.routeChangeNotification) 기준.
final class NativeSpeakerChanged extends NativeCallEvent {
  const NativeSpeakerChanged(this.enabled);

  final bool enabled;
}
