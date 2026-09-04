# ChannelDeco 儀表板｜固定結構保留規則

> **2026-07-25 建立｜2026-09-04 全面改寫，內容與現行兩支排程 SKILL.md 同步。**
>
> 這份是 `index.html` 的「不可破壞清單」。兩支排程每次更新**只新增／替換卡片與數字**，
> 以下結構一律不可移除或改動；若發現被移除或損毀，**應還原而非略過**。
>
> 對應排程檔：
> - `skills/threads-home-deco-daily.SKILL.md`（週一完整版）
> - `skills/threads-home-deco-daily-a-sweep.SKILL.md`（每日 A 級掃描）

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

## 6. 留言草稿口徑

2–4 句、先直接解對方的題、給一個具體可用的判斷或方向；
**不放連結、不自薦 ChannelDeco、不批評同業**；溫暖真實、用生活語言不用術語。
依 8 類切入點決定切角（例：⑤交屋時程 → 先談工期綁合約＋分階段；②預算明確 → 談把錢花在收納／採光，風格交給軟裝）。
風險／同業帳號：`data-draft` 留空或寫「（不留言，避免涉入敏感議題）」。

## 7. 兩支排程的分工邊界

| 區塊 | 週一完整版 | 每日 A 級掃描 |
|---|---|---|
| 貼文卡片 | 新增／替換 | 只在 `#postsGrid` 最前面新增 A 級 |
| 每日更新提醒 `#dailyBrief` | 也要更新 | **每天必做** |
| 本週社群關鍵信號／建議本週發文方向／語意集群健康度檢查 | 維護 | **只讀不改** |
| 熱門話題 Top 4 | 依本週新增重排 | 有更高讚才更新，否則不動 |
| header 日期與所有計數 | 用實際 grep 重算 | 用實際 grep 重算 |

**同日衝突：每週一完整版 > 每日 A 級掃描。** 每日版當天自行跳過，不得覆蓋或重複週更新增的卡片。

## 8. 推送前驗證清單

- [ ] `<div>`／`</div>` 數量平衡為 0、無 `.post-card` 巢狀
- [ ] 無重複 `post/POSTID`
- [ ] 最後一段 `<script>` 存成 .js 跑 `node --check` 通過
- [ ] 有 jsdom 時：`.kw-group` 為 7、收合狀態下 DOM 內 `.post-card` 為 0、`#dbTasks` 項數＝當日新增則數、`#aqList` 項數＝A 級總數
- [ ] header 總數／各類別 `.cs`／KPI 五格皆為實際 grep 結果，A 級數字與行動佇列一致
