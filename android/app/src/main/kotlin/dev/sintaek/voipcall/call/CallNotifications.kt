package dev.sintaek.voipcall.call

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.Person
import dev.sintaek.voipcall.MainActivity
import dev.sintaek.voipcall.R

object CallNotifications {
    const val CHANNEL_INCOMING = "incoming_calls_v1"
    const val NOTIFICATION_ID_INCOMING = 4101

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_INCOMING) != null) return

        val channel = NotificationChannel(
            CHANNEL_INCOMING,
            context.getString(R.string.call_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = context.getString(R.string.call_channel_description)
            // 소리/진동은 Ringer 가 직접 낸다 (Ringer 주석 참고)
            setSound(null, null)
            enableVibration(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }

    fun buildIncoming(context: Context, payload: CallPayload): Notification {
        val base = payload.channelId.hashCode()

        val fullScreen = PendingIntent.getActivity(
            context, base,
            IncomingCallActivity.intent(context, payload),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        // "수락"은 BroadcastReceiver 를 거치지 않고 Activity 를 바로 연다.
        // Android 12+ 는 알림 → Receiver → startActivity (notification trampoline) 를 막는다.
        val answer = PendingIntent.getActivity(
            context, base + 1,
            answerIntent(context, payload),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        // "거절"은 화면을 띄울 필요가 없으므로 Receiver 로 처리한다.
        val decline = PendingIntent.getBroadcast(
            context, base + 2,
            CallActionReceiver.declineIntent(context, payload),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val caller = Person.Builder()
            .setName(payload.displayName)
            .setImportant(true)
            .build()

        return NotificationCompat.Builder(context, CHANNEL_INCOMING)
            .setSmallIcon(R.drawable.ic_stat_call)
            .setContentTitle(payload.displayName)
            .setContentText(context.getString(R.string.call_incoming_label))
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(fullScreen)
            .setFullScreenIntent(fullScreen, true)
            .setStyle(NotificationCompat.CallStyle.forIncomingCall(caller, decline, answer))
            .build()
    }

    fun answerIntent(context: Context, payload: CallPayload): Intent =
        Intent(context, MainActivity::class.java).apply {
            action = CallContract.ACTION_ANSWER
            putExtra(CallContract.EXTRA_CHANNEL_ID, payload.channelId)
            putExtra(CallContract.EXTRA_PAYLOAD, payload.toBundle())
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP,
            )
        }
}
