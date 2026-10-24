import '../domain/entities/call_session.dart';

/// 통화 오디오 세션 추상화.
///
/// CallCubit 은 미디어가 Dart Agora 인지 iOS 네이티브 Agora 인지 모른다.
/// 음소거/스피커 상태도 구현체가 "실제로 바뀐 뒤" 이벤트로 알려준다.
/// (iOS 는 CallKit UI 에서도 음소거를 바꿀 수 있으므로, 상태의 출처를 하나로 맞추기 위함)
abstract interface class CallMedia {
  MediaOwner get owner;

  Stream<CallMediaEvent> get events;

  Future<void> join({
    required String channelId,
    required String token,
    required int uid,
  });

  Future<void> setMuted(bool muted);

  Future<void> setSpeaker(bool enabled);

  Future<void> leave();
}

sealed class CallMediaEvent {
  const CallMediaEvent();
}

final class RemoteJoined extends CallMediaEvent {
  const RemoteJoined(this.uid);

  final int uid;
}

final class RemoteLeft extends CallMediaEvent {
  const RemoteLeft(this.uid);

  final int uid;
}

/// 재연결까지 실패한 상태.
final class MediaConnectionLost extends CallMediaEvent {
  const MediaConnectionLost();
}

final class MediaMuteChanged extends CallMediaEvent {
  const MediaMuteChanged(this.muted);

  final bool muted;
}

final class MediaSpeakerChanged extends CallMediaEvent {
  const MediaSpeakerChanged(this.enabled);

  final bool enabled;
}
