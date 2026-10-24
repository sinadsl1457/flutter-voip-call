import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

class PeerAvatar extends StatefulWidget {
  const PeerAvatar({super.key, required this.name, required this.ringing});

  final String name;

  /// 호출/연결 중이면 바깥 링이 퍼지는 애니메이션.
  final bool ringing;

  @override
  State<PeerAvatar> createState() => _PeerAvatarState();
}

class _PeerAvatarState extends State<PeerAvatar>
    with SingleTickerProviderStateMixin {
  static const _size = 112.0;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant PeerAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ringing != widget.ringing) _sync();
  }

  void _sync() {
    if (widget.ringing) {
      _pulse.repeat();
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.name.isEmpty ? '?' : widget.name.characters.first;

    return SizedBox.square(
      dimension: _size * 1.8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final t = _pulse.value;
              return Container(
                width: _size * (1 + 0.8 * t),
                height: _size * (1 + 0.8 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CallColors.accent.withValues(alpha: 0.25 * (1 - t)),
                ),
              );
            },
          ),
          Container(
            width: _size,
            height: _size,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: CallColors.surface,
            ),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w600,
                color: CallColors.onBackground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
