# 푸시할 때 요약을 커밋 메시지와 컨플루언스에 기록하기

`scripts/push-with-summary.sh` 한 번이면 아래가 순서대로 실행됩니다.

1. 바뀐 내용(파일 목록 + diff)을 모은다.
2. Claude 로 한국어 요약을 만든다. 첫 줄은 커밋 제목, 아래는 항목.
3. 그 요약을 **커밋 메시지**로 커밋하고 푸시한다.
4. 같은 요약을 컨플루언스 문서 **맨 위**에 `날짜 · 저장소 · 커밋` 제목으로 붙인다. 이전 기록은 그대로 남는다.

```bash
scripts/push-with-summary.sh            # 실제 실행
scripts/push-with-summary.sh --dry-run  # 요약만 확인 (커밋·푸시·기록 안 함)
```

## 한 번만 준비
컨플루언스 토큰(scope: `read:page:confluence`, `write:page:confluence`)을 키체인에 넣어 둡니다.
토큰은 이 컴퓨터에만 있고 GitHub 에는 올라가지 않습니다.

```bash
security add-generic-password -s confluence-history -a "<컨플루언스 이메일>" -w
```

(`-w` 뒤를 비워 두면 토큰을 안전하게 입력하라고 묻습니다.)

## 바꿔 쓰는 값
환경변수로 덮어쓸 수 있습니다. 기본값은 스크립트 위쪽에 있습니다.

| 변수 | 의미 |
|---|---|
| `CONF_PAGE_ID` | 기록할 문서 ID |
| `CONF_CLOUD_ID` | 사이트 cloudId (`https://<사이트>.atlassian.net/_edge/tenant_info`) |
| `CONF_EMAIL` / `CONF_TOKEN` | 키체인 대신 직접 지정 |

## 동작 규칙
- 토큰이 없으면 컨플루언스 기록만 건너뛰고 커밋·푸시는 진행합니다.
- Claude 가 없거나 실패하면 변경 파일 목록으로 대신합니다.
- 이미지(png·jpg)와 `dist/`는 요약 대상에서 뺍니다. diff 가 길면 앞부분만 씁니다.
- 변경이 이미 커밋돼 있고 푸시만 남았으면, 새 커밋 없이 그 범위를 요약해 기록만 합니다.
- 기록 중 다른 사람이 같은 문서를 먼저 고치면(409) 한 번 다시 읽어서 재시도합니다.
- `git add -A` 로 전부 담으므로, 올리지 않을 파일은 `.gitignore` 에 넣어 두세요.
