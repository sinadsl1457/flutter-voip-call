package dev.sintaek.voipcall.call

/**
 * Dart / iOS 와 공유하는 문자열 계약.
 * 바꿀 때는 lib/features/call/native/ 와 ios/Runner/Call/VoipCallPayload.swift 도 같이 바꿔야 한다.
 */
object CallContract {
    const val EVENT_CHANNEL = "voip_call/events"
    const val METHOD_CHANNEL = "voip_call/methods"

    object Event {
        const val INCOMING = "call_incoming"
        const val ANSWERED = "call_answered"
        const val PEER_ACCEPTED = "call_peer_accepted"
        const val ENDED = "call_ended"
    }

    object PushType {
        const val START = "CALL_START"
        const val ACCEPTED = "CALL_ACCEPTED"
        const val STOP_RINGING = "STOP_RINGING"
        const val END = "CALL_END"

        val ALL = setOf(START, ACCEPTED, STOP_RINGING, END)
    }

    object EndReason {
        const val REMOTE_HANGUP = "remoteHangup"
        const val DECLINED = "declined"
        const val CANCELLED = "cancelled"
        const val NO_ANSWER = "noAnswer"
    }

    const val ACTION_ANSWER = "dev.sintaek.voipcall.action.ANSWER"
    const val ACTION_DECLINE = "dev.sintaek.voipcall.action.DECLINE"
    const val ACTION_DISMISS_INCOMING_UI = "dev.sintaek.voipcall.action.DISMISS_INCOMING_UI"

    const val EXTRA_CHANNEL_ID = "channelId"
    const val EXTRA_PAYLOAD = "payload"
}
