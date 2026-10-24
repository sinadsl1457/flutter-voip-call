package dev.sintaek.voipcall.call

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** 알림의 "거절" 버튼. (수락은 trampoline 제한 때문에 Activity PendingIntent 로 처리) */
class CallActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != CallContract.ACTION_DECLINE) return
        val channelId = intent.getStringExtra(CallContract.EXTRA_CHANNEL_ID) ?: return

        val pending = goAsync()
        CallActions.decline(context, channelId) { pending.finish() }
    }

    companion object {
        fun declineIntent(context: Context, payload: CallPayload): Intent =
            Intent(context, CallActionReceiver::class.java)
                .setAction(CallContract.ACTION_DECLINE)
                .putExtra(CallContract.EXTRA_CHANNEL_ID, payload.channelId)
    }
}
