abstract interface class ForegroundPushSource {
  /// 포그라운드에서 받은 푸시의 data 필드.
  Stream<Map<String, Object?>> get messages;
}
