import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../cubit/call_cubit.dart';

class CallStatusLabel extends StatelessWidget {
  const CallStatusLabel({super.key, required this.state});

  final CallState state;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: CallColors.muted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return switch (state.phase) {
      CallPhase.preparing => Text('연결 준비 중', style: style),
      CallPhase.dialing => Text('상대방을 호출하는 중…', style: style),
      CallPhase.connecting => Text('연결 중…', style: style),
      CallPhase.inCall => _ElapsedText(
        since: state.connectedAt ?? DateTime.now(),
        style: style?.copyWith(color: CallColors.accent),
      ),
      CallPhase.ended => Text(
        state.endReason?.label ?? '통화 종료',
        style: style,
      ),
    };
  }
}

/// 통화 시간. Cubit 이 매초 상태를 내보내지 않도록 위젯이 직접 타이머를 가진다.
class _ElapsedText extends StatefulWidget {
  const _ElapsedText({required this.since, this.style});

  final DateTime since;
  final TextStyle? style;

  @override
  State<_ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends State<_ElapsedText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.since);
    return Text(formatCallDuration(elapsed), style: widget.style);
  }
}

String formatCallDuration(Duration d) {
  final safe = d.isNegative ? Duration.zero : d;
  final h = safe.inHours;
  final m = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '${h.toString().padLeft(2, '0')}:$m:$s' : '$m:$s';
}
