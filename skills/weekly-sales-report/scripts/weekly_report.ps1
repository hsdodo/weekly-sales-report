# 판매내역 행(TSV)으로 주간 매출 리포트(슬랙 스레드용 마크다운)를 만든다.
# 입력 TSV 열 순서: 주문일, 주문번호, 판매채널, 카테고리, 상품명, 옵션, 수량, 판매단가, 결제금액 (시트 A:I 그대로, 헤더 행 있어도 됨)
# 사용: powershell -File weekly_report.ps1 -In rows.tsv -WeekStart 2026-10-19 -Out report.md
param(
  [Parameter(Mandatory)][string]$In,
  [Parameter(Mandatory)][string]$WeekStart,   # 리포트 주의 월요일 (yyyy-MM-dd)
  [Parameter(Mandatory)][string]$Out
)
$ErrorActionPreference = 'Stop'
$ws = [datetime]::ParseExact($WeekStart, 'yyyy-MM-dd', $null)
$we = $ws.AddDays(6); $ps = $ws.AddDays(-7); $pe = $ws.AddDays(-1)
$fmt = 'yyyy-MM-dd'
$days = '일','월','화','수','목','금','토'
function Label($d) { "$($d.Month)/$($d.Day)($($days[[int]$d.DayOfWeek]))" }
function Num($s) { [long](($s -replace '[^\d\-]', '')) }

$rows = foreach ($line in Get-Content -Encoding UTF8 $In) {
  if (-not $line.Trim()) { continue }
  $f = $line -split "`t"
  if ($f[0] -notmatch '^\d{4}-\d{2}-\d{2}$') { continue }   # 헤더·빈 줄 건너뜀
  [pscustomobject]@{ D=$f[0]; O=$f[1]; Ch=$f[2]; Cat=$f[3]; P=$f[4]; Q=(Num $f[6]); A=(Num $f[8]) }
}
$cur  = @($rows | Where-Object { $_.D -ge $ws.ToString($fmt) -and $_.D -le $we.ToString($fmt) })
$prev = @($rows | Where-Object { $_.D -ge $ps.ToString($fmt) -and $_.D -le $pe.ToString($fmt) })
if ($cur.Count -eq 0) { throw "리포트 주($($ws.ToString($fmt))~$($we.ToString($fmt))) 데이터가 없습니다." }
if ($prev.Count -eq 0) { Write-Warning "전주 데이터가 없어 증감률을 '-'로 표시합니다." }

function Kpi($r) {
  $s = [long](($r | Measure-Object A -Sum).Sum); $q = [long](($r | Measure-Object Q -Sum).Sum)
  $o = @($r | Select-Object -ExpandProperty O -Unique).Count
  @{ Sales=$s; Orders=$o; Qty=$q; AOV=$(if ($o) { [math]::Round($s / $o) } else { 0 }) }
}
function Sum($r, $key) { $h = @{}; foreach ($x in $r) { $h[$x.$key] = [long]$h[$x.$key] + $x.A }; $h }
function Won($n) { '{0:N0}원' -f $n }
function Pct($c, $p) {
  if (-not $p) { return '-' }
  $v = ($c - $p) / $p * 100
  if ([math]::Round($v, 1) -eq 0) { return '0.0%' }
  $(if ($v -gt 0) { '▲ ' } else { '▼ ' }) + ('{0:N1}%' -f [math]::Abs($v))
}
function Share($n, $t) { '{0:N1}%' -f ($n / $t * 100) }

$kc = Kpi $cur; $kp = Kpi $prev; $total = $kc.Sales
$o = @()
$o += "**📊 핵심 지표** (전주 $(Label $ps)~$(Label $pe) 대비)"
$o += '| 지표 | 지난주 | 전주 대비 |'
$o += '|---|---|---|'
$o += "| 총 매출 | $(Won $kc.Sales) | $(Pct $kc.Sales $kp.Sales) |"
$o += "| 주문 건수 | $($kc.Orders)건 | $(Pct $kc.Orders $kp.Orders) |"
$o += "| 판매 수량 | $($kc.Qty)개 | $(Pct $kc.Qty $kp.Qty) |"
$o += "| 객단가 | $(Won $kc.AOV) | $(Pct $kc.AOV $kp.AOV) |"

$c = Sum $cur 'Ch'; $p = Sum $prev 'Ch'
$o += ''; $o += '**🏪 판매채널별 매출**'
$o += '| 채널 | 매출 | 비중 | 전주 대비 |'; $o += '|---|---|---|---|'
foreach ($k in ($c.Keys | Sort-Object { -$c[$_] })) { $o += "| $k | $(Won $c[$k]) | $(Share $c[$k] $total) | $(Pct $c[$k] $p[$k]) |" }

$c = Sum $cur 'P'; $p = Sum $prev 'P'
$qty = @{}; foreach ($x in $cur) { $qty[$x.P] = [long]$qty[$x.P] + $x.Q }
$o += ''; $o += '**🏆 매출 상위 5개 상품**'
$o += '| 순위 | 상품 | 매출 | 수량 | 전주 대비 |'; $o += '|---|---|---|---|---|'
$i = 0
foreach ($k in ($c.Keys | Sort-Object { -$c[$_] } | Select-Object -First 5)) { $i++; $o += "| $i | $k | $(Won $c[$k]) | $($qty[$k])개 | $(Pct $c[$k] $p[$k]) |" }

$c = Sum $cur 'Cat'; $p = Sum $prev 'Cat'
$o += ''; $o += '**🗂 카테고리별 매출**'
$o += '| 카테고리 | 매출 | 비중 | 전주 대비 |'; $o += '|---|---|---|---|'
foreach ($k in ($c.Keys | Sort-Object { -$c[$_] })) { $o += "| $k | $(Won $c[$k]) | $(Share $c[$k] $total) | $(Pct $c[$k] $p[$k]) |" }

$c = Sum $cur 'D'
$vals = 0..6 | ForEach-Object { [long]$c[$ws.AddDays($_).ToString($fmt)] }
$max = ($vals | Measure-Object -Maximum).Maximum; $min = ($vals | Measure-Object -Minimum).Minimum
$o += ''; $o += '**📅 일별 매출**'
$o += '| 날짜 | 매출 |'; $o += '|---|---|'
foreach ($n in 0..6) {
  $tag = if ($vals[$n] -eq $max) { ' (최고)' } elseif ($vals[$n] -eq $min) { ' (최저)' } else { '' }
  $o += "| $(Label $ws.AddDays($n)) | $(Won $vals[$n])$tag |"
}
$o += ''
$o += "_기준: 결제금액 합계(배송비 제외) · 출처: 구글 시트 '판매관리' > 판매내역_"

$o -join "`n" | Out-File -Encoding utf8 $Out
# 첫 줄(채널 메시지)도 함께 저장해 둔다
"[주간 매출 리포트] $(Label $ws)~$(Label $we)" | Out-File -Encoding utf8 ([IO.Path]::ChangeExtension($Out, '.title.txt'))
