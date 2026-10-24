import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../cubit/call_cubit.dart';

class CallControls extends StatelessWidget {
  const CallControls({
    super.key,
    required this.state,
    required this.onToggleMute,
    required this.onToggleSpeaker,
    required this.onHangUp,
  });

  final CallState state;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onHangUp;

  bool get _mediaReady => switch (state.phase) {
    CallPhase.dialing || CallPhase.connecting || CallPhase.inCall => true,
    CallPhase.preparing || CallPhase.ended => false,
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundButton(
          icon: state.muted ? Icons.mic_off_rounded : Icons.mic_none_rounded,
          label: '음소거',
          selected: state.muted,
          onPressed: _mediaReady ? onToggleMute : null,
        ),
        _RoundButton(
          icon: Icons.call_end_rounded,
          label: '종료',
          size: 76,
          background: CallColors.danger,
          onPressed: state.isEnded ? null : onHangUp,
        ),
        _RoundButton(
          icon: state.speakerOn
              ? Icons.volume_up_rounded
              : Icons.volume_down_rounded,
          label: '스피커',
          selected: state.speakerOn,
          onPressed: _mediaReady ? onToggleSpeaker : null,
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.size = 64,
    this.background,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final double size;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final bg =
        background ?? (selected ? CallColors.onBackground : CallColors.surface);
    final fg = background != null
        ? Colors.white
        : (selected ? CallColors.background : CallColors.onBackground);

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: bg,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox.square(
                dimension: size,
                child: Icon(icon, color: fg, size: size * 0.42),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(color: CallColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
