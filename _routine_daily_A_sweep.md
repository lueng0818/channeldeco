# ChannelDeco｜每日輕量 A 級掃描（threads-home-deco-daily-a-sweep）

> **2026-07-25 建立｜2026-09-04 全面改寫，內容與現行排程 SKILL.md 同步。**
>
> 本檔為人類可讀的說明版；**實際執行以排程檔為準**：
> `C:\Users\Tilandky Ho\Documents\Claude\Scheduled\threads-home-deco-daily-a-sweep\SKILL.md`
> （repo 內對照本：[`skills/threads-home-deco-daily-a-sweep.SKILL.md`](skills/threads-home-deco-daily-a-sweep.SKILL.md)）
>
> 排程設定：cron `0 9 * * 0,2-6`（週日、週二～週六 09:00），Folders 選
> `C:\Users\Tilandky Ho\Documents\Claude專區\chanel deco`。
> 目的：A 級高意圖貼文的黃金接觸窗只有一兩天，週更太慢，這支每天補抓「新的 A 級」。

---

## 與週更的優先關係（最重要）

| 排程 | 時間 | 角色 | 同日衝突時 |
|---|---|---|---|
| `threads-home-deco-daily` | 週一 09:09 | 完整七類別更新 | **優先，照常執行** |
| `threads-home-deco-daily-a-sweep` | 週日、週二～週六 09:00 | 只補抓新 A 級 | **一律讓路，不掃描不寫入不推送** |

兩支共用同一份 `index.html` 與同一套 GitHub 推送機制，同日先後寫入會互相覆蓋卡片與統計數字。

---

## 步驟 0：重疊避讓檢查（最優先，未通過就直接結束）

開瀏覽器或改檔案**之前**，先用 bash 做三項檢查，任一成立就立即停止：

1. 今天是星期一（`date +%u` 回傳 `1`）
2. `index.html` 已出現當天的週更標記：
   ```bash
   cd "/sessions/<session>/mnt/chanel deco"
   D=$(date +%Y-%-m-%-d)          # 例：2026-9-4，月份與日期不補零
   grep -c "每週一完整七類別更新新增（$D" index.html
   ```
   回傳 ≥ 1 → 停止
3. header「最後更新」已是今天，且 `grep -c "data-added=\"$D\"" index.html` > 8 → 判定週更已跑過 → 停止

停止時**完全不動 index.html、不推送**，只回報一句：
「今日由每週一完整版負責，每日 A 級掃描自動略過（避免重複卡片與計數衝突）。」

### 防競態（三項檢查都通過才適用）

- 開始編輯前記錄 `git hash-object index.html`；寫入前再測一次，hash 變了代表檔案被別人動過 → 重讀、重去重、重算數字再寫。
- 推送前確認 hash 已穩定（間隔 30 秒兩次相同）才 `git hash-object -w` 與 push。
- 若出現與週更重複的卡片（同一 `post/POSTID`）→ **保留週更那張、刪本排程新增的那張**，然後重算所有計數。

---

## 步驟 1：讀現況去重

讀 `index.html`，取出所有已存在的 `class="post-author"` 帳號與 `.post-link` 的 href 當去重清單。

## 步驟 2：輕量掃 7 關鍵字（只找 A 級）

依序 navigate 七個搜尋頁（每頁 wait 4 秒再 `get_page_text`）：
軟裝設計／輕裝潢／空間佈置／室內設計／裝潢後悔／寵物宅／空間佈置靈感

網址格式：`https://www.threads.com/search?q=關鍵字&serp_type=default&filter=recent`
**務必加 `&filter=recent`**，否則預設「最相關」排序只會回傳 1～2 則舊貼文。

只挑符合 A 級訊號的新貼文：同時有**地區** ＋（預算／時程／明確求設計師統包推薦）任一。
已在去重清單者跳過。每天目標 0～6 則，**寧缺勿濫**。
非服務區（如雲林、宜蘭）若訊號完整可收，但要在分析中標明「非到府區」。

> Threads 頁面易逾時：同一 tab 反覆 timeout 就用 `tabs_create_mcp` 開新 tab 重試。
> 實務上用 `javascript_tool` 撈 `a[href*="/post/"]` 取單篇連結，比 `find` 穩定。

### 步驟 2.9：Discovery degraded-mode cutoff（2026-09-06）

節流（回傳量變少）與 endpoint 掛掉是**兩件事**，處置相反：

| 症狀 | 判斷 | 處置 |
|---|---|---|
| 只回 1～2 筆、單頁逾時 | throttling | 拉長間隔、換 tab、scroll 觸發載入 |
| 連續回錯誤頁／空頁 | endpoint availability | **停止擴大關鍵字**，進 DEGRADED |

**觸發條件**：同一輪中 3 個**相互獨立**的 discovery surface 均持續失敗
（A `/search?q=…` ／ B `/tag/軟裝設計` ／ C `/@channel.deco/replies`）
→ platform-side discovery degradation，立即停止重試。

```
Surface A fail → wait 20-30s
Surface B fail → wait 20-30s
Surface C fail → DEGRADED（不再擴大關鍵字、不再長時間重試）
```

先確認首頁 `https://www.threads.com/` 是否正常，用來區分「平台端異常」與「登入失效」。

**狀態記法（查不到 ≠ 是零）**：

```
Discovery       = DEGRADED
Intent analysis = SKIP — insufficient reliable input
Comment audit   = UNKNOWN
```

**不得**記成「0 則新貼文」「今日無新增 A 級」。
DEGRADED 當日跳過建卡，仍完成步驟 6（每日提醒，⚠️ 那條寫明三 surface 探測結果）、
步驟 7（計數重算）、步驟 10（驗證）、步驟 11（報告）。

canonical 規範：`000_Agent/knowledge/EXECUTION-BOUNDARY-STANDARD.md` 第四節。

## 步驟 3：取直連 URL ＋ 熱門留言 Top 5

只對選中的 A 級貼文做。用 `find`（或 JS 撈 anchor）取得 `href="/@user/post/POSTID"`，直接 navigate 過去（點內文區不會換頁）→ wait 4 秒 → `get_page_text` 取前 5 則留言（帳號＋內容＋讚數）。
取不到單篇連結就用個人頁並標「個人頁」；取不到留言填「🔄 留言將於下次更新補充」。

## 步驟 4：每則產出（繁中）

- `data-kw`：7 類別之一，以**來源關鍵字**為準
- 情緒：焦慮求助／成就感分享／無奈妥協／選擇困難／理性建議 之一
- 透視分析：核心痛點 ＋ ChannelDeco 商機（有反差留言標 ⚡）
- 意圖等級**固定為 A**（本掃只收 A）
- 留言草稿 `data-draft`：走 **ChannelDeco 三段式**（2026-09-11 由 Tilandky 裁決；正本 `語感規格_v0.1_2026-09-11.md` §G／§I，語料 `語感庫_原始語料_2026-09-11.md` C01–C06）：

  ```
  ① 接住對方寫出來的條件，給一句判斷
  ② 給一個具體、可驗證的技術提醒（對方沒問、但實際會踩到的那一題）
  ③ 收尾：「我們是 Channel Deco，做輕裝修＋軟裝設計，歡迎跟我們聊聊。」
  ```

  硬規則：用「我們」不用「我」｜**emoji 0 個**｜不批評同業｜3–5 句、約 **100–150 字**｜`data-draft` 內不可有半形雙引號與角括號。

  ⚠️ **舊版「不放連結、不自薦」已於 2026-09-11 作廢**——@channel.deco 實際留言 C01–C06 六則全部以自薦＋「聊聊」收尾，舊規則與品牌真實語氣衝突。
  ⚠️ **唯一例外**：`data-level="風險"` 維持不批評、不自薦，只轉化為自家透明度內容題材。

  依 8 類切入點決定第 ① 段切角：①無方向求推薦 ②預算明確求解 ③決策/審美兩難 ④找錯人踩雷 ⑤交屋/時程焦慮 ⑥生活機能疑慮 ⑦軟硬裝決策兩難 ⑧老屋/租屋翻新

## 步驟 5：建卡並插入

卡片在 HTML 裡是**平鋪**放在 `<div class="posts-grid" id="postsGrid">` 內；頁面上的兩層收合是載入時由 JS `buildHierarchy()` 動態組出來的，**不要手動建 `.kw-group`／`.lvl-group`**。

在 `#postsGrid` **最前面**插入，並在該批卡片前加標記註解：

```html
<!-- ===== 以下 N 則為 threads-home-deco-daily-a-sweep 每日輕量 A 級掃描新增（YYYY-M-D） ===== -->
<div class="post-card" data-added="YYYY-M-D" data-kw="類別" data-level="A" data-draft="草稿…">
```

- **`data-added` 必填**，格式與 `#dailyBrief` 的 `data-date` 完全一致（如 `2026-9-4`，不補零）
- `data-draft` 內不可有半形雙引號 `"`（改用『』「」或全形）、不可有 `<` `>`
- `.post-date` 用「日期 · 一句主題」；地區用含 📍 的 `.badge`
- 其餘結構比照 index.html 現有 A 級卡片；@channel.deco 已留言者作者旁加 ⭐
- **收尾務必 3 個 `</div>`**（analysis、comments-section、post-card 各一）

## 步驟 6：更新「📅 每日更新提醒」（每天必做）

`id="dailyBrief"`，位置在「今日行動佇列」下方、「📂 類別篩選」上方。

- 改 `data-date` 與 `.db-date` 文字（例：`2026 年 9 月 4 日（五）· 每日輕量 A 級掃描 · 下次更新 2026 年 9 月 5 日`）
- 改寫 `<ul class="db-points">` 的 3～5 條重點提醒，每條 `<li><strong>標記｜對象</strong>說明…</li>`，建議涵蓋：🔴 最優先該回哪一則、🟠 哪一則窗口正在關閉、🟡 可合併成內容主題的題材、💡 當日留言區觀察、⚠️ 關鍵字掃描狀況
- 右欄「今日待回貼文」與左上角數字由 `buildDailyBrief()` 依 `data-added` 自動生成，**不用手改**
- 當天無新 A 級時仍要更新日期與提醒（可寫「今日無新增 A 級，維持前一日待辦」）
- 若步驟 0 判定讓路，本步驟一併略過

## 步驟 7：更新數字（用實際 grep，不要沿用舊數字往上加）

- header 最後更新日期＝今天
- 總貼文數＝`grep -o '<div class="post-card' index.html | wc -l`
  （舊寫法 `'class="post-card"'` 會漏掉 `class="post-card featured"`，一律用新寫法）
- 「全部」與各類別 `.cs` 數字＝各 `data-kw` 在 `.post-card` 上的實際次數（含 featured）
- KPI 五格＝各 `data-level` 實際次數（含 featured）；A 級數字須與行動佇列標題一致
- 熱門話題 Top 4 有更高讚新貼文才更新，否則不動

## 步驟 8：固定結構一律保留

見 [`_routine_persist_rules.md`](_routine_persist_rules.md)。本排程對「本週社群關鍵信號」「建議本週發文方向」「語意集群健康度檢查」等週更專屬區塊**只讀不改**。

## 步驟 9：準備 commit（容器端；**不推送**）

> ⚠️ **執行與發布解耦（2026-09-06 定案）**
>
> 排程容器（Ubuntu）與 Windows 主機是**不同的 execution boundary**：
> 容器裡沒有 `C:\`、沒有 Windows Credential Store、沒有 `gh auth` 登入狀態。
> **這不是 PATH 問題，也不是 token 過期——依現行架構，容器必然無法 push。**
>
> 兩次事故同一個根因：2026-09-05 Tru-Mi「找不到 gh」、
> 2026-09-06 ChannelDeco `could not read Username for 'https://github.com'`。
> 過去 SOP 把「內容完成」與「發布完成」寫成同一個狀態，
> 於是撞到邊界時 Agent 會往兩個錯方向找解法：硬編 gh 路徑，或建 token 檔——
> 後者直接製造出 09-05 的明碼 PAT 外洩。
>
> canonical：`000_Agent/knowledge/EXECUTION-BOUNDARY-STANDARD.md`
> 憑證：[`GITHUB-AUTH-STANDARD.md`](GITHUB-AUTH-STANDARD.md)

> ⚠️ **2026-09-11 追加修正：容器端不再產生 commit，Windows 端也不再推 dangling SHA。**
>
> 舊版流程是容器用 `git commit-tree` 造出 commit object、Windows 端 `git push <sha>:refs/heads/main`。
> 這會讓**遠端前進、但本機 `main` 這個 ref 不前進**。divergence 每天累積，
> 2026-09-11 實際撞上：本機 main 落後遠端數天，commit 掛在舊 parent 上被判 `non-fast-forward`。
> **這是流程本身會累積的結構性缺陷，不是偶發錯誤**，所以整段 plumbing 從 Deployment Pipeline 移除。
>
> `commit-tree` 之後仍可作為容器端產生 **candidate／evidence** 的手段，
> 但**不得**再當成 branch-management 的正式方式——那條路徑會把今天剛查清楚的根因寫回 SOP。

| Pipeline | 執行環境 | 責任 |
|---|---|---|
| Content Pipeline | 本排程（Ubuntu 容器） | 掃描、判讀、改 `index.html`、驗證。**不碰 git** |
| Deployment Pipeline | **Windows 主機（人工）** | fetch → gate → reset --mixed → commit → push → verify |
| Verification | Windows／容器 | `git diff FETCH_HEAD -- index.html` 為空，或 [`tools/deploy_verify.sh`](tools/deploy_verify.sh) |

容器端做到「`index.html` 改好且通過步驟 10 驗證」為止，宣告 `CONTENT_COMPLETE`。

### 容器端不做的事

- ❌ `git push`、`git commit`、`git commit-tree`、`git mktree`、`git reset`
- ❌ `gh auth status`（容器沒有 gh，問了也沒意義）
- ❌ 用 `git ls-remote` 當「推得動」的證據——它只驗 **read reachability**。
  要驗當前 runtime 的推送能力用 `git push --dry-run`。
- ❌ 硬編 `gh` 路徑、建 `.github_token`／`token.txt`、把 token 寫進 remote URL 或 `.git/config`
- ❌ 向使用者索取 token 字串

### 交給 Windows 的交付物（正常 branch workflow，照抄貼上不要改順序）

```powershell
cd "$env:USERPROFILE\Documents\Claude專區\chanel deco"

# ⓪ 確認在 main 這條 branch 上（detached HEAD 會讓本機 ref 又不前進）
git branch --show-current          # 預期輸出：main

# ① 取得遠端最新（只更新 FETCH_HEAD，不動工作區）
git fetch channeldeco main

# ② ⛔ GATE：確認「今天的修改確實還在工作區」才准往下走
#    reset 是為了對齊遠端 ref，不是為了清掉本地工作
git status --short                                                   # index.html 應為 M
Select-String -Path index.html -Pattern 'a-sweep 每日輕量 A 級掃描新增（<今天日期>' -Quiet   # 應為 True
(Select-String -Path index.html -Pattern '<div class="post-card' -AllMatches).Matches.Count  # 應為預期卡片數
# 任一不符 → 停下來回報，不要 reset

# ③ 對齊遠端 ref（--mixed 只移動 HEAD 與索引，working tree 原封不動）
#    🚫 絕對不要用 --hard，那會把今天的修改整個抹掉
git reset --mixed FETCH_HEAD

# ④ 覆核差異規模：淨增行數應約等於「新增卡片數 × 9 + 1」
#    出現四位數改動量代表整檔換行／BOM 漂移 → 停下來回報，不要 commit
git diff --stat -- index.html

# ⑤ 提交並推送 branch（不是 SHA）：本機 main、遠端 main、working tree 三者重新一致
git add index.html
git commit -m "Daily A-sweep <日期>: +N 則A級"
git push channeldeco main:refs/heads/main

# ⑥ 驗證：下面這行輸出為空才算 DEPLOY_VERIFIED
git fetch channeldeco main
git diff FETCH_HEAD -- index.html
```

> 用 `main:refs/heads/main` 而不是 `HEAD:refs/heads/main`：兩者在正常情況等價，
> 但 HEAD detached 時前者會**直接失敗**、後者會靜默推出一顆本機 ref 追不到的 commit——
> 那正是舊流程的失敗模式，讓它大聲壞掉比較安全。

### 換行政策

本 repo 已設 **repo-local** `core.autocrlf=input`（不設 `--global`，避免影響其他專案）：

```powershell
git config core.autocrlf input
git config --get core.autocrlf     # 預期輸出：input
```

`index.html` 行尾維持全 LF、無 BOM。改檔時**只動要改的行**，不要整檔重寫
（2026-09-02 `MEMORY.md` 整檔 LF→CRLF 漂移事故同型）。
更徹底的做法是用 `.gitattributes` 把文字檔換行政策固定下來，比個人 Git config 更可重現。

## 步驟 9.5：Deployment Evidence Gate

```bash
bash tools/deploy_verify.sh
```

四項證據：local artifact hash／local HEAD／remote HEAD／target file hash comparison。
驗的是「GitHub 上的內容是否等於本機內容」，比 `git push` 的 exit code 更接近真正在意的結果。

| 退出碼 | 意義 | 狀態 |
|---|---|---|
| 0 | 遠端＝本機 | **`DEPLOY_VERIFIED`** ← 只有這裡才叫發布完成 |
| 1 | 遠端落後本機 | `DEPLOY_WAITING` / `DEPLOY_BLOCKED` |
| 2 | 讀不到遠端 | `UNKNOWN`——不得宣稱已發布，也不得記成 0 |

> 本機 `.git` 的 HEAD ref 不會因 plumbing 推送而前進，`[2] local HEAD` 常顯示很舊的日期，
> 這是正常的。**權威證據是 `[4]` 的檔案 hash 比對。**

## 步驟 10：驗證（推送前）

> ⛔ **凡可機器判定的硬規則一律實測，不得目測或抽查**（2026-09-11 裁決，見
> [`_routine_persist_rules.md`](_routine_persist_rules.md) §8）。

**主要方式**：在 repo 根目錄跑

```powershell
.\tools\content_gate.ps1
```

離開碼 0 才可宣告 `CONTENT_COMPLETE`。它會實測：div 平衡／七類別與五等級加總是否等於總卡片數／
頁面顯示數字是否等於實際數字／重複 POSTID／當日每則 `data-draft` 的字數與三段式硬規則／
必填屬性／LF 與 BOM。

**容器端 bash 不可用時的替代**：用瀏覽器 JS 引擎對實際字串量測（`String.length`、正則），
或載入已發布頁面以其自身 JS 產出的統計數字反查。**不得改用目測。**

補充（工具未涵蓋的部分）：

- 抽出最後一段 `<script>` 存成 .js 跑 `node --check`
- 有 jsdom 或已發布頁面時，確認 `#dbTasks` 項數＝今日新增則數、`.kw-group` 為 7、
  收合狀態下 DOM 內 `.post-card` 為 0、`#aqList` 項數＝A 級總數
- `.post-card` 巢狀為 0

## 步驟 11：報告（四段狀態模型）

**不得**在未經 `deploy_verify.sh` 驗證時寫「發布完成」「已上線」「每日更新完成」。

```
Environment : [OK ／ DEGRADED（沙箱掛載失敗等執行環境問題，與 Git 流程缺陷分開記）]
Discovery   : [OK ／ DEGRADED（附三 surface 探測結果與重試過程）]
Content     : CONTENT_COMPLETE
Validation  : [PASS ／ FAIL（列出哪幾項因環境限制未能執行）]
Deployment  : DEPLOY_WAITING — 待 Windows 端執行步驟 9 指令
```

標準狀態模型：

```
CONTENT_COMPLETE → DEPLOY_WAITING → DEPLOY_PUSHED → DEPLOY_VERIFIED
```

若哪天恢復「容器先算 commit」的架構（僅作 candidate／evidence，不直接推），
狀態模型改為：

```
CONTENT_COMPLETE → COMMIT_CANDIDATE_READY
                 → Windows fetch / reset --mixed / stage / commit / push
                 → DEPLOY_PUSHED → DEPLOY_VERIFIED
```

**`COMMIT_CANDIDATE_READY` 不等於「Windows 直接推這顆 SHA」**——Windows 端一律重走
正常 branch workflow，容器算出的 commit 只是佐證與比對用。

容器端結束時最多只能宣告 `CONTENT_COMPLETE`；
架構上無法推送記 `DEPLOY_BLOCKED`（不是 `PENDING`——後者的語意是「等一下可能自己好」，
會讓 Agent 一直重試一件結構上不可能成功的事）。
**執行環境故障（如 `Plan9 share "c" is not mounted`）歸類為 Environment Failure，
不併入 Git 發布流程缺陷計算**——兩者根因不同、修法也不同。
搭配 CLAUDE.md 交付狀態：內容完成但未發布 → **⚠️ 做完了但有疑慮**，不可用 ✅。

內容部分：

- 步驟 0 讓路：只回一句「今日由每週一完整版負責，每日 A 級掃描自動略過」，不附 commit
- Discovery 為 DEGRADED：照步驟 2.9 記法，**不要寫「今日無新 A 級」**
- 掃描正常但無合格 A 級：回報「今日無新 A 級貼文（7 組關鍵字皆正常回傳）」
- 有新增：新增 N 則（各帳號＋地區）、當日重點提醒摘要、可貼的 push 指令、
  repo 連結 https://github.com/lueng0818/channeldeco

---

## 背景

品牌 ChannelDeco 伽宜諾；輕裝修＋軟裝設計＋空間陳列擺拍；
服務區 高雄／屏東／台南／桃園／新北／台北；
受眾 首購小白／品味租屋族／局部換殼族／長輩照護族。
