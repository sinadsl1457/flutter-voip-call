import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/theme.dart';
import '../../domain/entities/call_session.dart';
import '../cubit/call_cubit.dart';
import '../widgets/call_controls.dart';
import '../widgets/call_status_label.dart';
import '../widgets/peer_avatar.dart';

sealed class CallPageArgs {
  const CallPageArgs();
}

final class OutgoingCallArgs extends CallPageArgs {
  const OutgoingCallArgs({
    required this.peerId,
    required this.peerName,
    required this.localUid,
  });

  final int peerId;
  final String peerName;
  final int localUid;

  @override
  String toString() => 'OutgoingCallArgs(peer=$peerId)';
}

final class AnsweredCallArgs extends CallPageArgs {
  const AnsweredCallArgs(this.session);

  final CallSession session;

  @override
  String toString() =>
      'AnsweredCallArgs(${session.channelId}, ${session.mediaOwner.name})';
}

class CallPage extends StatelessWidget {
  const CallPage({super.key, required this.args});

  final CallPageArgs args;

  static Route<void> route(CallPageArgs args) => MaterialPageRoute<void>(
    settings: const RouteSettings(name: '/call'),
    fullscreenDialog: true,
    builder: (_) => CallPage(args: args),
  );

  String get _peerName => switch (args) {
    OutgoingCallArgs(:final peerName) => peerName,
    AnsweredCallArgs(:final session) => session.peerName,
  };

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CallCubit>(
      // 화면이 그려지기 전에 시그널 구독을 시작해야 하므로 lazy: false
      lazy: false,
      create: (_) {
        final cubit = getIt<CallCubit>();
        switch (args) {
          case OutgoingCallArgs(:final peerId, :final peerName, :final localUid):
            unawaited(
              cubit.startOutgoing(
                peerId: peerId,
                peerName: peerName,
                localUid: localUid,
              ),
            );
          case AnsweredCallArgs(:final session):
            unawaited(cubit.attachAnswered(session));
        }
        return cubit;
      },
      child: _CallView(peerName: _peerName),
    );
  }
}

class _CallView extends StatelessWidget {
  const _CallView({required this.peerName});

  final String peerName;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CallCubit>();

    return BlocConsumer<CallCubit, CallState>(
      listenWhen: (prev, curr) => !prev.isEnded && curr.isEnded,
      listener: (context, state) async {
        final message = state.error?.message ?? state.endReason?.label;
        if (message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        // 종료 사유를 잠깐 보여준 뒤 닫는다.
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (context.mounted) await Navigator.of(context).maybePop();
      },
      builder: (context, state) {
        return PopScope(
          // 통화 중 뒤로가기로 화면만 사라지는 것을 막는다. 종료는 버튼으로.
          canPop: state.isEnded,
          child: Scaffold(
            backgroundColor: CallColors.background,
            body: SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  PeerAvatar(
                    name: peerName,
                    ringing: state.phase == CallPhase.dialing ||
                        state.phase == CallPhase.connecting,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    peerName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: CallColors.onBackground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  CallStatusLabel(state: state),
                  const Spacer(flex: 3),
                  CallControls(
                    state: state,
                    onToggleMute: cubit.toggleMute,
                    onToggleSpeaker: cubit.toggleSpeaker,
                    onHangUp: cubit.hangUp,
                  ),
                  const SizedBox(height: 56),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

extension CallErrorMessage on CallError {
  String get message => switch (this) {
    CallError.micPermissionDenied => '마이크 권한이 필요합니다. 설정에서 허용해 주세요.',
    CallError.pushTokenMissing => '전화 기능을 쓰려면 알림 권한을 허용해 주세요.',
    CallError.network => '네트워크 연결을 확인해 주세요.',
    CallError.server => '통화를 시작하지 못했습니다. 잠시 후 다시 시도해 주세요.',
    CallError.media => '음성 연결에 실패했습니다.',
  };
}
