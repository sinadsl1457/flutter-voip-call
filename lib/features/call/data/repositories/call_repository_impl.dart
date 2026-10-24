import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/logging/log.dart';
import '../../../../core/network/base_response.dart';
import '../../domain/entities/call_ticket.dart';
import '../../domain/repositories/call_repository.dart';
import '../datasources/call_api.dart';
import '../models/call_dto.dart';

@LazySingleton(as: CallRepository)
class CallRepositoryImpl implements CallRepository {
  CallRepositoryImpl(this._api);

  static const _tag = 'CallRepository';

  final CallApi _api;

  @override
  Future<Either<Failure, CallTicket>> startCall({
    required int calleeId,
    required String deviceId,
    required bool isTest,
  }) {
    return _request('startCall', () async {
      final res = await _api.startCall(
        StartCallRequest(
          calleeId: calleeId,
          callerDeviceUid: deviceId,
          isTest: isTest,
        ),
      );
      final data = _unwrap(res);
      return CallTicket(channelId: data.channelId, rtcToken: data.rtcToken);
    });
  }

  @override
  Future<Either<Failure, Unit>> acceptCall({
    required String channelId,
    required String acceptorToken,
  }) {
    return _request('acceptCall', () async {
      final res = await _api.acceptCall(
        channelId,
        AcceptCallRequest(acceptorToken: acceptorToken),
      );
      _ensureSuccess(res);
      return unit;
    });
  }

  @override
  Future<Either<Failure, Duration?>> endCall({
    required String channelId,
    required bool isTest,
  }) {
    return _request('endCall', () async {
      final res = await _api.endCall(channelId, EndCallRequest(isTest: isTest));
      _ensureSuccess(res);
      final seconds = res.data?.duration;
      return seconds == null ? null : Duration(seconds: seconds);
    });
  }

  Future<Either<Failure, T>> _request<T>(
    String name,
    Future<T> Function() run,
  ) async {
    try {
      return Right(await run());
    } catch (e, st) {
      final failure = failureFrom(e);
      Log.e(_tag, '$name failed: $failure', e, st);
      return Left(failure);
    }
  }

  void _ensureSuccess(BaseResponse<Object?> res) {
    if (!res.success) {
      throw ServerFailure(res.message ?? 'request failed', code: res.code);
    }
  }

  T _unwrap<T>(BaseResponse<T> res) {
    _ensureSuccess(res);
    final data = res.data;
    if (data == null) throw const ParseFailure('empty data');
    return data;
  }
}
