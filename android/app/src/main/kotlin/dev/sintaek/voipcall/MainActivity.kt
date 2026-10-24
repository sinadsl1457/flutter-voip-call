package dev.sintaek.voipcall

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import dev.sintaek.voipcall.call.CallActions
import dev.sintaek.voipcall.call.CallContract
import dev.sintaek.voipcall.call.CallEventStreamer
import dev.sintaek.voipcall.call.CallMethodHandler
import dev.sintaek.voipcall.call.CallPayload
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        EventChannel(messenger, CallContract.EVENT_CHANNEL)
            .setStreamHandler(CallEventStreamer)
        MethodChannel(messenger, CallContract.METHOD_CHANNEL)
            .setMethodCallHandler(CallMethodHandler(this) { setShowOverLockScreen(false) })
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        CallEventStreamer.detach()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // super.onCreate 안에서 configureFlutterEngine 이 호출되므로, 이후에는 채널이 등록돼 있다.
        // Dart 가 아직 listen 하지 않았더라도 CallEventStreamer 가 이벤트를 버퍼링한다.
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) handleCallIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleCallIntent(intent)
    }

    private fun handleCallIntent(intent: Intent?) {
        if (intent?.action != CallContract.ACTION_ANSWER) return
        val channelId = intent.getStringExtra(CallContract.EXTRA_CHANNEL_ID) ?: return
        val fallback = CallPayload.fromBundle(intent.getBundleExtra(CallContract.EXTRA_PAYLOAD))

        // 프로세스 재생성 등으로 같은 인텐트가 다시 전달돼도 두 번 처리하지 않도록.
        intent.action = Intent.ACTION_MAIN

        // 잠금화면에서 받은 경우에도 잠금 해제 없이 Flutter 통화 화면이 보이도록.
        // 통화가 끝나면 releaseCall → onCallReleased 에서 되돌린다.
        setShowOverLockScreen(true)
        CallActions.answer(this, channelId, fallback)
    }

    private fun setShowOverLockScreen(show: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(show)
            setTurnScreenOn(show)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (show) window.addFlags(flags) else window.clearFlags(flags)
        }
    }
}
