import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/session/session_store.dart';
import '../features/call/native/native_call_bridge.dart';
import '../features/call/presentation/coordinator/call_coordinator.dart';
import 'di/injection.dart';

/// 데모용 다이얼러. 실제 서비스에서는 주소록/학생 목록 등에서 발신한다.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _coordinator = getIt<CallCoordinator>();
  final _session = getIt<SessionStore>();
  final _peerIdController = TextEditingController();
  final _peerNameController = TextEditingController(text: '테스트 상대');

  String? _fcmToken;
  bool _fullScreenIntentAllowed = true;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    // Android 13+ 알림 권한 / iOS 알림 권한. 수신 알림과 CALL_ACCEPTED 수신에 필요.
    await FirebaseMessaging.instance.requestPermission();
    String? token;
    try {
      token = await FirebaseMessaging.instance.getToken();
    } on FirebaseException {
      // iOS: APNs 토큰을 받기 전이면 'apns-token-not-set'. 데모 화면이므로 표시만 생략.
    }
    final fullScreen = Platform.isAndroid
        ? await getIt<NativeCallBridge>().canUseFullScreenIntent()
        : true;
    if (!mounted) return;
    setState(() {
      _fcmToken = token;
      _fullScreenIntentAllowed = fullScreen;
    });
  }

  @override
  void dispose() {
    _peerIdController.dispose();
    _peerNameController.dispose();
    super.dispose();
  }

  void _call() {
    final peerId = int.tryParse(_peerIdController.text.trim());
    if (peerId == null) return;
    final name = _peerNameController.text.trim();
    _coordinator.startOutgoing(
      peerId: peerId,
      peerName: name.isEmpty ? '상대방' : name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VoIP Call Demo')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!_fullScreenIntentAllowed)
            const Card(
              child: ListTile(
                leading: Icon(Icons.warning_amber_rounded),
                title: Text('전체화면 알림 권한 꺼짐'),
                subtitle: Text(
                  'Android 14+: 잠금화면에서 수신 화면 대신 알림만 표시됩니다. '
                  '설정 > 앱 > 특별한 앱 접근 > 전체 화면 알림에서 허용하세요.',
                ),
              ),
            ),
          _InfoTile(label: '내 user id', value: '${_session.userId ?? '-'}'),
          _InfoTile(label: 'FCM token', value: _fcmToken),
          if (Platform.isIOS)
            ValueListenableBuilder<String?>(
              valueListenable: _coordinator.voipToken,
              builder: (_, token, _) =>
                  _InfoTile(label: 'VoIP token (PushKit)', value: token),
            ),
          const SizedBox(height: 24),
          TextField(
            controller: _peerIdController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '상대 user id'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _peerNameController,
            decoration: const InputDecoration(labelText: '표시 이름'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _call,
            icon: const Icon(Icons.call_rounded),
            label: const Text('전화 걸기'),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = value ?? '-';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        icon: const Icon(Icons.copy_rounded),
        tooltip: '복사',
        onPressed: value == null
            ? null
            : () => Clipboard.setData(ClipboardData(text: text)),
      ),
    );
  }
}
