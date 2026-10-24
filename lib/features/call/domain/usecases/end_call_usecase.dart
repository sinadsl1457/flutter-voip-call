import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../app/app_config.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/call_repository.dart';

@injectable
class EndCallUseCase implements UseCase<String, Duration?> {
  EndCallUseCase(this._repository, this._config);

  final CallRepository _repository;
  final AppConfig _config;

  @override
  Future<Either<Failure, Duration?>> call(String channelId) {
    return _repository.endCall(
      channelId: channelId,
      isTest: _config.isTestCall,
    );
  }
}
