# 서버 계약 (클라이언트 관점)

서버는 이 저장소에 포함되어 있지 않다. 클라이언트가 기대하는 REST API 와 푸시 payload 를 정리한다.
Dart(`CallApi`), Android(`NativeCallApi`), iOS(`CallApiClient`) 세 곳이 같은 계약을 쓴다.

## REST

모든 요청은 `Authorization: Bearer <accessToken>`. 응답은 공통 envelope:

```json
{ "success": true, "code": null, "message": null, "data": { } }
```

| 메서드 | 경로 | 호출 주체 | body | data |
|---|---|---|---|---|
| `POST` | `/calls` | Dart (발신) | `{ calleeId, callerDeviceUid, isTest }` | `{ channelId, token }` |
| `PATCH` | `/calls/{channelId}/accept` | Android: Dart / iOS: 네이티브 | `{ acceptorToken }` | – |
| `DELETE` | `/calls/{channelId}/end` | 종료: Dart / 거절: 네이티브 | `{ isTest }` | `{ duration }` (초) |

- `token`: 발신자용 Agora RTC 토큰. 수신자 토큰은 `CALL_START` 푸시에 실려 온다.
- `acceptorToken`: 수락한 기기의 푸시 토큰 (Android = FCM, iOS = PushKit VoIP).
  서버는 이 기기를 **제외한** 수신자의 다른 기기에 `STOP_RINGING` 을 보낸다.
- `callerDeviceUid`: 발신 기기 식별자. 같은 계정으로 로그인한 발신자의 다른 기기는 울리지 않게 한다.
- `end` 는 통화 상태와 무관하게 멱등이어야 한다. 양쪽이 거의 동시에 끊으면 두 번 호출된다.
- 에러 코드 `CALLER_TOKEN_NOT_FOUND`: 발신자의 푸시 토큰이 서버에 없음 → 상대가 받아도 `CALL_ACCEPTED` 를 돌려줄 수 없으므로 발신 자체를 거절.

## 푸시

### 타입과 수신자

| type | 받는 쪽 | Android | iOS |
|---|---|---|---|
| `CALL_START` | 수신자의 모든 기기 | FCM data, `priority: high` | **VoIP 푸시 (PushKit)** |
| `CALL_ACCEPTED` | 발신자 | FCM data | FCM (일반 APNs) |
| `STOP_RINGING` | 수신자의 (수락 기기를 제외한) 기기 | FCM data | FCM (일반 APNs) |
| `CALL_END` | 상대방 | FCM data | FCM (일반 APNs) |

iOS 에서 VoIP 푸시는 `CALL_START` 에만 쓴다. iOS 13 부터 VoIP 푸시를 받으면 **반드시** CallKit 에
통화를 리포트해야 하고, 지키지 않으면 앱이 종료되며 반복되면 VoIP 푸시 전달이 중단된다.
제어 메시지까지 VoIP 로 보내면 "리포트할 통화가 없는 VoIP 푸시"가 생기므로 일반 푸시로 보낸다.
(클라이언트는 방어적으로 이 경우도 처리한다 — `CallKitController.reportAndEndImmediately`)

### payload

```jsonc
// CALL_START (Android: FCM data — 모든 값이 문자열)
{
  "type": "CALL_START",
  "channelId": "c0a8012e-...",
  "callerId": "12",
  "calleeId": "34",
  "callerName": "김선생",
  "rtcToken": "007eJx..."   // 수신자(calleeId)용 Agora 토큰
}

// CALL_START (iOS: VoIP 푸시 — data 아래에 두거나 최상위에 둬도 됨)
{
  "aps": {},
  "data": { "type": "CALL_START", "channelId": "...", "callerId": 12, "calleeId": 34, "callerName": "김선생", "rtcToken": "..." }
}

// STOP_RINGING / CALL_END / CALL_ACCEPTED
{ "type": "STOP_RINGING", "channelId": "...", "reason": "answeredElsewhere" }
```

`reason` (선택): `cancelled` · `answeredElsewhere` · `declined` · `remoteHangup` · `noAnswer`.
없으면 `STOP_RINGING` → `cancelled`, `CALL_END` → `remoteHangup` 으로 본다.

### iOS VoIP 푸시 전송 헤더

```
apns-push-type: voip
apns-topic: <bundle id>.voip
apns-priority: 10
apns-expiration: 0      // 지난 통화가 뒤늦게 울리지 않도록
```

Development 프로비저닝 프로파일로 서명된 빌드는 sandbox VoIP 토큰을 받는다.
서버가 production APNs 로 보내면 전달되지 않으므로, TestFlight/App Store 빌드는 Distribution 프로파일로 서명돼야 한다.
