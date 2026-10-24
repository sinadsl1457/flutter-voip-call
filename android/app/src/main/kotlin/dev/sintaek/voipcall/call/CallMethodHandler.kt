package dev.sintaek.voipcall.call

import android.app.NotificationManager
import android.content.Context
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Dart → Android. 메서드 이름은 Dart NativeCallBridge 와 1:1. */
class CallMethodHandler(
    context: Context,
    private val onCallReleased: () -> Unit,
) : MethodChannel.MethodCallHandler {

    private val appContext = context.applicationContext
    private val store by lazy { NativeCredentialStore(appContext) }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "configure" -> {
                store.apiBaseUrl = call.argument<String>("apiBaseUrl")
                store.isTestCall = call.argument<Boolean>("isTestCall") ?: true
                result.success(null)
            }

            "syncSession" -> {
                store.accessToken = call.argument<String>("accessToken")
                result.success(null)
            }

            "releaseCall" -> {
                val channelId = call.argument<String>("channelId")
                if (channelId.isNullOrBlank()) {
                    result.error("INVALID_ARGUMENT", "channelId is required", null)
                    return
                }
                CallActions.release(appContext, channelId)
                onCallReleased()
                result.success(null)
            }

            // Android 는 Dart(agora_rtc_engine)가 미디어를 소유하므로 네이티브에서 할 일이 없다.
            "setMuted", "setSpeaker" -> result.success(null)

            // PushKit 은 iOS 전용
            "getVoipToken" -> result.success(null)

            "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent())

            else -> result.notImplemented()
        }
    }

    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        return appContext.getSystemService(NotificationManager::class.java).canUseFullScreenIntent()
    }
}
