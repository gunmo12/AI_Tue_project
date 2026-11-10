# MoneyMate Cloud Run 리포트 서버

Cloud Run **서비스**에 소스로 배포하는 독립 서버입니다. 모델 호출에는 Gemini Developer API를 사용합니다. 기존 서비스가 이 프로젝트 전용이면 서비스 이름과 리전을 그대로 사용하세요. 이미 다른 앱이 사용하는 서비스라면 별도 서비스를 사용하세요. 소스 배포는 서비스에 새 리비전을 만듭니다.

`POST /report`는 Android 앱의 6개 항목에 맞춰 월별 집계값만 받습니다. 서버가 합계, 잔여 예산, 예산 사용률, 전월 증감을 계산합니다. Gemini는 집계에 맞는 조언을 후보에서 선택합니다. 따라서 금액과 조언의 숫자를 모델이 직접 생성하는 구조를 피합니다. `GET /status`는 서버 기동 여부를 확인합니다.

## Cloud Run에 적용

1. ZIP을 풀고 Cloud Shell에서 `Dockerfile`이 있는 폴더로 이동합니다.
2. Secret Manager의 `moneymate-gemini-key`에 Google AI Studio에서 발급한 Gemini API 키를 저장합니다. `moneymate-mobile-access`에는 `openssl rand -hex 32`로 생성한 64자리 접속 코드(줄바꿈 제외)를 저장합니다. Cloud Run 서비스 계정에 이 두 보안 비밀의 **Secret Manager Secret Accessor** 역할을 부여합니다. 아래 `:1`은 실제 버전 번호로 바꿉니다.
3. 아래의 프로젝트 ID, 서비스 이름, 리전, 서비스 계정 이메일을 자신의 값으로 바꿉니다. 예시 모델 `gemini-3.5-flash-lite`는 Gemini Developer API에서 구조화 출력을 지원하는 모델 ID로 변경할 수 있습니다.

```bash
PROJECT_ID='YOUR_PROJECT_ID'
SERVICE='YOUR_CLOUD_RUN_SERVICE'
REGION='YOUR_SERVICE_REGION'
SERVICE_ACCOUNT='YOUR_RUNTIME_SERVICE_ACCOUNT_EMAIL'

gcloud run deploy "$SERVICE" \
  --project "$PROJECT_ID" --region "$REGION" --source . \
  --service-account "$SERVICE_ACCOUNT" \
  --no-invoker-iam-check \
  --cpu-throttling --min 0 --max 1 --concurrency 1 --timeout 45s \
  --update-env-vars 'GEMINI_MODEL=gemini-3.5-flash-lite' \
  --update-secrets 'GEMINI_API_KEY=moneymate-gemini-key:1,MONEYMATE_ACCESS_CODE=moneymate-mobile-access:1'
```

API 키 값은 Cloud Shell 명령이나 파일에 입력할 필요가 없습니다. `.gcloudignore`와 `.dockerignore`는 빌드에 필요한 파일만 포함합니다.

현재 Android 앱은 공개 `POST /app-report` 경로를 사용합니다. 월별 집계 형식을 검증한 뒤 Gemini를 호출합니다. 기존 클라이언트용 `POST /report`는 접속 코드를 검증합니다. 최대 인스턴스와 동시 요청 수는 처리량 설정이며 Gemini 요금 상한을 설정하지 않습니다.

이전 Claude 패치를 이미 배포했다면 Gemini 호출을 확인한 뒤 Cloud Run의 변수 및 보안 비밀 설정에서 이전 환경변수 매핑(`CLAUDE_MODEL`, `ANTHROPIC_WORKSPACE_ID`, `ANTHROPIC_API_KEY`)을 제거할 수 있습니다.

## Cloud Shell에서 확인

접속 코드 보안 비밀에 접근할 수 있는 계정으로 실행합니다. 마지막 요청에서 실제 Gemini API 사용량이 발생할 수 있습니다.

```bash
URL=$(gcloud run services describe "$SERVICE" --project "$PROJECT_ID" \
  --region "$REGION" --format='value(status.url)')

curl --fail-with-body -sS "$URL/status"

CODE=$(gcloud secrets versions access 1 --secret=moneymate-mobile-access --project="$PROJECT_ID")
printf 'Authorization: Bearer %s\n' "$CODE" | curl --fail-with-body -sS -H @- \
  -H 'Content-Type: application/json' \
  --data-binary @sample-report.json "$URL/report"
unset CODE
```

응답에서 `mode: "gemini"`를 확인해야 실제 모델 호출이 성공한 것입니다. `mode: "rules"`는 기본 조언으로 응답했다는 뜻입니다. `reason`은 `model_not_configured`(키나 모델 설정 누락), `model_unavailable`(API 오류, 지연 또는 응답 검증 실패), `no_spending`(분석할 지출 없음) 중 하나입니다. 모델 오류에 대한 자동 재호출은 하지 않습니다. `sample-report.json`의 계산값은 총지출 862,000원, 잔여 238,000원, 예산 사용률 78.4%, 전월 대비 -63,000원입니다.

## Flutter 연동 계약

- `POST /report`, `Content-Type: application/json`, 최대 8 KiB, `Content-Length` 필요
- `month`는 `YYYY-MM`, `category_totals_won`은 `식비`, `교통`, `쇼핑`, `구독`, `카페`, `기타`의 원 단위 정수 합계입니다. 생략된 항목은 0원으로 처리합니다.
- `budget_won`, `previous_total_won`은 선택입니다. `previous_total_won`에는 같은 기준으로 집계한 비교 가능한 전월 합계만 보냅니다. 전월 데이터가 없거나 0원이면 증감률은 `null`입니다.
- 응답의 `facts`에는 계산된 수치가, `advice`에는 표시할 조언이 들어갑니다. `mode`를 사용해 AI와 규칙 응답을 구분할 수 있습니다.
- Android 앱은 `POST /app-report`를 호출하며 기기 등록이 필요 없습니다.

로컬 테스트는 `python -m unittest -v`로 실행합니다. 모의 Gemini 응답을 사용하며 실제 키가 필요 없습니다.

[Cloud Run 소스 배포](https://docs.cloud.google.com/run/docs/deploying-source-code) · [Secret Manager 연동](https://docs.cloud.google.com/run/docs/configuring/services/secrets) · [Gemini API 키](https://ai.google.dev/gemini-api/docs/api-key) · [Gemini 3.5 Flash-Lite](https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash-lite)
