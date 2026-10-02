#!/usr/bin/env bash
# 수정한 내용을 Claude 로 정리해서 ① 커밋 메시지로 쓰고 ② 푸시하고 ③ 컨플루언스 문서 맨 위에 기록한다.
#
#   scripts/push-with-summary.sh            # 변경 → 요약 → 커밋 → 푸시 → 컨플루언스 기록
#   scripts/push-with-summary.sh --dry-run  # 요약만 만들어 보여 준다 (커밋·푸시·기록 안 함)
#
# 필요한 것
#   - claude CLI (Claude Code). 없거나 실패하면 변경 파일 목록으로 대신한다.
#   - 컨플루언스 기록용 환경변수 (없으면 기록만 건너뛴다. 커밋·푸시는 그대로 진행)
#       CONF_EMAIL   컨플루언스 계정 이메일
#       CONF_TOKEN   scope 가 있는 API 토큰 (read:page, write:page)
#     환경변수가 없으면 macOS 키체인 항목 'confluence-history'에서 읽는다. (docs/confluence-history.md)
#
# 토큰은 이 컴퓨터에서만 쓰이고 GitHub 에는 올라가지 않는다.

set -euo pipefail

CLOUD_ID="${CONF_CLOUD_ID:-0850dd06-9c58-45c0-96ed-4ce246429c84}"
PAGE_ID="${CONF_PAGE_ID:-815137714}"
API="https://api.atlassian.com/ex/confluence/${CLOUD_ID}/wiki/api/v2/pages/${PAGE_ID}"

DRY=0
[[ "${1:-}" == "--dry-run" ]] && DRY=1

cd "$(git rev-parse --show-toplevel)"
REPO_NAME="$(basename "$(git rev-parse --show-toplevel)")"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ── 1) 무엇이 바뀌었는지 모으기 ───────────────────────────────
DIRTY=0
if [[ -n "$(git status --porcelain)" ]]; then
  DIRTY=1
  git add -A
  git diff --cached --stat >"$TMP/stat.txt"
  git diff --cached -U2 -- . ':(exclude)dist/*' ':(exclude)*.png' ':(exclude)*.jpg' ':(exclude)*.jpeg' ':(exclude)*.lock' >"$TMP/diff.txt" || true
else
  UPSTREAM="$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null || true)"
  if [[ -z "$UPSTREAM" ]] || [[ -z "$(git log "${UPSTREAM}..HEAD" --oneline)" ]]; then
    echo "올릴 변경이 없습니다."
    exit 0
  fi
  git diff --stat "${UPSTREAM}..HEAD" >"$TMP/stat.txt"
  git diff -U2 "${UPSTREAM}..HEAD" -- . ':(exclude)dist/*' ':(exclude)*.png' ':(exclude)*.jpg' ':(exclude)*.jpeg' >"$TMP/diff.txt" || true
fi
# 너무 길면 앞부분만 쓴다.
head -c 60000 "$TMP/diff.txt" >"$TMP/diff-cut.txt"

# ── 2) Claude 로 정리 ─────────────────────────────────────────
PROMPT='아래는 git 변경 내용(파일 목록과 diff)이다. 디자인팀 동료가 읽을 변경 요약을 한국어로 써라.
형식:
- 첫 줄: 커밋 제목 한 줄(50자 이내, 마침표 없음)
- 빈 줄
- 그다음 "- "로 시작하는 항목 2~6개. 사용자가 체감하는 변화를 먼저, 내부 정리는 짧게.
코드 용어는 꼭 필요할 때만 쓴다. 추측하지 말고 diff에 있는 내용만 쓴다. 다른 설명이나 머리말은 쓰지 않는다.'

SUMMARY=""
if command -v claude >/dev/null 2>&1; then
  { cat "$TMP/stat.txt"; echo; cat "$TMP/diff-cut.txt"; } >"$TMP/input.txt"
  SUMMARY="$(claude -p "$PROMPT" <"$TMP/input.txt" 2>/dev/null || true)"
fi
if [[ -z "${SUMMARY//[[:space:]]/}" ]]; then
  echo "(Claude 요약을 만들지 못해 변경 파일 목록으로 대신합니다)"
  SUMMARY="$(printf '업데이트: %s\n\n' "$(date '+%Y-%m-%d')"; sed 's/^/- /' "$TMP/stat.txt" | head -20)"
fi
printf '%s\n' "$SUMMARY" >"$TMP/summary.txt"
SUBJECT="$(head -n 1 "$TMP/summary.txt")"

echo "──────── 요약 ────────"
cat "$TMP/summary.txt"
echo "──────────────────────"

if [[ $DRY -eq 1 ]]; then
  [[ $DIRTY -eq 1 ]] && git reset -q
  echo "(dry-run: 커밋·푸시·기록 안 함)"
  exit 0
fi

# ── 3) 커밋 → 푸시 ───────────────────────────────────────────
if [[ $DIRTY -eq 1 ]]; then
  git commit -q -F "$TMP/summary.txt"
fi
git push -q origin "$BRANCH"
HASH="$(git rev-parse --short HEAD)"
echo "푸시 완료: ${HASH} (${BRANCH})"

# ── 4) 컨플루언스 문서 맨 위에 기록 ──────────────────────────
# 환경변수가 없으면 macOS 키체인(항목 이름: confluence-history)에서 읽는다.
if [[ -z "${CONF_TOKEN:-}" ]] && command -v security >/dev/null 2>&1; then
  CONF_TOKEN="$(security find-generic-password -s confluence-history -w 2>/dev/null || true)"
  if [[ -z "${CONF_EMAIL:-}" ]]; then
    CONF_EMAIL="$(security find-generic-password -s confluence-history 2>/dev/null | sed -n 's/.*"acct"<blob>="\(.*\)"/\1/p' || true)"
  fi
  export CONF_TOKEN CONF_EMAIL
fi
if [[ -z "${CONF_EMAIL:-}" || -z "${CONF_TOKEN:-}" ]]; then
  echo "CONF_EMAIL / CONF_TOKEN 이 없어 컨플루언스 기록은 건너뜁니다."
  exit 0
fi

export TMP API HASH REPO_NAME BRANCH
python3 - <<'PY'
import base64, datetime, html, json, os, sys, urllib.error, urllib.request

tmp, api = os.environ["TMP"], os.environ["API"]
auth = base64.b64encode(f"{os.environ['CONF_EMAIL']}:{os.environ['CONF_TOKEN']}".encode()).decode()
headers = {"Authorization": f"Basic {auth}", "Content-Type": "application/json", "Accept": "application/json"}


def call(url, data=None, method="GET"):
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    with urllib.request.urlopen(req, timeout=30) as res:
        return json.load(res)


lines = open(f"{tmp}/summary.txt", encoding="utf-8").read().strip().splitlines()
subject = lines[0].strip()
items = [l[2:].strip() for l in lines[1:] if l.strip().startswith("- ")]
now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
block = f"<h3>{html.escape(now)} · {html.escape(os.environ['REPO_NAME'])} · {html.escape(os.environ['HASH'])}</h3>"
block += f"<p><strong>{html.escape(subject)}</strong></p>"
if items:
    block += "<ul>" + "".join(f"<li>{html.escape(i)}</li>" for i in items) + "</ul>"

for attempt in range(2):
    try:
        page = call(f"{api}?body-format=storage")
        body = page["body"]["storage"]["value"]
        payload = {
            "id": page["id"],
            "status": "current",
            "title": page["title"],
            "version": {"number": page["version"]["number"] + 1},
            "body": {"representation": "storage", "value": block + body},
        }
        call(api, json.dumps(payload).encode(), "PUT")
        print("컨플루언스 기록 완료")
        break
    except urllib.error.HTTPError as e:
        # 누가 그 사이에 문서를 고쳤다면(409) 다시 읽어서 한 번만 재시도한다.
        if e.code == 409 and attempt == 0:
            continue
        print(f"컨플루언스 기록 실패: HTTP {e.code} {e.read().decode()[:300]}", file=sys.stderr)
        sys.exit(0)
PY
