package dev.sintaek.voipcall.call

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

/**
 * 수신 중(벨이 울리는 동안)에만 살아있는 포그라운드 서비스.
 *
 * - FCM 고우선순위 메시지를 받은 직후 시작한다. 이 시점에는 백그라운드에서도 FGS 시작이 허용된다.
 * - 수락/거절/상대 취소/타임아웃 중 무엇이든 [CallActions] 를 통해 stop 된다.
 * - 통화 "중"에는 이 서비스가 없다. 통화 중 오디오는 Flutter(Agora) 쪽이 담당.
 */
class IncomingCallService : Service() {

    private lateinit var ringer: Ringer
    private val handler = Handler(Looper.getMainLooper())
    private var channelId: String? = null

    /** 서버의 STOP_RINGING 이 유실돼도 무한히 울리지 않도록 하는 안전장치. */
    private val ringTimeout = Runnable {
        channelId?.let { CallActions.onMissed(this, it) }
    }

    override fun onCreate() {
        super.onCreate()
        ringer = Ringer(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val payload = CallPayload.fromBundle(intent?.getBundleExtra(CallContract.EXTRA_PAYLOAD))
        if (payload == null) {
            Log.w(TAG, "started without payload")
            stopSelf()
            return START_NOT_STICKY
        }

        CallNotifications.ensureChannel(this)
        // startForegroundService 후 5초 안에 startForeground 를 불러야 하므로 가장 먼저.
        ServiceCompat.startForeground(
            this,
            CallNotifications.NOTIFICATION_ID_INCOMING,
            CallNotifications.buildIncoming(this, payload),
            ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL,
        )

        // 같은 채널의 CALL_START 재전송이면 벨을 다시 시작하지 않는다.
        if (channelId != payload.channelId) {
            channelId = payload.channelId
            ringer.start()
            handler.removeCallbacks(ringTimeout)
            handler.postDelayed(ringTimeout, RING_TIMEOUT_MS)
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(ringTimeout)
        ringer.stop()
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val TAG = "IncomingCallService"
        private const val RING_TIMEOUT_MS = 60_000L

        fun start(context: Context, payload: CallPayload) {
            val intent = Intent(context, IncomingCallService::class.java)
                .putExtra(CallContract.EXTRA_PAYLOAD, payload.toBundle())
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, IncomingCallService::class.java))
        }
    }
}
