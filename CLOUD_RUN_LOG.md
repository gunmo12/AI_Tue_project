# MoneyMate Cloud Run 운영 로그

## 2026-11-10 15:49 KST · 서비스 중단

프로젝트 `aitueproject`, 리전 `asia-northeast3`, 서비스 `moneymate-mobile`에 수동 확장 인스턴스 0을 적용했습니다. 마지막 배포 리비전은 `moneymate-mobile-00003-j5k`입니다. 트래픽 설정은 마지막 리비전 100%이며 별도 트래픽 태그는 없었습니다.

2026-11-10 15:49:01 KST에 외부 주소의 `GET /status`와 `POST /app-report`가 모두 HTTP 503을 반환했습니다. 재개 명령은 [인계 문서](HANDOFF.md)에 있습니다.

## Cloud Logging 요청 로그

중단 확인 직후 최근 7일을 최대 200건까지 조회했고 21건이 반환됐습니다. HTTP 200은 11건, 400은 1건, 401은 4건, 404는 3건, 405는 2건입니다. 중단 확인용 503은 위에 별도로 기록했습니다.

| 최근 요청 시간 (KST) | 심각도 | HTTP | 리비전 |
| --- | --- | --- | --- |
| 2026-11-10 15:46:01 | INFO | 200 | moneymate-mobile-00003-j5k |
| 2026-11-10 15:43:29 | INFO | 200 | moneymate-mobile-00003-j5k |
| 2026-11-10 15:33:36 | INFO | 200 | moneymate-mobile-00003-j5k |
| 2026-11-10 15:33:23 | WARNING | 401 | moneymate-mobile-00003-j5k |
| 2026-11-10 15:33:22 | WARNING | 400 | moneymate-mobile-00003-j5k |
| 2026-11-10 15:33:21 | INFO | 200 | moneymate-mobile-00003-j5k |
| 2026-11-10 15:13:50 | INFO | 200 | moneymate-mobile-00002-hj5 |
| 2026-11-10 15:13:40 | INFO | 200 | moneymate-mobile-00002-hj5 |
| 2026-11-10 15:09:30 | INFO | 200 | moneymate-mobile-00002-hj5 |
| 2026-11-10 15:06:49 | WARNING | 401 | moneymate-mobile-00002-hj5 |
| 2026-11-10 15:06:49 | INFO | 200 | moneymate-mobile-00002-hj5 |
| 2026-11-10 15:03:58 | WARNING | 404 | moneymate-mobile-00002-hj5 |
