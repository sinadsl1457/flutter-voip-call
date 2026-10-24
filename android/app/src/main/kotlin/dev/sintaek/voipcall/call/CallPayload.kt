package dev.sintaek.voipcall.call

import android.os.Bundle

/**
 * 서버 푸시(FCM data) payload.
 *
 * FCM data 는 Map<String, String> 이므로 숫자도 문자열로 온다.
 * Intent 로 넘길 때도 Bundle 에 문자열로만 담아서 [fromData] 하나로 파싱한다.
 * (getSerializableExtra(HashMap) 는 API 33 에서 deprecated 이고 타입 안전하지 않음)
 */
data class CallPayload(
    val type: String,
    val channelId: String,
    val callerId: Long?,
    val calleeId: Long?,
    val callerName: String?,
    val rtcToken: String?,
    val reason: String?,
) {
    val displayName: String
        get() = callerName?.takeIf { it.isNotBlank() } ?: "알 수 없는 발신자"

    fun toBundle(): Bundle = Bundle().apply {
        putString(KEY_TYPE, type)
        putString(KEY_CHANNEL_ID, channelId)
        callerId?.let { putString(KEY_CALLER_ID, it.toString()) }
        calleeId?.let { putString(KEY_CALLEE_ID, it.toString()) }
        callerName?.let { putString(KEY_CALLER_NAME, it) }
        rtcToken?.let { putString(KEY_RTC_TOKEN, it) }
        reason?.let { putString(KEY_REASON, it) }
    }

    /** Dart 의 CallWirePayload 가 읽는 형태. */
    fun toFlutterMap(): Map<String, Any?> = mapOf(
        KEY_TYPE to type,
        KEY_CHANNEL_ID to channelId,
        KEY_CALLER_ID to callerId,
        KEY_CALLEE_ID to calleeId,
        KEY_CALLER_NAME to callerName,
        KEY_RTC_TOKEN to rtcToken,
    )

    companion object {
        private const val KEY_TYPE = "type"
        private const val KEY_CHANNEL_ID = "channelId"
        private const val KEY_CALLER_ID = "callerId"
        private const val KEY_CALLEE_ID = "calleeId"
        private const val KEY_CALLER_NAME = "callerName"
        private const val KEY_RTC_TOKEN = "rtcToken"
        private const val KEY_REASON = "reason"

        private val KEYS = listOf(
            KEY_TYPE, KEY_CHANNEL_ID, KEY_CALLER_ID, KEY_CALLEE_ID,
            KEY_CALLER_NAME, KEY_RTC_TOKEN, KEY_REASON,
        )

        fun fromData(data: Map<String, String>): CallPayload? {
            val type = data[KEY_TYPE]?.takeIf { it.isNotBlank() } ?: return null
            val channelId = data[KEY_CHANNEL_ID]?.takeIf { it.isNotBlank() } ?: return null
            return CallPayload(
                type = type,
                channelId = channelId,
                callerId = data[KEY_CALLER_ID]?.toLongOrNull(),
                calleeId = data[KEY_CALLEE_ID]?.toLongOrNull(),
                callerName = data[KEY_CALLER_NAME],
                rtcToken = data[KEY_RTC_TOKEN],
                reason = data[KEY_REASON],
            )
        }

        fun fromBundle(bundle: Bundle?): CallPayload? {
            if (bundle == null) return null
            val data = KEYS.mapNotNull { key -> bundle.getString(key)?.let { key to it } }.toMap()
            return fromData(data)
        }
    }
}
