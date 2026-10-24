/// 발신 요청에 대한 서버 응답 — 생성된 채널과 발신자용 RTC 토큰.
class CallTicket {
  const CallTicket({required this.channelId, required this.rtcToken});

  final String channelId;
  final String rtcToken;
}
