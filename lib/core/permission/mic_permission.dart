import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';

abstract interface class MicPermission {
  /// 권한이 있으면 true. 영구 거부 상태면 설정 화면을 연다.
  Future<bool> request();
}

@LazySingleton(as: MicPermission)
class PermissionHandlerMicPermission implements MicPermission {
  @override
  Future<bool> request() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) await openAppSettings();
    return false;
  }
}
