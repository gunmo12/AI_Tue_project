# MoneyMate 개발 진행 기록

2026년 11월 10일 기준입니다.

## 현재 상태

- Android 앱 버전은 `1.0.3+4`입니다. Android Studio에서 이 Flutter 프로젝트를 열고 `lib/main.dart`를 실행할 수 있습니다. [APK 빌드 방법](HANDOFF.md#android-실행)
- 홈의 지출 내역 필터와 월 선택 버튼이 좁은 화면에서도 맞도록 수정했습니다.
- 리포트 상단 카드에서 Gemini 조언을 요청하고 결과를 볼 수 있습니다. 조언과 리포트의 다시 생성 버튼은 절약 플랜과 같은 보라색 스타일의 작은 버튼을 사용합니다.
- **설정 → 프로토타입 지출 → 예시 지출 선택하기**에서 일상 소비형, 절약 실천형, 쇼핑 집중형 중 하나를 선택할 수 있습니다. 선택한 달에 예시 33건을 적용하며, 다시 선택하면 이 기능으로 생성한 해당 월의 예시 세트만 교체합니다. 사용자가 직접 추가·수정한 기록과 이전 버전의 기록은 보존합니다.

## 서버 연동

- Google Cloud 프로젝트 `aitueproject`, 서울 리전 `asia-northeast3`의 Cloud Run 서비스 `moneymate-mobile`을 15:49 KST에 인스턴스 0으로 중단했습니다. 마지막 배포 리비전은 `moneymate-mobile-00003-j5k`입니다. [Cloud Run 서비스](https://console.cloud.google.com/run/detail/asia-northeast3/moneymate-mobile?project=aitueproject)
- 서버를 재개하면 앱은 별도 설정이나 기기 등록 없이 `POST /app-report`에 선택 월, 항목별 지출 합계, 전체 예산, 전월 총액을 보냅니다. 서버가 집계값을 검증한 뒤 Gemini 3.5 Flash-Lite를 호출해 조언을 반환합니다. Gemini API 키는 서버의 Secret Manager에 보관합니다. [서버 소스 및 배포 안내](server/README.md)
- 앱용 경로는 접속 코드 없이 호출할 수 있으며 앱 전용 호출 횟수 제한은 없습니다. 기존 `/report` 경로는 접속 코드가 필요합니다.
- 기본 DNS가 Cloud Run 주소를 해석하지 못하면 앱이 HTTPS DNS로 주소를 다시 조회합니다. 서버 연결에는 원래 도메인의 TLS 인증서 검증을 사용합니다.

## 검증 결과

- Flutter 정적 분석과 단위·위젯 테스트 18개가 통과했습니다.
- Android 에뮬레이터에서 예시 데이터로 실제 Gemini 응답을 받았습니다. 지출 예시를 바꾸거나 다시 적용해도 사용자 기록은 유지되고 예시가 중복되지 않는 것을 확인했습니다.
- 기존 에뮬레이터 DB가 스키마 버전 2로 갱신됐고, 디버그 앱 설치·실행과 릴리스 APK 빌드가 완료됐습니다.
- 릴리스 APK SHA-256은 `04701df8bc337038906132726c0bb5ae89273d45be24b5238e689e4b8d42afd9`입니다.

## 이어서 작업할 때

다른 컴퓨터에서 시작하는 방법과 서버 재개 명령은 [HANDOFF.md](HANDOFF.md)에 있습니다. 개발 오류와 조치는 [ERROR_LOG.md](ERROR_LOG.md)에, 서버 중단 결과와 요청 로그는 [CLOUD_RUN_LOG.md](CLOUD_RUN_LOG.md)에 있습니다. 최신 앱의 Gemini 연결은 에뮬레이터에서 확인했습니다. 실제 휴대폰에서의 확인은 아직 기록되지 않았습니다.
