# ChannelDeco Content Gate - 可機器判定的 canonical 硬規則，一律實測
#
# 由來：2026-09-11。當日五則 data-draft 以「目測抽查」宣告 PASS，
# 實測後發現 151-161 字，全數超過 語感規格 §I 的 150 字上限。
# 同一 session 另有兩個同型案例：HTML 結構驗證以「結構比對」代替實跑、
# KPI A 級數字沿用舊值（實際已少算 2）。
# 三個獨立情境同方向 → Tilandky 於 2026-09-11 裁決立為硬規則：
#   凡可機器判定的 canonical 硬規則，不得以目測或抽查宣告 PASS。
#
# 用法（Windows PowerShell，於 repo 根目錄）：
#   .\tools\content_gate.ps1
#   .\tools\content_gate.ps1 -Today 2026-9-11
# 離開碼：0 = PASS，1 = FAIL（有 FAIL 就不得宣告 CONTENT_COMPLETE）
#
# 編碼規則（2026-09-11 踩過）：
#   1. 本檔存為 UTF-8 with BOM。Windows PowerShell 5.1 讀 .ps1 預設用系統
#      ANSI（cp950），沒有 BOM 時中文字串變亂碼，還會連帶炸掉引號配對，
#      錯誤訊息會指向完全無關的行（「'<' 運算子保留供未來使用」之類）。
#   2. 程式碼內不放 emoji 或不可見字元，一律用 \u 逃脫。放真字元進來等於
#      再踩一次同一個坑，而且用肉眼看不出哪裡壞掉。

param(
  [string]$File  = "index.html",
  [string]$Today = "",
  [int]$DraftMin = 100,
  [int]$DraftMax = 150
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $File)) { Write-Host "FAIL  找不到檔案：$File" -ForegroundColor Red; exit 1 }
$html = Get-Content $File -Raw -Encoding UTF8

$script:fail = 0
function Ok   ([string]$m) { Write-Host "PASS  $m" -ForegroundColor Green }
function Bad  ([string]$m) { Write-Host "FAIL  $m" -ForegroundColor Red; $script:fail = $script:fail + 1 }
function Info ([string]$m) { Write-Host "      $m" -ForegroundColor DarkGray }

# --- 0. 今天日期（格式與 #dailyBrief 的 data-date 一致，月日不補零） ---------
if (-not $Today) { $Today = (Get-Date).ToString("yyyy-M-d") }
$dbDate = [regex]::Match($html, 'id="dailyBrief"[^>]*data-date="([^"]+)"').Groups[1].Value
if ($dbDate -eq $Today) { Ok "dailyBrief data-date = $Today" }
else { Bad "dailyBrief data-date 是 $dbDate，預期 $Today（右欄待回清單會抓不到當日卡片）" }

# --- 1. div 平衡 -------------------------------------------------------------
$openCount  = ([regex]::Matches($html, '<div[\s>]')).Count
$closeCount = ([regex]::Matches($html, '</div>')).Count
if ($openCount -eq $closeCount) { Ok "div 平衡（$openCount / $closeCount）" }
else { Bad "div 不平衡：開 $openCount、閉 $closeCount，差 $($openCount - $closeCount)" }

# --- 2. 卡片總數與各維度加總 -------------------------------------------------
$total = ([regex]::Matches($html, '<div class="post-card[^>]*>')).Count
Info "實際卡片數 = $total"

$kwList  = @('軟裝設計','輕裝潢','空間佈置','室內設計','裝潢後悔','寵物宅','空間佈置靈感')
$lvlList = @('A','B','C','D','風險')

$kwCount = @{}
foreach ($k in $kwList) {
  $pat = '<div class="post-card[^>]*data-kw="' + [regex]::Escape($k) + '"'
  $kwCount[$k] = ([regex]::Matches($html, $pat)).Count
}
$lvlCount = @{}
foreach ($l in $lvlList) {
  $pat = '<div class="post-card[^>]*data-level="' + [regex]::Escape($l) + '"'
  $lvlCount[$l] = ([regex]::Matches($html, $pat)).Count
}

$kwSum  = ($kwCount.Values  | Measure-Object -Sum).Sum
$lvlSum = ($lvlCount.Values | Measure-Object -Sum).Sum
if ($kwSum  -eq $total) { Ok "七類別加總 $kwSum = 總卡片數" }  else { Bad "七類別加總 $kwSum 不等於總卡片數 $total" }
if ($lvlSum -eq $total) { Ok "五等級加總 $lvlSum = 總卡片數" } else { Bad "五等級加總 $lvlSum 不等於總卡片數 $total" }

# --- 3. 頁面顯示的數字要等於實際數字（不得沿用舊值往上加） -------------------
$csAll = [regex]::Match($html, 'data-kw="all"[^>]*>\s*<div class="num">(\d+)</div>').Groups[1].Value
if ($csAll -eq "$total") { Ok "「全部」顯示 $csAll = 實際 $total" }
else { Bad "「全部」顯示 $csAll，實際 $total" }

foreach ($k in $kwList) {
  $pat    = 'class="cs" data-kw="' + [regex]::Escape($k) + '"[^>]*>\s*<div class="num">(\d+)</div>'
  $shown  = [regex]::Match($html, $pat).Groups[1].Value
  $actual = $kwCount[$k]
  if ($shown -eq "$actual") { Ok "類別 $k 顯示 $shown = 實際 $actual" }
  else { Bad "類別 $k 顯示 $shown，實際 $actual" }
}
foreach ($l in $lvlList) {
  $pat    = 'kpi-box"[^>]*data-lvl="' + [regex]::Escape($l) + '"[^>]*>\s*<div class="kn">(\d+)</div>'
  $shown  = [regex]::Match($html, $pat).Groups[1].Value
  $actual = $lvlCount[$l]
  if ($shown -eq "$actual") { Ok "KPI $l 顯示 $shown = 實際 $actual" }
  else { Bad "KPI $l 顯示 $shown，實際 $actual" }
}

# --- 4. 重複卡片（以 card 為單位，不是以 URL 出現次數） -----------------------
#
# 2026-09-11 修正。舊版定義是「同一 POSTID 在整份 HTML 出現 > 1 次即 duplicate」，
# 實測 6 個命中裡有 3 個是假陽性：
#   DZIITtYD5pr  一次原文連結、一次「查看留言」清單引用
#   DY_XodVmes-  同一張卡內部有兩個原文連結
#   DWoOYoxEsU7  同上
# 真正要問的是「同一則 Threads 貼文有沒有被建成兩張不同的 .post-card」，
# 所以改成：把 HTML 依 .post-card 切段，每段只取第一個「原文連結」當該卡的
# canonical identity，再跨卡比對。留言引用、分析區引用、同卡第二個連結都不計。
#
# 長期正解是讓卡片自帶 data-postid，但那等於對全部卡片做一次 migration，
# 不在本次範圍；先用「每卡一個 canonical POSTID」把定義修正確。

# 切片邊界：本張 .post-card 起點 → 下一張 .post-card 起點。
# 不嘗試用 regex 找巢狀 </div> 的結束位置（HTML 裡 div 太多，一定會提早斷掉）。
#
# ⚠️ 邊界樣式務必用 '<div class="post-card[^>]*>'（post-card 後面不加收尾雙引號）。
#    寫成 '<div class="post-card"[^>]*>' 會漏掉 class="post-card featured" 的卡片
#    （2026-09-11 實測：365 + 39 featured = 404）。漏掉的 featured 卡會被併進前一張
#    的切片，它的 POSTID 就從判重裡整個消失——那是 false negative，比 false positive
#    更危險，因為畫面上看不出來。
$cardStarts = [regex]::Matches($html, '<div class="post-card[^>]*>')

# 自檢：切片數必須等於卡片總數，否則 detector 本身就壞了，不要相信它的判重結果
if ($cardStarts.Count -eq $total) { Ok "card 切片數 $($cardStarts.Count) = 總卡片數（detector 邊界正確）" }
else { Bad "card 切片數 $($cardStarts.Count) 不等於總卡片數 $total，duplicate detector 的邊界有問題，judgement 不可信" }

$linkPat        = '<div class="post-link">\s*<a\s+href="https://www\.threads\.com/@[^"/]+/post/([A-Za-z0-9_-]+)"'
$canonicalCards = New-Object System.Collections.ArrayList
$multiLink      = New-Object System.Collections.ArrayList

for ($i = 0; $i -lt $cardStarts.Count; $i++) {
  $start = $cardStarts[$i].Index
  if ($i -lt $cardStarts.Count - 1) { $end = $cardStarts[$i + 1].Index } else { $end = $html.Length }
  $cardHtml = $html.Substring($start, $end - $start)

  # 作者一律取 card 自己的 .post-author，不可拿 URL 裡的帳號當作者
  $author = [regex]::Match($cardHtml, '<div class="post-author">([^<]+)</div>').Groups[1].Value
  $links  = [regex]::Matches($cardHtml, $linkPat)
  if ($links.Count -eq 0) { continue }

  if ($links.Count -gt 1) { [void]$multiLink.Add("$author（canonical $($links[0].Groups[1].Value)，卡內有 $($links.Count) 個原文連結）") }

  [void]$canonicalCards.Add([pscustomobject]@{
    PostId = $links[0].Groups[1].Value
    Author = $author
  })
}

$distinct = ($canonicalCards | ForEach-Object { $_.PostId } | Sort-Object -Unique).Count
Info "有 canonical 原文連結的卡片 = $($canonicalCards.Count) 張，相異 POSTID = $distinct 個"

$dupGroups = $canonicalCards | Group-Object PostId | Where-Object { $_.Count -gt 1 }
if (-not $dupGroups) { Ok "無重複卡片（每則 Threads 貼文只有一張 .post-card）" }
else {
  foreach ($g in $dupGroups) {
    $authors = @($g.Group | ForEach-Object { $_.Author } | Where-Object { $_ } | Sort-Object -Unique)
    if ($authors.Count -le 1) {
      Bad "重複卡片：$($g.Name) 有 $($g.Count) 張（作者 $($authors -join '、')）。與週更撞號時保留週更那張；都不是週更時保留資料較完整的那張，不要以較新覆蓋"
    } else {
      Bad "DATA_INTEGRITY_REVIEW：$($g.Name) 出現在不同作者的卡片（$($authors -join '、')）。這不是單純重複，可能是 attribution 或 source URL 錯置，**不要自動刪除**，須比對原文人工查核"
    }
  }
}

if ($multiLink.Count -gt 0) {
  Info "提醒（不列 FAIL）：以下卡片內有多個原文連結，只取第一個當 canonical，請確認多出來的是引用而非誤植"
  foreach ($x in $multiLink) { Info "  - $x" }
}

# --- 5. 當日 data-draft：語感規格 §I 硬規則，逐則實測不抽查 -------------------
# 純 \u 逃脫，涵蓋：代理對（絕大多數 emoji）、箭頭、雜項技術、
# 雜項符號與 dingbats、補充符號、變體選擇符 VS16。
$emojiPat = '[\uD800-\uDBFF]|[←-⇿]|[⌀-⏿]|[☀-➿]|[⬀-⯿]|️'

$cardPat    = '<div class="post-card"[^>]*data-added="' + [regex]::Escape($Today) + '"[^>]*>'
$todayCards = [regex]::Matches($html, $cardPat)
Info "當日（$Today）新增卡片 = $($todayCards.Count) 張"
if ($todayCards.Count -eq 0) { Info "當日無新增卡片，跳過草稿檢查（若預期有新增，這本身就是 FAIL 訊號）" }

foreach ($m in $todayCards) {
  $tag    = $m.Value
  $author = [regex]::Match($html.Substring($m.Index), '<div class="post-author">([^<]+)</div>').Groups[1].Value
  $lvl    = [regex]::Match($tag, 'data-level="([^"]+)"').Groups[1].Value
  $d      = [regex]::Match($tag, 'data-draft="([^"]*)"').Groups[1].Value

  if ($lvl -eq '風險') {
    if ($d -match 'Channel Deco' -or $d -match '聊聊') { Bad "$author（風險級）草稿含自薦或邀約，風險級不得自薦" }
    else { Ok "$author（風險級）未自薦" }
    continue
  }
  if (-not $d) { Bad "$author A 級卡片缺 data-draft"; continue }

  $len      = $d.Length
  $problems = New-Object System.Collections.ArrayList
  if ($len -gt $DraftMax -or $len -lt $DraftMin) { [void]$problems.Add("字數 $len（應 $DraftMin-$DraftMax）") }
  if ($d -notmatch '我們')  { [void]$problems.Add("未用「我們」") }
  if ($d -match $emojiPat)  { [void]$problems.Add("含 emoji（硬規則為 0 個）") }
  if ($d -notmatch '聊聊')  { [void]$problems.Add("未以「聊聊」收尾") }
  if ($d -match '[<>]')     { [void]$problems.Add("含角括號") }

  if ($problems.Count -eq 0) { Ok "$author 草稿 $len 字，三段式硬規則全過" }
  else { Bad ("$author 草稿：" + ($problems -join '；')) }
}

# --- 6. 當日卡片必填屬性 -----------------------------------------------------
foreach ($m in $todayCards) {
  $tag  = $m.Value
  $miss = New-Object System.Collections.ArrayList
  foreach ($attr in @('data-added','data-kw','data-level')) {
    if ($tag -notmatch $attr) { [void]$miss.Add($attr) }
  }
  if ($miss.Count -gt 0) { Bad ("有卡片缺必填屬性：" + ($miss -join '、')) }
}

# --- 7. 換行政策 -------------------------------------------------------------
$crlf = ([regex]::Matches($html, "`r`n")).Count
if ($crlf -eq 0) { Ok "行尾全 LF，無 CRLF" }
else { Bad "檔內有 $crlf 處 CRLF，可能發生整檔換行漂移，請確認 core.autocrlf=input" }

if ($html.Length -gt 0 -and $html[0] -eq [char]0xFEFF) { Bad "index.html 開頭有 BOM" } else { Ok "index.html 無 BOM" }

$n = $script:fail
Write-Host ""
if ($n -eq 0) {
  Write-Host "CONTENT GATE: PASS - 可宣告 CONTENT_COMPLETE" -ForegroundColor Green
  Write-Host ""
  Write-Host "⚠️ 本 gate 只涵蓋『慣用語檢查』裡可機器判定的部分，不代表流程已完成。" -ForegroundColor Yellow
  Write-Host "   ChannelDeco 內容流程：AI 生成 → Human Write → 慣用語檢查 → 發布／回覆" -ForegroundColor Yellow
  Write-Host "   Human Write 與 Real-World Validation 的 owner 是 Hailey／ChannelDeco 團隊，不是本工具。" -ForegroundColor Yellow
  Write-Host "   『通過品牌語氣規格』≠『Human Write 完成』——前者是規則符合度，後者是人的語言所有權，兩個 Gate 分開記。" -ForegroundColor Yellow
  exit 0
} else {
  Write-Host "CONTENT GATE: FAIL（$n 項）- 不得宣告 CONTENT_COMPLETE，修好再跑一次" -ForegroundColor Red
  exit 1
}
