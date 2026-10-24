import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../app/app_config.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/session/device_id_provider.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/call_ticket.dart';
import '../repositories/call_repository.dart';

class StartCallParams {
  const StartCallParams({required this.calleeId});

  final int calleeId;
}

@injectable
class StartCallUseCase implements UseCase<StartCallParams, CallTicket> {
  StartCallUseCase(this._repository, this._deviceId, this._config);

  final CallRepository _repository;
  final DeviceIdProvider _deviceId;
  final AppConfig _config;

  @override
  Future<Either<Failure, CallTicket>> call(StartCallParams input) {
    return _repository.startCall(
      calleeId: input.calleeId,
      deviceId: _deviceId.deviceId,
      isTest: _config.isTestCall,
    );
  }
}
