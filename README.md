# weekly-sales-report

구글 시트 '판매관리'의 판매내역으로 지난주(월~일) 주간 매출 리포트를 만들어 슬랙 채널에 보내는 Claude 스킬입니다.

- 채널에는 `[주간 매출 리포트] 10/19(월)~10/25(일)` 한 줄만 올리고, 리포트는 그 메시지의 스레드에 댓글 1개로 답니다.
- 리포트 항목: 핵심 지표(매출·주문 건수·판매 수량·객단가), 판매채널별 매출, 매출 상위 5개 상품, 카테고리별 매출, 일별 매출 — 모두 전주 대비 증감률 포함
- 같은 첫 줄 메시지가 채널에 이미 있으면 보내지 않습니다.

## 필요한 것

- Google Drive / Google Sheets 커넥터, Slack 커넥터
- Windows PowerShell (집계 스크립트 `scripts/weekly_report.ps1`)

## 설치

### Claude Code (플러그인 마켓플레이스)

```
/plugin marketplace add hsdodo/weekly-sales-report
/plugin install weekly-sales-report@hsdodo-skills
```

### claude.ai

`weekly-sales-report.skill` 파일을 내려받아 **설정 → 기능 → 스킬**에서 업로드합니다.

## 사용 예

- "주간 매출 리포트 보내줘"
- "10/12 주 매출 리포트 슬랙에 올려줘"
