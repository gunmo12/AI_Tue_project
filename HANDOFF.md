# MoneyMate 다른 컴퓨터에서 이어서 작업하기

2026년 11월 10일 기준으로 Android 앱 버전은 `1.0.3+4`이며 Cloud Run은 중단되어 있습니다. 같은 Google Cloud 프로젝트에서 기존 서비스를 재개할 수 있습니다.

## Android 실행

~~~powershell
git clone https://github.com/gunmo12/AI_Tue_project.git
cd AI_Tue_project
flutter pub get
flutter analyze
flutter test
~~~

저장소에 접근할 수 있는 GitHub 계정으로 클론합니다. Android Studio에서 저장소 루트를 열고 Flutter SDK와 Android SDK를 지정한 다음, 에뮬레이터나 연결된 휴대폰에서 `lib/main.dart`를 실행합니다. 기존 장부는 해당 기기의 앱 전용 SQLite에 있습니다.

APK는 저장소 루트에서 `flutter build apk --release`로 빌드합니다. 결과는 `build/app/outputs/flutter-apk/app-release.apk`입니다. 다른 컴퓨터에서 만든 테스트 서명 APK는 서명이 다르면 기존 앱 위에 설치할 수 없습니다.

## Gemini 서버 재개

`aitueproject`에 접근할 수 있는 계정으로 Google Cloud Shell을 열고 실행합니다.

~~~bash
gcloud run services update moneymate-mobile --project=aitueproject --region=asia-northeast3 --scaling=auto
curl -fsS https://moneymate-mobile-693983780937.asia-northeast3.run.app/status
~~~

`/status`가 `{"status":"ok"}`를 반환하면 앱에서 **리포트 → Gemini 조언 받기**를 확인합니다. 서버 주소는 앱에 설정돼 있고 Gemini API 키는 기존 리비전이 Secret Manager의 `moneymate-gemini-key`에서 읽습니다. 서버 변경이 필요하면 [서버 배포 안내](server/README.md)를 참고합니다.

다시 중단하려면 Cloud Shell에서 실행합니다.

~~~bash
gcloud run services update moneymate-mobile --project=aitueproject --region=asia-northeast3 --scaling=0
~~~

중단 상태에서는 Gemini 요청이 실패합니다. 지출·예산 기록과 기기에서 계산하는 리포트는 사용할 수 있습니다.

## 기록과 서버 소스

- [진행사항](PROGRESS.md)
- [개발 오류와 해결 과정](ERROR_LOG.md)
- [Cloud Run 중단 및 요청 로그](CLOUD_RUN_LOG.md)
- [서버 소스](server/)에는 Dockerfile, Python API, 테스트와 예시 요청이 있습니다. 서버 테스트는 이 폴더에서 `python -B -m unittest -v`로 실행합니다.
