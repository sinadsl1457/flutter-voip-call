package dev.sintaek.voipcall.call

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import androidx.core.content.ContextCompat
import dev.sintaek.voipcall.R

/**
 * 잠금화면/화면 꺼짐 상태에서 뜨는 수신 화면 (full-screen intent).
 *
 * Flutter 를 띄우지 않는 순수 네이티브 화면이다. 콜드 스타트에서 Flutter 엔진이 뜨기까지
 * 1~2초가 걸리는데, 그동안 사용자가 보는 화면이 비어 있으면 안 되기 때문.
 * 벨소리는 여기서 울리지 않는다 (IncomingCallService 의 Ringer 가 단독 담당).
 */
class IncomingCallActivity : Activity() {

    private lateinit var payload: CallPayload
    private var receiverRegistered = false

    private val dismissReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) = finishAndRemoveTask()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val parsed = CallPayload.fromBundle(intent.getBundleExtra(CallContract.EXTRA_PAYLOAD))
        // 알림이 늦게 눌려 이미 끝난 통화라면 바로 닫는다.
        if (parsed == null || !CallStore.isRinging(parsed.channelId)) {
            finishAndRemoveTask()
            return
        }
        payload = parsed

        showOverLockScreen()
        setContentView(R.layout.activity_incoming_call)
        findViewById<TextView>(R.id.caller_name).text = payload.displayName
        findViewById<TextView>(R.id.caller_initial).text = payload.displayName.take(1)
        findViewById<View>(R.id.btn_answer).setOnClickListener { onAnswer() }
        findViewById<View>(R.id.btn_decline).setOnClickListener { onDecline() }

        ContextCompat.registerReceiver(
            this,
            dismissReceiver,
            IntentFilter(CallContract.ACTION_DISMISS_INCOMING_UI),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        receiverRegistered = true
    }

    private fun showOverLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun onAnswer() {
        // MainActivity 가 잠금화면 위에 Flutter 통화 화면을 띄우고 CallActions.answer 를 호출한다.
        startActivity(CallNotifications.answerIntent(this, payload))
        finishAndRemoveTask()
    }

    private fun onDecline() {
        CallActions.decline(this, payload.channelId)
        finishAndRemoveTask()
    }

    override fun onDestroy() {
        if (receiverRegistered) unregisterReceiver(dismissReceiver)
        super.onDestroy()
    }

    companion object {
        fun intent(context: Context, payload: CallPayload): Intent =
            Intent(context, IncomingCallActivity::class.java).apply {
                putExtra(CallContract.EXTRA_PAYLOAD, payload.toBundle())
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION)
            }
    }
}
