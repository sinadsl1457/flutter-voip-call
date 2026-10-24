import 'package:flutter/widgets.dart';

/// 통화 화면은 푸시/네이티브 이벤트로 열리기 때문에 BuildContext 없이 접근할 수 있어야 한다.
final rootNavigatorKey = GlobalKey<NavigatorState>();
