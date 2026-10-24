import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/call_ticket.dart';

abstract interface class CallRepository {
  /// 서버가 채널/토큰을 만들고 상대 기기에 CALL_START 푸시를 보낸다.
  Future<Either<Failure, CallTicket>> startCall({
    required int calleeId,
    required String deviceId,
    required bool isTest,
  });

  /// [acceptorToken]: 수락한 기기의 푸시 토큰. 서버는 이 기기를 제외한
  /// 나머지 기기에 STOP_RINGING 을 보내고, 발신자에게 CALL_ACCEPTED 를 보낸다.
  Future<Either<Failure, Unit>> acceptCall({
    required String channelId,
    required String acceptorToken,
  });

  /// 통화 종료/거절/취소 공통. 서버가 상대에게 CALL_END 또는 STOP_RINGING 을 보낸다.
  Future<Either<Failure, Duration?>> endCall({
    required String channelId,
    required bool isTest,
  });
}

abstract interface class PushTokenProvider {
  /// 이 기기의 FCM 토큰. 수락 API 의 acceptorToken 으로 쓴다.
  Future<String?> pushToken();
}
