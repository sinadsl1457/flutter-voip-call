import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../session/session_store.dart';

@injectable
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._session);

  final SessionStore _session;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _session.accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
