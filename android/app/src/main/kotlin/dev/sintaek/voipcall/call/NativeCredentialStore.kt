package dev.sintaek.voipcall.call

import android.content.Context
import androidx.core.content.edit

/**
 * Flutter 가 MethodChannel 로 내려준 설정/세션.
 *
 * 알림의 "거절" 버튼은 Flutter 엔진 없이 처리되므로(앱 프로세스만 잠깐 깨어남)
 * 네이티브가 서버를 호출할 수 있도록 디스크에 보관한다.
 *
 * 실서비스 버전은 서버가 푸시 payload 에 액세스 토큰을 실어 보냈는데,
 * 토큰이 푸시 경로(FCM/APNs, 로그)에 노출되는 구조라 앱이 직접 동기화하는 방식으로 바꿨다.
 */
class NativeCredentialStore(context: Context) {
    private val prefs = context.applicationContext
        .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    var apiBaseUrl: String?
        get() = prefs.getString(KEY_BASE_URL, null)
        set(value) = prefs.edit { putString(KEY_BASE_URL, value) }

    var isTestCall: Boolean
        get() = prefs.getBoolean(KEY_IS_TEST_CALL, true)
        set(value) = prefs.edit { putBoolean(KEY_IS_TEST_CALL, value) }

    var accessToken: String?
        get() = prefs.getString(KEY_ACCESS_TOKEN, null)
        set(value) = prefs.edit {
            if (value.isNullOrEmpty()) remove(KEY_ACCESS_TOKEN) else putString(KEY_ACCESS_TOKEN, value)
        }

    private companion object {
        const val PREFS_NAME = "voip_call_native"
        const val KEY_BASE_URL = "api_base_url"
        const val KEY_IS_TEST_CALL = "is_test_call"
        const val KEY_ACCESS_TOKEN = "access_token"
    }
}
