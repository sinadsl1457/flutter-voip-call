package dev.sintaek.voipcall.call

import android.util.Log
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

/**
 * 통화 푸시의 Android 진입점.
 *
 * firebase_messaging 플러그인의 서비스를 상속해서 매니페스트에서 교체한다(tools:node="remove").
 * - 통화 타입(CALL_*, STOP_RINGING)은 여기서 처리하고 끝낸다. 앱이 꺼져 있어도 Flutter 엔진을 띄우지 않고
 *   바로 벨을 울릴 수 있어야 하기 때문.
 * - 그 외 메시지와 onNewToken 은 super 로 넘겨 플러그인 동작을 유지한다.
 *
 * 포그라운드에서는 플러그인의 FlutterFirebaseMessagingReceiver 도 같은 메시지를 Dart onMessage 로 보내지만,
 * Dart 쪽 ForegroundPushSource 는 Android 에서 통화 메시지를 무시하도록 되어 있다.
 */
class CallFcmService : FlutterFirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        val payload = CallPayload.fromData(message.data)
        if (payload == null || payload.type !in CallContract.PushType.ALL) {
            super.onMessageReceived(message)
            return
        }

        Log.i(TAG, "${payload.type} channel=${payload.channelId}")
        when (payload.type) {
            CallContract.PushType.START -> onCallStart(payload)

            // 발신자 기기: 상대가 받음
            CallContract.PushType.ACCEPTED -> CallEventStreamer.emit(
                CallContract.Event.PEER_ACCEPTED,
                mapOf("channelId" to payload.channelId),
            )

            // 수신자 기기: 발신자가 취소했거나, 같은 계정의 다른 기기가 받음
            CallContract.PushType.STOP_RINGING -> {
                if (CallStore.answeredChannelId == payload.channelId) {
                    // 이 기기가 받은 통화다. 서버는 수락 기기를 제외하고 보내야 하지만 방어적으로 무시.
                    return
                }
                CallActions.onRemoteEnded(
                    this, payload.channelId,
                    payload.reason ?: CallContract.EndReason.CANCELLED,
                )
            }

            CallContract.PushType.END -> CallActions.onRemoteEnded(
                this, payload.channelId,
                payload.reason ?: CallContract.EndReason.REMOTE_HANGUP,
            )
        }
    }

    private fun onCallStart(payload: CallPayload) {
        val active = CallStore.activeChannelId()
        if (active != null && active != payload.channelId) {
            // 1:1 통화만 지원. 통화 중 수신은 서버가 busy 처리하는 것이 원칙이고, 여기서는 무시한다.
            Log.w(TAG, "busy with $active, ignore ${payload.channelId}")
            return
        }
        CallStore.putRinging(payload)
        CallEventStreamer.emit(CallContract.Event.INCOMING, payload.toFlutterMap())
        IncomingCallService.start(this, payload)
    }

    private companion object {
        const val TAG = "CallFcmService"
    }
}
