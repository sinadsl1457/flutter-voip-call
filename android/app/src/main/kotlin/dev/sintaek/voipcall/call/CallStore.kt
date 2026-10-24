package dev.sintaek.voipcall.call

import java.util.concurrent.ConcurrentHashMap

/**
 * 프로세스 내 통화 상태.
 * FCM 서비스 스레드, 메인 스레드, BroadcastReceiver 에서 동시에 접근하므로 동시성 컬렉션을 쓴다.
 *
 * 프로세스가 죽었다 살아나는 경우를 위해 Intent 에도 payload 를 함께 실어 보낸다 ([CallPayload.toBundle]).
 */
object CallStore {
    private val ringing = ConcurrentHashMap<String, CallPayload>()

    /** 이 기기에서 수락한 통화. Flutter 가 releaseCall 할 때까지 유지. */
    @Volatile
    var answeredChannelId: String? = null
        private set

    fun putRinging(payload: CallPayload) {
        ringing[payload.channelId] = payload
    }

    fun ringing(channelId: String): CallPayload? = ringing[channelId]

    fun isRinging(channelId: String): Boolean = ringing.containsKey(channelId)

    /** 진행 중(울리는 중 또는 수락됨)인 통화. 동시에 하나만 허용한다. */
    fun activeChannelId(): String? = answeredChannelId ?: ringing.keys.firstOrNull()

    /** 수락 처리. 이미 수락된 통화면 false (알림 버튼과 전체화면 버튼 중복 탭). */
    @Synchronized
    fun markAnswered(channelId: String): Boolean {
        if (answeredChannelId == channelId) return false
        ringing.remove(channelId)
        answeredChannelId = channelId
        return true
    }

    @Synchronized
    fun remove(channelId: String) {
        ringing.remove(channelId)
        if (answeredChannelId == channelId) answeredChannelId = null
    }
}
