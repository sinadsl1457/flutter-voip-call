package dev.sintaek.voipcall.call

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * 수신 통화 상태 전이를 한 곳에 모은 것.
 *
 * 수락/거절 진입점이 여러 개(알림 버튼, 전체화면 Activity, MainActivity 인텐트)라서
 * 각자 링 정지·캐시 정리·Flutter 통지를 하다 보면 순서가 엇갈린다.
 * 진입점은 이 객체만 호출하고, 실제 처리는 여기서만 한다.
 */
object CallActions {
    private const val TAG = "CallActions"

    /** 프로세스 수명 스코프. Activity 가 먼저 finish 돼도 거절 API 호출은 끝까지 간다. */
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /**
     * 사용자가 수락함. 링을 멈추고 Flutter 에 알린다.
     * 수락 API 호출과 RTC join 은 Flutter(CallCubit)가 한다 — Android 에서는 Flutter 가 미디어 소유자.
     */
    fun answer(context: Context, channelId: String, fallback: CallPayload?) {
        val payload = CallStore.ringing(channelId) ?: fallback
        if (payload == null) {
            Log.w(TAG, "answer: unknown channel $channelId")
            return
        }
        if (!CallStore.markAnswered(channelId)) {
            Log.d(TAG, "answer: already answered $channelId")
            return
        }
        stopRinging(context)
        CallEventStreamer.emit(
            CallContract.Event.ANSWERED,
            payload.toFlutterMap() + ("mediaOwner" to "flutter"),
        )
    }

    /**
     * 사용자가 거절함. Flutter 가 떠 있지 않을 수 있으므로 서버 통지는 네이티브가 직접 한다.
     * [onComplete] 는 BroadcastReceiver.goAsync() 를 끝내기 위한 콜백.
     */
    fun decline(context: Context, channelId: String, onComplete: (() -> Unit)? = null) {
        val appContext = context.applicationContext
        CallStore.remove(channelId)
        stopRinging(appContext)
        CallEventStreamer.emit(
            CallContract.Event.ENDED,
            mapOf("channelId" to channelId, "reason" to CallContract.EndReason.DECLINED),
        )

        scope.launch {
            NativeCallApi(NativeCredentialStore(appContext))
                .endCall(channelId)
                .onFailure { Log.w(TAG, "decline: end api failed", it) }
            onComplete?.invoke()
        }
    }

    /** 상대 취소(STOP_RINGING) / 상대 종료(CALL_END). */
    fun onRemoteEnded(context: Context, channelId: String, reason: String) {
        if (CallStore.isRinging(channelId)) stopRinging(context)
        CallStore.remove(channelId)
        CallEventStreamer.emit(
            CallContract.Event.ENDED,
            mapOf("channelId" to channelId, "reason" to reason),
        )
    }

    fun onMissed(context: Context, channelId: String) =
        onRemoteEnded(context, channelId, CallContract.EndReason.NO_ANSWER)

    /** Flutter 가 통화를 끝낸 뒤 releaseCall 로 호출. 남아있을 수 있는 수신 UI 를 모두 정리한다. */
    fun release(context: Context, channelId: String) {
        CallStore.remove(channelId)
        stopRinging(context)
    }

    private fun stopRinging(context: Context) {
        IncomingCallService.stop(context)
        NotificationManagerCompat.from(context).cancel(CallNotifications.NOTIFICATION_ID_INCOMING)
        context.sendBroadcast(
            Intent(CallContract.ACTION_DISMISS_INCOMING_UI).setPackage(context.packageName),
        )
    }
}
