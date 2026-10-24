package dev.sintaek.voipcall.call

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import io.flutter.plugin.common.EventChannel

/**
 * 네이티브 → Dart 이벤트 스트림.
 *
 * 수신 수락은 대부분 "앱이 꺼져 있거나 백그라운드"인 상태에서 일어난다.
 * 이때 MainActivity 가 막 만들어져 Dart 의 listen 이 아직 안 붙었으므로, 이벤트를 버퍼에 쌓아두고
 * onListen 이 호출되는 즉시 순서대로 내보낸다.
 *
 * 실서비스 버전은 sink 연결 후 300ms / 1000ms 지연 flush 를 여러 번 걸어 타이밍을 맞췄다.
 * 지연 값은 기기 성능에 기대는 값이라, 여기서는 onListen 자체를 "Dart 가 준비됨" 신호로 보고
 * 지연 없이 그 시점에 flush 한다. (화면 전환 타이밍은 Dart 쪽 CallCoordinator 가 따로 맞춘다)
 *
 * 모든 sink 접근은 메인 스레드에서만 한다 (EventSink 는 메인 스레드 전용).
 */
object CallEventStreamer : EventChannel.StreamHandler {
    private const val TAG = "CallEventStreamer"
    private const val MAX_PENDING = 32

    /** 너무 오래된 이벤트(예: 1분 전 수락)는 Dart 가 늦게 붙었을 때 화면을 잘못 띄우므로 버린다. */
    private const val PENDING_TTL_MS = 60_000L

    private class Pending(val envelope: Map<String, Any?>, val createdAt: Long)

    private val mainHandler = Handler(Looper.getMainLooper())
    private val pending = ArrayDeque<Pending>()
    private var sink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        flush()
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    /**
     * FlutterEngine 이 파괴될 때 호출. onCancel 이 오지 않은 채 엔진이 사라지면
     * 죽은 sink 로 이벤트를 보내 유실되므로 명시적으로 끊는다.
     */
    fun detach() = onMain { sink = null }

    fun emit(event: String, data: Map<String, Any?> = emptyMap()) {
        val envelope = mapOf("event" to event, "data" to data)
        onMain {
            val current = sink
            if (current != null) {
                current.success(envelope)
            } else {
                if (pending.size >= MAX_PENDING) pending.removeFirst()
                pending.addLast(Pending(envelope, SystemClock.elapsedRealtime()))
                Log.d(TAG, "buffered $event (pending=${pending.size})")
            }
        }
    }

    private fun flush() {
        val current = sink ?: return
        val now = SystemClock.elapsedRealtime()
        while (pending.isNotEmpty()) {
            val item = pending.removeFirst()
            if (now - item.createdAt > PENDING_TTL_MS) {
                Log.d(TAG, "drop stale ${item.envelope["event"]}")
                continue
            }
            current.success(item.envelope)
        }
    }

    private inline fun onMain(crossinline block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) block() else mainHandler.post { block() }
    }
}
