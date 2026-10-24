import 'package:json_annotation/json_annotation.dart';

part 'call_dto.g.dart';

@JsonSerializable(createFactory: false)
class StartCallRequest {
  const StartCallRequest({
    required this.calleeId,
    required this.callerDeviceUid,
    this.isTest = false,
  });

  final int calleeId;
  final String callerDeviceUid;
  final bool isTest;

  Map<String, dynamic> toJson() => _$StartCallRequestToJson(this);
}

@JsonSerializable(createToJson: false)
class StartCallResponse {
  const StartCallResponse({required this.channelId, required this.rtcToken});

  final String channelId;

  @JsonKey(name: 'token')
  final String rtcToken;

  factory StartCallResponse.fromJson(Map<String, dynamic> json) =>
      _$StartCallResponseFromJson(json);
}

@JsonSerializable(createFactory: false)
class AcceptCallRequest {
  const AcceptCallRequest({required this.acceptorToken});

  final String acceptorToken;

  Map<String, dynamic> toJson() => _$AcceptCallRequestToJson(this);
}

@JsonSerializable(createFactory: false)
class EndCallRequest {
  const EndCallRequest({this.isTest = false});

  final bool isTest;

  Map<String, dynamic> toJson() => _$EndCallRequestToJson(this);
}

@JsonSerializable(createToJson: false)
class EndCallResponse {
  const EndCallResponse({this.duration});

  /// 통화 시간(초). 연결 전에 끝난 통화면 null.
  final int? duration;

  factory EndCallResponse.fromJson(Map<String, dynamic> json) =>
      _$EndCallResponseFromJson(json);
}
