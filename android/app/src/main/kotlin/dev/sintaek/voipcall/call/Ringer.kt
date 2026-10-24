package dev.sintaek.voipcall.call

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * 수신 벨소리 + 진동.
 *
 * 벨은 IncomingCallService 한 곳에서만 울린다. 알림 채널 사운드는 끄고(setSound(null)),
 * 전체화면 Activity 도 따로 울리지 않는다. 여러 곳에서 각자 울리면 정지 시점이 어긋나
 * 통화를 받은 뒤에도 벨이 남는 문제가 생긴다.
 */
class Ringer(context: Context) {
    private val appContext = context.applicationContext
    private val audioManager = appContext.getSystemService(AudioManager::class.java)
    private val vibrator: Vibrator? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            appContext.getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            appContext.getSystemService(Vibrator::class.java)
        }

    private var ringtone: Ringtone? = null

    fun start() {
        stop()
        // 사용자의 벨소리 모드를 따른다: 무음이면 화면/알림만.
        when (audioManager?.ringerMode) {
            AudioManager.RINGER_MODE_NORMAL -> {
                playRingtone()
                vibrate()
            }
            AudioManager.RINGER_MODE_VIBRATE -> vibrate()
            else -> Unit
        }
    }

    fun stop() {
        ringtone?.stop()
        ringtone = null
        vibrator?.cancel()
    }

    private fun playRingtone() {
        val uri = RingtoneManager.getActualDefaultRingtoneUri(appContext, RingtoneManager.TYPE_RINGTONE)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        ringtone = RingtoneManager.getRingtone(appContext, uri)?.apply {
            audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) isLooping = true
            play()
        }
    }

    private fun vibrate() {
        val vibrator = vibrator ?: return
        val pattern = longArrayOf(0, 1000, 1000)
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU ->
                // USAGE_RINGTONE 으로 지정해야 방해금지/진동 강도 설정이 "전화" 기준으로 적용된다.
                vibrator.vibrate(
                    VibrationEffect.createWaveform(pattern, 0),
                    VibrationAttributes.createForUsage(VibrationAttributes.USAGE_RINGTONE),
                )
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O ->
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, 0))
            else ->
                @Suppress("DEPRECATION")
                vibrator.vibrate(pattern, 0)
        }
    }
}
