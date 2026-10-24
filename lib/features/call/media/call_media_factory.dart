import 'package:injectable/injectable.dart';

import '../../../app/app_config.dart';
import '../domain/entities/call_session.dart';
import '../native/native_call_bridge.dart';
import 'agora_call_media.dart';
import 'call_media.dart';
import 'native_call_media.dart';

@lazySingleton
class CallMediaFactory {
  CallMediaFactory(this._config, this._bridge);

  final AppConfig _config;
  final NativeCallBridge _bridge;

  CallMedia create(MediaOwner owner) => switch (owner) {
    MediaOwner.flutter => AgoraCallMedia(appId: _config.rtcAppId),
    MediaOwner.native => NativeCallMedia(_bridge),
  };
}
