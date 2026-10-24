package dev.sintaek.voipcall.call

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * Flutter 엔진 없이 호출해야 하는 API. Android 에서는 "거절" 뿐이다.
 * (수락은 미디어를 소유한 Dart 가 호출한다 — MediaOwner 참고)
 */
class NativeCallApi(
    private val store: NativeCredentialStore,
    private val client: OkHttpClient = defaultClient,
) {
    suspend fun endCall(channelId: String): Result<Unit> = withContext(Dispatchers.IO) {
        runCatching {
            val baseUrl = store.apiBaseUrl?.trimEnd('/')
                ?: throw IllegalStateException("apiBaseUrl is not configured")
            val token = store.accessToken
                ?: throw IllegalStateException("access token is missing")

            val body = JSONObject()
                .put("isTest", store.isTestCall)
                .toString()
                .toRequestBody(JSON)

            val request = Request.Builder()
                .url("$baseUrl/calls/$channelId/end")
                .delete(body)
                .header("Authorization", "Bearer $token")
                .build()

            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) throw IOException("HTTP ${response.code}")
            }
        }
    }

    private companion object {
        val JSON = "application/json; charset=utf-8".toMediaType()

        // BroadcastReceiver.goAsync() 의 제한(약 10초) 안에 끝나도록
        val defaultClient: OkHttpClient by lazy {
            OkHttpClient.Builder()
                .callTimeout(8, TimeUnit.SECONDS)
                .build()
        }
    }
}
