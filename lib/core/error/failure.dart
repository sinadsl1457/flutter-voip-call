import 'package:dio/dio.dart';
import 'package:json_annotation/json_annotation.dart';

sealed class Failure {
  const Failure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType($message)';
}

/// 연결 실패, 타임아웃, 2xx 이외 응답 등.
final class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {this.statusCode});

  final int? statusCode;
}

/// 서버가 `success: false` 와 함께 내려준 비즈니스 에러.
final class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.code});

  /// 예: `CALLER_TOKEN_NOT_FOUND` — 발신자의 푸시 토큰이 서버에 없어서
  /// CALL_ACCEPTED 를 돌려받을 수 없는 상태.
  final String? code;
}

final class ParseFailure extends Failure {
  const ParseFailure(super.message);
}

final class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}

Failure failureFrom(Object error) {
  if (error is Failure) return error;
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['code'] is String) {
      return ServerFailure(
        data['message']?.toString() ?? 'server_error',
        code: data['code'] as String,
      );
    }
    return NetworkFailure(
      error.message ?? error.type.name,
      statusCode: error.response?.statusCode,
    );
  }
  if (error is CheckedFromJsonException) {
    return ParseFailure('${error.className}.${error.key}: ${error.message}');
  }
  return UnknownFailure(error.toString());
}
