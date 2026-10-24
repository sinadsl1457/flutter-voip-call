import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../../../../core/network/base_response.dart';
import '../models/call_dto.dart';

part 'call_api.g.dart';

/// 서버 계약은 docs/server-contract.md 참고.
/// accept / end 는 Android(Kotlin)·iOS(Swift) 네이티브에서도 같은 엔드포인트를 직접 호출한다.
@RestApi()
abstract class CallApi {
  factory CallApi(Dio dio, {String? baseUrl}) = _CallApi;

  @POST('/calls')
  Future<BaseResponse<StartCallResponse>> startCall(
    @Body() StartCallRequest body,
  );

  @PATCH('/calls/{channelId}/accept')
  Future<BaseResponse<dynamic>> acceptCall(
    @Path('channelId') String channelId,
    @Body() AcceptCallRequest body,
  );

  @DELETE('/calls/{channelId}/end')
  Future<BaseResponse<EndCallResponse>> endCall(
    @Path('channelId') String channelId,
    @Body() EndCallRequest body,
  );
}
