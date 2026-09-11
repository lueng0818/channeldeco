# ChannelDeco 儀表板｜固定結構保留規則

> **2026-07-25 建立｜2026-09-04 全面改寫，內容與現行兩支排程 SKILL.md 同步。**
>
> 這份是 `index.html` 的「不可破壞清單」。兩支排程每次更新**只新增／替換卡片與數字**，
> 以下結構一律不可移除或改動；若發現被移除或損毀，**應還原而非略過**。
>
> 對應排程檔：
> - `skills/threads-home-deco-daily.SKILL.md`（週一完整版）
> - `skills/threads-home-deco-daily-a-sweep.SKILL.md`（每日 A 級掃描）
>
> 發布相關（2026-09-06 加入）：
> - `tools/deploy_verify.sh` — Deployment Evidence Gate
> - `000_Agent/knowledge/EXECUTION-BOUNDARY-STANDARD.md` — 跨專案執行邊界 canonical

---

## 1. `<style>` 內必須保留的規則

| 項目 | 選擇器 | 作用 |
|---|---|---|
| 卡片左緣色條 | `.post-card[data-level="A/B/C/D/風險"]{border-left-color:…}` | A綠／B藍／C紫／D灰／風險深紅 |
| 效能 | `.post-card{content-visibility:auto;contain-intrinsic-size:auto 460px}` | 避免大量卡片拖垮繪製 |
| 防切字 | `html,body{overflow-x:hidden}`、`.ch-row>span`／`.post-analysis` 的 `overflow-wrap:anywhere` | 長中文不溢出 |
| 行動佇列 | `.action-queue`／`.aq-*` | 置頂 A 級清單 |
| 留言草稿 | `.post-draft`／`.pd-*`／`.aq-copy`／`.aq-draft-text` | 草稿顯示＋一鍵複製 |
| 本週內容選題 | `.content-topics`／`.ct-*` | B 級題庫 |
| 每日更新提醒 | `.daily-brief`／`.db-*` | 每日 A 級掃描專屬區塊 |
| 兩層收合階層 | `.kw-group`／`.kwg-*`／`.lvl-group`／`.lvlg-*`／`.groups-wrap` | 類別 → 等級收合 |

⚠️ **`.daily-brief` 不可加 `content-visibility`** —— 加了整塊不繪製。

## 2. `<body>` 內三個固定區塊

1. `.container` 頂端的 `<div class="action-queue" id="actionQueue">…</div>`
2. 其下方的 `<div class="daily-brief" id="dailyBrief">…</div>`
3. 策略專區前的 `<div class="content-topics" id="contentTopics">…</div>`

## 3. `<script>` 內必須保留的函式

`esc()`、`buildActionQueue()`、`capActionQueue()`、`renderDrafts()`、`copyDraft()`、
`buildContentTopics()`、`buildDailyBrief()`、`buildHierarchy()`、`toggleGroup()`、
`setGroup()`、`mountCards()`、`scrollToEl()`，
以及**改寫版**的 `filterKw()`／`filterLevel()`（它們現在驅動收合，不是改 display）。

### 🚫 絕對不要改回一次全部塞進 DOM

收合狀態下卡片是**延遲掛載**（存在 `pg.__pending` fragment，展開才進 DOM）。
這是頁面能正常繪製的關鍵：卡片全部塞進 DOM 時整頁高達 6 萬 px、1 萬多個節點，Chrome 會整片畫不出來。

### 其他自動生成規則

- 「今日行動佇列」由 `buildActionQueue()` 自動從所有 `data-level="A"` 卡片生成，`capActionQueue()` 預設只顯示前 12 則、其餘收合可展開 —— **不要拿掉，也不要改回手寫清單**
- 「本週內容選題」由 `buildContentTopics()` 自動從所有 `data-level="B"` 卡片依分享數排序生成
- 「每日更新提醒」右欄與左上角數字由 `buildDailyBrief()` 依 `data-added` 生成

## 4. 卡片開頭 div 的必填屬性

```html
<div class="post-card" data-added="2026-9-4" data-kw="室內設計" data-level="A" data-draft="草稿…">
```

| 屬性 | 必填 | 說明 |
|---|---|---|
| `data-added` | ✅ | 今天日期，月份日期**不補零**，格式須與 `#dailyBrief` 的 `data-date` 完全一致。漏了「每日更新提醒」右欄就抓不到 |
| `data-kw` | ✅ | 7 類別之一，以來源關鍵字為準 |
| `data-level` | ✅ | 缺了左緣色條與行動佇列都抓不到 |
| `data-draft` | A 級必填 | 不可有半形雙引號 `"`、不可有 `<` `>` |
| `data-topic` | 選配 | B 級可加「一句可做成貼文的切角」，會顯示在內容選題後面 |

## 5. 意圖分級（`data-level` 取值）

| data-level | 判準 | ChannelDeco 動作 |
|---|---|---|
| `A` 高意圖 | 有**地區** ＋（預算／時程／明確求推薦統包設計師）任一 | 優先接觸，24 小時內回頭看是否已被回覆 |
| `B` 問題意圖 | 有明確裝潢困擾／提問，但未進購買決策期 | 留言給專業判斷，納入內容題庫 |
| `C` 情緒共鳴 | 分享裝潢壓力／後悔故事，無明確需求 | 先接情緒再補一句觀點 |
| `D` 低對頻 | 純娛樂 UGC／爆料八卦／同業日常 | 只記錄市場訊號，不追蹤 |
| `風險` | 投訴點名、裝潢蟑螂爆料、糾紛、家庭敏感議題、協尋 | 一律不留言、不自薦、不批評同業 |

**判級參考（八類切入點）**：①無方向求推薦 ②預算明確求解 ③決策/審美兩難 ④找錯人踩雷
⑤交屋/時程焦慮 ⑥生活機能疑慮 ⑦軟硬裝決策兩難 ⑧老屋/租屋翻新。
①②⑤＋有地區通常是 A；③⑥⑦與一般提問多為 B。

**A 級卡片格式建議**：`.post-date` 用「日期 · 一句主題」（例：`2026-9-4 · 高雄新成屋13坪求報價`），
地區用含 📍 的 `.badge`（例：`<span class="badge">📍高雄</span>`）—— 行動佇列會自動抓這兩者組出清單。
官方帳號 @channel.deco 已留言的貼文，作者旁加 ⭐。

## 5.5 品牌歸屬與內容流程（2026-09-11 Tilandky 裁定）

> ⛔ **ChannelDeco 是 Hailey 的品牌。Jessica 對應的是 Tru-Mi。**
> 兩邊的品牌語感與 Real-World Validation **不可混用**，
> 也不可把 Tru-Mi／Jessica 的語氣規格套到 ChannelDeco 內容上。

| 階段 | 做什麼 | Owner |
|---|---|---|
| ① AI 生成 | 依 ChannelDeco 品牌語氣、既有真實語料、貼文情境產生貼文或 Threads 回覆建議 | AI |
| ② Human Write | 人工改寫。**重點不是校稿，是把「AI 寫得對」轉成「本人真的會這樣說」** | Hailey／ChannelDeco 團隊 |
| ③ 慣用語檢查 | 對照 ChannelDeco 語感庫檢查常用詞、句型、稱呼、CTA、禁用語、長度與 AI 味；**可機器判定的硬規則必須實測**（`tools/content_gate.ps1`） | AI ＋ 工具 |
| ④ Real-World Validation | 「這句我會不會真的留言出去？」 | **Hailey／ChannelDeco 團隊** |

### Attribution 原則（2026-09-11 Tilandky 裁定）

```
已知品牌來源 ≠ 已知真人作者

@channel.deco 語料  →  標「ChannelDeco 品牌語料」
只有具備作者證據    →  才標「Hailey 個人語料」
```

修正跨品牌汙染時**不得用「另一個真人名字」取代錯誤的真人名字**。
已確認的是「品牌 owner／Human Write owner ＝ Hailey／ChannelDeco」，
但這**推不出**某個具體職責（例如線上視訊由誰承接）由 Hailey 本人執行。
證據不足時改成**不指名的敘述**；連該項服務本身都沒有可靠來源時，標為**待確認**，不要保留成事實。

*依據*：2026-09-11 修掉三處「由 Jessica 以線上視訊接案」時，若直接替換成 Hailey，
等於用一個未驗證的真人職責取代一個已知錯誤，製造出新的假事實。
**品牌歸屬與真人職責是兩個獨立的 evidence 欄位。**

⛔ **兩個 Gate 不可合併**：
- 「通過品牌語氣規格」＝ **規則符合度**（③）
- 「Human Write 完成」＝ **人的語言所有權**（②）

前者 PASS 不等於後者完成，狀態要分開記：

```
Content            : CONTENT_COMPLETE
Validation         : PASS（Automated Gate）
Human Write        : [DONE ／ NOT RUN]
Real-World         : [DONE ／ NOT RUN]
Owner              : Hailey / ChannelDeco
```

## 6. 留言草稿口徑

> **2026-09-11 更新**：舊口徑「不放連結、不自薦」已作廢。正本＝`語感規格_v0.1_2026-09-11.md` §G／§I。

走 **ChannelDeco 三段式**：

```
① 接住對方寫出來的條件，給一句判斷
② 給一個具體、可驗證的技術提醒（對方沒問、但實際會踩到的那一題）
③ 收尾：「我們是 Channel Deco，做輕裝修＋軟裝設計，歡迎跟我們聊聊。」
```

硬規則：用「我們」不用「我」｜**emoji 0 個**｜不批評同業｜3–5 句、約 **100–150 字**｜
`data-draft` 內不可有半形雙引號 `"`、不可有 `<` `>`。
「聊聊」是招牌收尾，**不要改成「歡迎諮詢」「歡迎詢問」「歡迎私訊」**。

依 8 類切入點決定第 ① 段切角（例：⑤交屋時程 → 先談工期綁合約＋分階段；②預算明確 → 談把錢花在收納／採光，風格交給軟裝）。
**風險級貼文為唯一例外**：維持不批評、不自薦，`data-draft` 留空或寫「（不留言，避免涉入敏感議題）」，只轉化為自家透明度內容題材。

## 7. 兩支排程的分工邊界

| 區塊 | 週一完整版 | 每日 A 級掃描 |
|---|---|---|
| 貼文卡片 | 新增／替換 | 只在 `#postsGrid` 最前面新增 A 級 |
| 每日更新提醒 `#dailyBrief` | 也要更新 | **每天必做** |
| 本週社群關鍵信號／建議本週發文方向／語意集群健康度檢查 | 維護 | **只讀不改** |
| 熱門話題 Top 4 | 依本週新增重排 | 有更高讚才更新，否則不動 |
| header 日期與所有計數 | 用實際 grep 重算 | 用實際 grep 重算 |

**同日衝突：每週一完整版 > 每日 A 級掃描。** 每日版當天自行跳過，不得覆蓋或重複週更新增的卡片。

## 8. Content Gate：宣告 `CONTENT_COMPLETE` 前的驗證清單

> ⛔ **硬規則（2026-09-11 Tilandky 裁決）：凡可機器判定的 canonical 硬規則，
> 不得以目測、估算或抽查宣告 PASS，一律實測全部項目。**
>
> 涵蓋範圍：字數上下限、emoji 數、禁用字元（`"` `<` `>`）、必要收尾（「聊聊」）、
> 必填屬性（`data-added`／`data-kw`／`data-level`／A 級的 `data-draft`）、
> 重複 POSTID、各項計數一致性、div 平衡、LF／BOM。
>
> **執行方式**：`.\tools\content_gate.ps1`（Windows PowerShell，repo 根目錄執行）。
> 離開碼 0 才可宣告 `CONTENT_COMPLETE`。容器端 bash 不可用時，
> 可用瀏覽器 JS 引擎對實際字串量測代替，**但不得改用目測**。
>
> *依據（三個獨立情境，同方向）*：2026-09-11 五則 `data-draft` 以目測抽查宣告
> 通過，實測為 151–161 字，全數超過 §I 的 150 字上限；同日 HTML 結構驗證以
> 「結構比對」代替實跑；KPI A 級沿用舊值，實際已少算 2。
> 這是已發生事故的防呆，不是預防性設計。

以下全過才可以宣告 `CONTENT_COMPLETE`、把發布指令交給 Windows。
任一項不過就修好再交，不要留下計數與卡片不一致的版本。

- [ ] `<div>`／`</div>` 數量平衡為 0、無 `.post-card` 巢狀
- [ ] 無重複 `post/POSTID`（與週更撞號時保留週更那張）
- [ ] 最後一段 `<script>` 存成 .js 跑 `node --check` 通過
- [ ] 有 jsdom 時：`.kw-group` 為 7、收合狀態下 DOM 內 `.post-card` 為 0、`#dbTasks` 項數＝當日新增則數、`#aqList` 項數＝A 級總數
- [ ] header 總數／各類別 `.cs`／KPI 五格皆為實際 grep 結果，A 級數字與行動佇列一致
- [ ] 五個 `data-level` 計數加總＝總卡片數；七個 `data-kw` 計數加總＝總卡片數
- [ ] 行尾維持全 LF、無 BOM（`grep -c $'\r'` 應為 0）——避免整檔換行漂移蓋掉別人的修改
- [ ] 覆寫前後各驗一次 `git hash-object index.html`，並確認 hash 已穩定（間隔 30 秒兩次相同）

> ⚠️ **用 Grep 工具代替 bash 統計時要加 `<div class="post-card` 前綴**，
> 否則會把 `<style>` 裡的 `.post-card[data-level="A"]` 等 CSS 選擇器一起算進去
> （2026-09-11 實測多算 7 筆）。加總對不上總卡片數就是統計式寫錯了。

## 9. Deployment Gate：發布後的驗證

**Content Gate 過 ≠ 已發布。** 容器端不碰 git（見
[`_routine_daily_A_sweep.md`](_routine_daily_A_sweep.md) 步驟 9），
發布由 Windows 主機人工執行**正常 branch workflow**：
`fetch → gate → reset --mixed FETCH_HEAD → add → commit → push channeldeco main:refs/heads/main`。

🚫 **不再使用「Windows 直接推容器算出的 dangling commit SHA」**——
那會讓遠端前進而本機 `main` ref 不前進，divergence 每天累積，
2026-09-11 已實際造成 `non-fast-forward` 而中斷發布。

驗證擇一：

```powershell
git fetch channeldeco main
git diff FETCH_HEAD -- index.html     # 輸出為空 → DEPLOY_VERIFIED
```

```bash
bash tools/deploy_verify.sh
```

| 退出碼 | 意義 | 狀態 |
|---|---|---|
| 0 | 遠端＝本機 | **`DEPLOY_VERIFIED`** ← 只有這裡才叫「發布完成」 |
| 1 | 遠端落後本機 | `DEPLOY_WAITING` / `DEPLOY_BLOCKED` |
| 2 | 讀不到遠端 | `UNKNOWN`——不得宣稱已發布，也不得記成 0 |

狀態模型 `CONTENT_COMPLETE → DEPLOY_WAITING → DEPLOY_PUSHED → DEPLOY_VERIFIED`，
容器端結束時最多只能宣告 `CONTENT_COMPLETE`。
若恢復「容器先算 commit」作為 candidate／evidence，模型改為
`CONTENT_COMPLETE → COMMIT_CANDIDATE_READY → Windows branch workflow → DEPLOY_PUSHED → DEPLOY_VERIFIED`，
且 **`COMMIT_CANDIDATE_READY` 不等於「Windows 直接推這顆 SHA」**。

**執行環境故障**（如容器 `Plan9 share "c" is not mounted`）歸類為 **Environment Failure**，
與 Git 發布流程缺陷分開記——兩者根因不同、修法也不同。

canonical 規範：`000_Agent/knowledge/EXECUTION-BOUNDARY-STANDARD.md`
憑證規範：[`GITHUB-AUTH-STANDARD.md`](GITHUB-AUTH-STANDARD.md)
