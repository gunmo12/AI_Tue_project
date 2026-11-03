# 소비 어시스턴트 Android

기존 소비 분석 웹 프로토타입을 UPsist와 같은 Flutter 방식의 안드로이드 앱으로 옮긴 V1입니다. PC·Python 서버·인터넷 연결 없이 휴대폰에서 지출과 예산을 기록하고 분석합니다. 사용자 제공 Figma의 연보라 배경, 흰 카드, 원본 SVG 아이콘과 다섯 개 하단 메뉴를 반영했습니다.

## 휴대폰에서 실행

1. 함께 제공한 `spending-assistant-android.apk`를 안드로이드 휴대폰으로 복사합니다.
2. 휴대폰에서 APK를 열어 설치합니다. 휴대폰이 해당 파일 앱의 설치 허용을 요구하면 사용자가 직접 확인합니다.
3. 앱 목록에서 **소비 어시스턴트**를 엽니다.

이 APK는 검증을 위한 테스트 서명으로 빌드합니다. Google Play 배포 전용 서명·스토어 등록은 포함하지 않습니다. 기존 UPsist와 앱 ID가 달라 별도로 설치됩니다. 프로젝트에는 서명 키를 포함하지 않습니다.

## 기능

- 홈: 월 선택, 총지출·남은 예산·사용률, 카테고리별 도넛, 7일 구간별 추이, 검색·필터
- 지출: 날짜·금액·항목·사용처·메모·직접 확인한 반복 결제 입력, 수정, 확인 후 삭제
- 분석: 항목별 금액·비중, 최근 4개월 비교, 주간 소비 추이
- 리포트: 실제 저장 내역의 집계 설명, 예산 현황, 반복 결제 조회, 절약 가정 조정, 이전 리포트의 갱신 필요 안내
- 예산: 월별 전체·항목별 한도, 90% 이상 주의 및 100% 초과 표시, 날짜별 내역 조회
- 설정: 이름 변경, 선택 월 CSV 저장, 확인 문구 입력 후 전체 초기화

CSV는 안드로이드의 파일 저장 창에서 사용자가 선택한 위치에 저장합니다. 저장소 전체 접근 권한을 요청하지 않습니다. CSV는 지출 내보내기이며 예산·리포트 백업과 가져오기는 포함하지 않습니다.

## 저장과 예시 데이터

SQLite DB는 앱 전용 저장소의 `spending-assistant.db`에 저장됩니다. 앱 종료 후에도 유지됩니다. 앱 삭제 또는 데이터 초기화 시 지워집니다. Android 시스템 자동 백업은 비활성화했습니다.

첫 실행 때 기기 날짜의 현재 월에 가상 지출 33건과 지난달 비교용 6건을 만듭니다. 현재 월 합계 862,000원, 예산 1,100,000원, 잔여 238,000원, 사용률 78.4%입니다. 쇼핑 190,000 / 200,000원은 95.0% 주의입니다. 월말까지 가상 날짜가 포함되므로 실제 소비로 해석하지 마세요. 설정에서 초기화하면 예시를 다시 자동 생성하지 않습니다.

## 계산과 AI 범위

금액은 정수 원 단위, 비율은 소수점 첫째 자리로 표시합니다. 경계 판정에는 반올림 전 금액을 사용합니다. 예산 0원은 미설정이며 사용률을 만들지 않습니다. 비교 가능한 이전 기록이 없으면 증감률을 만들지 않습니다.

월 비교는 각 월의 1일~말일까지 저장된 전체 내역 비교입니다. 월말 예측이나 같은 경과일 비교가 아닙니다. 카페 예상 절약액은 평균 결제액(원 단위 반올림) × 줄일 횟수이며, 주당 횟수와 주 수를 표시하고 현재 월 카페 기록 건수 이내로 제한합니다. 절약 보장이나 자동 구독 판단이 아닙니다.

사용자 선택에 따라 **AI API는 연결하지 않았습니다.** 화면에 ‘계산 기반 리포트 · AI API 미연결’을 표시합니다. 실제 결제·계좌 연동·구독 해지·소비 내역의 외부 전송은 없습니다. 소득·저축액이 없으므로 Figma의 저축률 표시는 예산 사용률로 바꿨습니다.

## 개발 실행

Flutter SDK와 Android SDK/JDK가 설치된 환경에서 Android Studio로 프로젝트 폴더를 열거나 아래 명령을 실행합니다. 정확한 의존성은 `pubspec.lock`에 고정되어 있습니다.

```powershell
flutter pub get
flutter run -d <기기ID>
flutter build apk --release
```

`android/local.properties`는 컴퓨터별 SDK 경로이므로 소스 ZIP에서 제외합니다. Flutter 명령 또는 Android Studio가 현재 컴퓨터의 경로로 생성합니다.

```powershell
flutter analyze
flutter test
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart -d <에뮬레이터ID>
```

통합 테스트는 별도 `integration-validation.db`를 사용합니다. 실제 사용자 DB는 초기화하지 않습니다. 에뮬레이터 테스트용 DB만 만들고 제거합니다.

## 코드

| 파일 | 역할 |
| --- | --- |
| `lib/main.dart` | 네 화면 및 설정, 월 조회와 표시 |
| `lib/editors.dart` | 지출·예산 입력창, 확인 대화상자, CSV 요청 |
| `lib/domain.dart` | 검증, 정수 집계, 예산 상태, 리포트 규칙 |
| `lib/repository.dart` | SQLite 저장·조회 및 최초 예시 데이터 |
| `lib/design.dart` | Figma 스타일, 원본 SVG, 데이터 기반 그래프 |
| `android/.../MainActivity.kt` | 안드로이드 파일 저장 창과 CSV 저장 |
| `test/` | 계산 및 입력 위젯 테스트 |
| `integration_test/` | 기기 SQLite·화면 전환 통합 검증 |

디자인: [사용자 제공 Figma](https://www.figma.com/design/YuKoDuhQTehOZmlYQngVeG?node-id=4-593)

구현 참고: [Flutter의 SQLite 저장](https://docs.flutter.dev/cookbook/persistence/sqlite), [Android APK 빌드](https://docs.flutter.dev/deployment/android)
