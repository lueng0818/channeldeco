# ChannelDeco 儀表板｜排程 Skill 索引

這個資料夾放的是維護 [`index.html`](../index.html)（Threads 社群監測儀表板）的兩支 cowork 排程指令，
是本機排程檔的**版本控管對照本**。

## 檔案對照

| repo 內檔案 | 本機實際執行的檔案 | 排程 | cron |
|---|---|---|---|
| [`threads-home-deco-daily.SKILL.md`](threads-home-deco-daily.SKILL.md) | `C:\Users\...\Documents\Claude\Scheduled\threads-home-deco-daily\SKILL.md` | 每週一完整七類別更新 | `0 9 * * 1` |
| [`threads-home-deco-daily-a-sweep.SKILL.md`](threads-home-deco-daily-a-sweep.SKILL.md) | `C:\Users\...\Documents\Claude\Scheduled\threads-home-deco-daily-a-sweep\SKILL.md` | 每日輕量 A 級掃描 | `0 9 * * 0,2-6` |

> ⚠️ **修改排程行為時請改本機的 SKILL.md，再把內容同步回這裡。**
> repo 內的副本只作為版本紀錄與 review 用，排程不會讀取這裡的檔案。

## 相關文件

- [`../_routine_daily_A_sweep.md`](../_routine_daily_A_sweep.md) — 每日 A 級掃描的人類可讀說明版
- [`../_routine_persist_rules.md`](../_routine_persist_rules.md) — `index.html` 的固定結構保留規則（不可破壞清單）

## 兩支排程的關係

```
週一           threads-home-deco-daily          完整七類別更新（最高優先）
週日、週二～六   threads-home-deco-daily-a-sweep   只補抓新的 A 級高意圖貼文
```

兩支**共用同一份 `index.html` 與同一套 GitHub 推送機制**，同日先後寫入會互相覆蓋卡片與統計數字。

**優先順序固定：每週一完整版 > 每日 A 級掃描。**
每日版在步驟 0 會自行做三項避讓檢查（是否週一／是否已有當天週更標記／當天卡片數是否超過每日規模），
任一成立就完全不動檔案、不推送。

## 共同規則摘要

- 七個固定類別：軟裝設計／輕裝潢／空間佈置／室內設計／裝潢後悔／寵物宅／空間佈置靈感
- 意圖分級 `data-level`：`A` 高意圖／`B` 問題意圖／`C` 情緒共鳴／`D` 低對頻／`風險`
- 每張卡片開頭 div 必填 `data-added`、`data-kw`、`data-level`；A 級另加 `data-draft`
- 所有計數（總數、各類別 `.cs`、KPI 五格）一律用實際 grep 重算，**不要沿用舊數字往上加**
- 推送用 git plumbing（`hash-object` → `mktree` → `commit-tree` → `push`），雲端掛載資料夾一般 git 指令會因 lock 檔失敗

## 品牌背景

- 品牌：ChannelDeco 伽宜諾
- 服務：輕裝修 ＋ 軟裝設計、空間陳列擺拍、顧問諮詢
- 服務區域：高雄、屏東、台南、桃園、新北、台北
- 目標受眾：首購成家小白、品味租屋族、局部換殼族、長輩居家照護族
- 官方網站：https://channeldeco.com/
