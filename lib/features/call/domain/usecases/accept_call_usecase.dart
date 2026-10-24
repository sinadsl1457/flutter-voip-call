import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/call_repository.dart';

/// Flutter 가 미디어를 소유하는 수신 통화(Android)에서만 쓰인다.
/// iOS 는 CXAnswerCallAction 안에서 네이티브가 직접 수락 API 를 호출한다.
@injectable
class AcceptCallUseCase implements UseCase<String, Unit> {
  AcceptCallUseCase(this._repository, this._pushTokens);

  final CallRepository _repository;
  final PushTokenProvider _pushTokens;

  @override
  Future<Either<Failure, Unit>> call(String channelId) async {
    final token = await _pushTokens.pushToken();
    if (token == null || token.isEmpty) {
      return const Left(ServerFailure('push token unavailable'));
    }
    return _repository.acceptCall(channelId: channelId, acceptorToken: token);
  }
}
