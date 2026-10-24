import 'package:flutter/material.dart';

import 'home_page.dart';
import 'navigation.dart';
import 'theme.dart';

class VoipCallApp extends StatelessWidget {
  const VoipCallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoIP Call',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      theme: buildAppTheme(),
      home: const HomePage(),
    );
  }
}
