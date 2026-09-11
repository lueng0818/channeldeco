# ChannelDeco Content Gate — 可機器判定的 canonical 硬規則，一律實測
#
# 由來：2026-09-11。當日五則 data-draft 以「目測抽查」宣告 PASS，
# 實測後發現 151–161 字，全數超過 語感規格 §I 的 150 字上限。
# 同一 session 另有兩個同型案例：HTML 結構驗證以「結構比對」代替實跑、
# KPI A 級數字沿用舊值（實際已少算 2）。
# 三個獨立情境同方向 → Tilandky 於 2026-09-11 裁決立為硬規則：
#   凡可機器判定的 canonical 硬規則，不得以目測或抽查宣告 PASS。
#
# 用法（Windows PowerShell，於 repo 根目錄）：
#   .\tools\content_gate.ps1
#   .\tools\content_gate.ps1 -Today 2026-9-11
# 離開碼：0 = PASS，1 = FAIL（有 FAIL 就不得宣告 CONTENT_COMPLETE）

param(
  [string]$File  = "index.html",
  [string]$Today = "",
  [int]$DraftMin = 100,
  [int]$DraftMax = 150
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $File)) { Write-Host "FAIL  找不到檔案：$File" -ForegroundColor Red; exit 1 }
$html = Get-Content $File -Raw -Encoding UTF8

$fail = 0
function Ok  ($m){ Write-Host "PASS  $m" -ForegroundColor Green }
function Bad ($m){ Write-Host "FAIL  $m" -ForegroundColor Red; $script:fail++ }
function Info($m){ Write-Host "      $m" -ForegroundColor DarkGray }

# ── 0. 今天日期（格式與 #dailyBrief 的 data-date 一致，月日不補零） ──────────
if (-not $Today) { $Today = (Get-Date).ToString("yyyy-M-d") }
$dbDate = [regex]::Match($html,'id="dailyBrief"[^>]*data-date="([^"]+)"').Groups[1].Value
if ($dbDate -eq $Today) { Ok "dailyBrief data-date = $Today" }
else { Bad "dailyBrief data-date 是 $dbDate，預期 $Today（右欄待回清單會抓不到當日卡片）" }

# ── 1. div 平衡與卡片巢狀 ────────────────────────────────────────────────
$open  = ([regex]::Matches($html,'<div[\s>]')).Count
$close = ([regex]::Matches($html,'</div>')).Count
if ($open -eq $close) { Ok "div 平衡（$open / $close）" }
else { Bad "div 不平衡：<div> $open 個、</div> $close 個，差 $($open-$close)" }

# ── 2. 卡片總數與各維度加總 ──────────────────────────────────────────────
$cards = [regex]::Matches($html,'<div class="post-card[^>]*>')
$total = $cards.Count
Info "實際卡片數 = $total"

$kwList  = @('軟裝設計','輕裝潢','空間佈置','室內設計','裝潢後悔','寵物宅','空間佈置靈感')
$lvlList = @('A','B','C','D','風險')

$kwCount  = @{}; foreach($k in $kwList) { $kwCount[$k] = ([regex]::Matches($html,'<div class="post-card[^>]*data-kw="'+[regex]::Escape($k)+'"')).Count }
$lvlCount = @{}; foreach($l in $lvlList){ $lvlCount[$l] = ([regex]::Matches($html,'<div class="post-card[^>]*data-level="'+[regex]::Escape($l)+'"')).Count }

$kwSum  = ($kwCount.Values  | Measure-Object -Sum).Sum
$lvlSum = ($lvlCount.Values | Measure-Object -Sum).Sum
if ($kwSum  -eq $total) { Ok "七類別加總 = $kwSum = 總卡片數" }  else { Bad "七類別加總 $kwSum ≠ 總卡片數 $total（可能漏了類別或統計式寫錯）" }
if ($lvlSum -eq $total) { Ok "五等級加總 = $lvlSum = 總卡片數" } else { Bad "五等級加總 $lvlSum ≠ 總卡片數 $total" }

# ── 3. 頁面上顯示的數字要等於實際數字（不得沿用舊值往上加） ────────────────
$csAll = [regex]::Match($html,'data-kw="all"[^>]*>\s*<div class="num">(\d+)</div>').Groups[1].Value
if ($csAll -eq "$total") { Ok "「全部」顯示 $csAll = 實際 $total" } else { Bad "「全部」顯示 $csAll，實際 $total" }

foreach($k in $kwList){
  $shown = [regex]::Match($html,'class="cs" data-kw="'+[regex]::Escape($k)+'"[^>]*>\s*<div class="num">(\d+)</div>').Groups[1].Value
  if ($shown -eq "$($kwCount[$k])") { Ok "類別 $k 顯示 $shown = 實際 $($kwCount[$k])" }
  else { Bad "類別 $k 顯示 $shown，實際 $($kwCount[$k])" }
}
foreach($l in $lvlList){
  $shown = [regex]::Match($html,'kpi-box"[^>]*data-lvl="'+[regex]::Escape($l)+'"[^>]*>\s*<div class="kn">(\d+)</div>').Groups[1].Value
  if ($shown -eq "$($lvlCount[$l])") { Ok "KPI $l 顯示 $shown = 實際 $($lvlCount[$l])" }
  else { Bad "KPI $l 顯示 $shown，實際 $($lvlCount[$l])" }
}

# ── 4. 重複 POSTID ──────────────────────────────────────────────────────
$ids = [regex]::Matches($html,'threads\.com/@[A-Za-z0-9_.]+/post/([A-Za-z0-9_-]+)') | ForEach-Object { $_.Groups[1].Value }
$dup = $ids | Group-Object | Where-Object Count -gt 1
if (-not $dup) { Ok "無重複 POSTID（共 $($ids.Count) 筆連結）" }
else { Bad "重複 POSTID：$([string]::Join('、', ($dup | ForEach-Object { "$($_.Name) ×$($_.Count)" })))（與週更撞號時保留週更那張）" }

# ── 5. 當日 data-draft：語感規格 §I 硬規則，逐則實測不抽查 ──────────────────
# 正本：語感規格_v0.1_2026-09-11.md §G／§I
$todayCards = [regex]::Matches($html,'<div class="post-card"[^>]*data-added="'+[regex]::Escape($Today)+'"[^>]*>')
Info "當日（$Today）新增卡片 = $($todayCards.Count) 張"
if ($todayCards.Count -eq 0) { Info "當日無新增卡片，跳過草稿檢查（若預期有新增，這本身就是 FAIL 訊號）" }

$emoji = '[\uD800-\uDBFF]|[☀-➿]|️|[←-⇿]|[⬀-⯿]'
foreach($m in $todayCards){
  $tag    = $m.Value
  $author = [regex]::Match($html.Substring($m.Index), '<div class="post-author">([^<]+)</div>').Groups[1].Value
  $lvl    = [regex]::Match($tag,'data-level="([^"]+)"').Groups[1].Value
  $d      = [regex]::Match($tag,'data-draft="([^"]*)"').Groups[1].Value

  if ($lvl -eq '風險') {
    # 風險級為唯一例外：維持不批評、不自薦
    if ($d -match 'Channel Deco' -or $d -match '聊聊') { Bad "$author（風險級）草稿含自薦或邀約——風險級不得自薦" }
    else { Ok "$author（風險級）未自薦" }
    continue
  }
  if (-not $d) { Bad "$author A 級卡片缺 data-draft"; continue }

  $len = $d.Length
  $problems = @()
  if ($len -gt $DraftMax -or $len -lt $DraftMin) { $problems += "字數 $len（應 $DraftMin–$DraftMax）" }
  if ($d -notmatch '我們')            { $problems += "未用「我們」" }
  if ($d -match '(?<!我)們|^我[^們]')  { }  # 保留：人稱細checking交由人工
  if ($d -match $emoji)               { $problems += "含 emoji（硬規則為 0 個）" }
  if ($d -notmatch '聊聊')            { $problems += "未以「聊聊」收尾（招牌收尾，不可改成歡迎諮詢／私訊）" }
  if ($d -match '[<>]')               { $problems += "含角括號" }

  if ($problems.Count -eq 0) { Ok "$author 草稿 $len 字，三段式硬規則全過" }
  else { Bad "$author 草稿：$([string]::Join('；', $problems))" }
}

# ── 6. 當日卡片必填屬性 ──────────────────────────────────────────────────
foreach($m in $todayCards){
  $tag = $m.Value
  $miss = @()
  foreach($attr in @('data-added','data-kw','data-level')){ if ($tag -notmatch $attr) { $miss += $attr } }
  if ($miss.Count -gt 0) { Bad "有卡片缺必填屬性：$([string]::Join('、',$miss))" }
}

# ── 7. 換行政策 ─────────────────────────────────────────────────────────
$crlf = ([regex]::Matches($html,"`r`n")).Count
if ($crlf -eq 0) { Ok "行尾全 LF，無 CRLF" } else { Bad "檔內有 $crlf 處 CRLF——可能發生整檔換行漂移，請確認 core.autocrlf=input" }
if ($html.Length -gt 0 -and $html[0] -eq [char]0xFEFF) { Bad "檔案開頭有 BOM" } else { Ok "無 BOM" }

Write-Host ""
if ($fail -eq 0) {
  Write-Host "CONTENT GATE: PASS — 可宣告 CONTENT_COMPLETE" -ForegroundColor Green
  Write-Host "注意：以上皆為 Automated Gate。Jessica Real-World Validation 另計，不得因此標為完成。" -ForegroundColor Yellow
  exit 0
} else {
  Write-Host "CONTENT GATE: FAIL（$fail 項）— 不得宣告 CONTENT_COMPLETE，修好再跑一次" -ForegroundColor Red
  exit 1
}
