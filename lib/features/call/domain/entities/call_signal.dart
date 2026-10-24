import 'call_end_reason.dart';
import 'call_session.dart';

/// 통화 생명주기 신호. 출처(네이티브 EventChannel / FCM 포그라운드 메시지)와 무관하게
/// CallSignalHub 가 이 형태로 정규화해서 내보낸다.
sealed class CallSignal {
  const CallSignal(this.channelId);

  final String channelId;
}

/// 사용자가 네이티브 수신 UI(CallKit / 전체화면 Activity / 알림 버튼)에서 전화를 받음.
final class CallAnsweredLocally extends CallSignal {
  CallAnsweredLocally(this.session) : super(session.channelId);

  final CallSession session;
}

/// (발신자 입장) 상대가 전화를 받음 — 서버 푸시 CALL_ACCEPTED.
final class CallAcceptedByPeer extends CallSignal {
  const CallAcceptedByPeer(super.channelId);
}

final class CallEnded extends CallSignal {
  const CallEnded(super.channelId, this.reason);

  final CallEndReason reason;
}
