import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/di/injection.dart';
import 'features/call/presentation/coordinator/call_coordinator.dart';

// FirebaseMessaging.onBackgroundMessage 는 일부러 등록하지 않는다.
// 통화 푸시는 네이티브(Android CallFcmService / iOS PushKit)가 처리하므로 Dart 백그라운드
// isolate 가 필요 없다. 등록해 두면 Android 에서 통화 푸시마다 백그라운드 FlutterEngine 이 추가로 떠서
// 메인 엔진과 경쟁하게 된다 (실서비스에서 ANR 원인이었던 부분).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await configureDependencies();
  await getIt<CallCoordinator>().start();
  runApp(const VoipCallApp());
}
