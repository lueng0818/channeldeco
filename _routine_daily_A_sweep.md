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

## 步驟 3：取直連 URL ＋ 熱門留言 Top 5

只對選中的 A 級貼文做。用 `find`（或 JS 撈 anchor）取得 `href="/@user/post/POSTID"`，直接 navigate 過去（點內文區不會換頁）→ wait 4 秒 → `get_page_text` 取前 5 則留言（帳號＋內容＋讚數）。
取不到單篇連結就用個人頁並標「個人頁」；取不到留言填「🔄 留言將於下次更新補充」。

## 步驟 4：每則產出（繁中）

- `data-kw`：7 類別之一，以**來源關鍵字**為準
- 情緒：焦慮求助／成就感分享／無奈妥協／選擇困難／理性建議 之一
- 透視分析：核心痛點 ＋ ChannelDeco 商機（有反差留言標 ⚡）
- 意圖等級**固定為 A**（本掃只收 A）
- 留言草稿 `data-draft`：2–4 句、先解題、給具體方向；**不放連結、不自薦、不批評同業**；溫暖生活語言。依 8 類切入點決定切角：①無方向求推薦 ②預算明確求解 ③決策/審美兩難 ④找錯人踩雷 ⑤交屋/時程焦慮 ⑥生活機能疑慮 ⑦軟硬裝決策兩難 ⑧老屋/租屋翻新

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

## 步驟 9：推送 GitHub

雲端掛載資料夾，一般 git 指令常因 lock 檔失敗，改用底層 plumbing：

```bash
git fetch channeldeco main
NEW=$(git hash-object -w index.html)
git ls-tree FETCH_HEAD                      # 務必用 FETCH_HEAD，remote 沒設 fetch refspec
printf '100644 blob %s\tindex.html\n' "$NEW" > tree.txt
TREE=$(git mktree < tree.txt)
export GIT_AUTHOR_NAME="ChannelDeco Bot" GIT_AUTHOR_EMAIL="bot@channeldeco.local"
export GIT_COMMITTER_NAME="ChannelDeco Bot" GIT_COMMITTER_EMAIL="bot@channeldeco.local"
C=$(git commit-tree "$TREE" -p <FETCH_HEAD_sha> -m "Daily A-sweep <日期>: +N 則A級")
git push channeldeco "$C:refs/heads/main"
git fetch channeldeco main && git diff FETCH_HEAD -- index.html    # 應為 0
```

diff 不是 0 → 推送期間檔案又被改動 → 重新 fetch、重算計數後再推一次。
token 到期日 2027-08-12；**推送成功時不要提 token**，只有 push 回 401／403 時才提一次，請使用者自行更新 `.git/config`，永遠不要索取 token 字串。

## 步驟 10：驗證（推送前）

- `<div>`／`</div>` 數量平衡為 0、無 `.post-card` 巢狀
- 無重複 `post/POSTID`（若有，保留週更那張）
- 抽出最後一段 `<script>` 存成 .js 跑 `node --check`
- 有 jsdom 時載入一次，確認 `#dbTasks` 項數＝今日新增則數、`.kw-group` 為 7、收合狀態下 DOM 內 `.post-card` 為 0

## 步驟 11：報告

- 讓路時：只回報一句，不附 commit
- 無新 A 級：仍更新日期與提醒後推送，回報「今日無新 A 級貼文」
- 有新增：新增 N 則（各帳號＋地區）、當日重點提醒摘要、commit SHA、repo 連結
  https://github.com/lueng0818/channeldeco

---

## 背景

品牌 ChannelDeco 伽宜諾；輕裝修＋軟裝設計＋空間陳列擺拍；
服務區 高雄／屏東／台南／桃園／新北／台北；
受眾 首購小白／品味租屋族／局部換殼族／長輩照護族。
