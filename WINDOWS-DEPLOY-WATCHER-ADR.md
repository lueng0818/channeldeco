# ADR：Windows Deployment Watcher v1 設計決策紀錄

```
Status              : ACCEPTED — design decisions only
Implementation      : NOT_STARTED
Runtime authority   : UNCHANGED
Producer schema     : FROZEN / LEGACY_V0
```

> 建立日期：2026-09-07
> 姊妹檔：[`GITHUB-AUTH-STANDARD.md`](GITHUB-AUTH-STANDARD.md)（憑證放哪裡）
> 　　　　`000_Agent/knowledge/EXECUTION-BOUNDARY-STANDARD.md`（哪個 runtime 有資格用它）
> 本檔管的是第三件事：**跨 runtime 的部署交接要怎麼談。**

---

## 0. 這份文件是什麼、不是什麼

**是**：一份決策紀錄。記下 2026-09-07 已經談定的邊界，以及還沒定、必須等 watcher v1 設計時一起決定的項目。

**不是**：實作規範。
**本檔不新增任何執行授權。** 除第 4 節所記錄、已於既有排程 prompt 生效的三行報告契約外，其餘內容均為設計決策或待決事項，**不得**直接作為修改系統或啟用自動部署的依據。

> ⚠️ **給下一個讀到這份文件的 Agent／人：**
> 本檔第 2～4 節的「已定案」指的是**設計方向已定案**，不是「系統已經這樣運作」。
> Windows watcher **尚未建置**。目前唯一在跑的部署路徑是**人工**執行
> `github_push.sh` / `git push`。
> **不得**依據本檔去修改 producer、排程 prompt、`DEPLOY_READY.json` 欄位，
> 或啟用任何自動部署行為。要動，先走第 6 節的 migration 順序。

---

## 1. 目前狀態（事實，非設計）

| 項目 | 狀態 |
|---|---|
| Producer（Tru-Mi `DEPLOY_READY.json`） | **FROZEN**。欄位凍結至 watcher contract 定稿，不得擴充或改名 |
| Envelope 版本 | **LEGACY_V0（implicit）**。`schema_version` 刻意**不寫入** JSON |
| Windows watcher | **NOT_AVAILABLE**。未建置、未實測 |
| Legacy 自動執行 | **FORBIDDEN** |
| ChannelDeco 是否比照產生 envelope | **DEFERRED**。暫不新增，維持 commit SHA + 人工 push |
| 共用 envelope schema 抽取 | **AFTER WATCHER V1 DESIGN** |
| 實際部署方式 | 人工（Windows 主機，走既有 `gh` credential helper） |

**為什麼 v0 不寫 `schema_version`**：欄位已宣布凍結，此時只為了「未來可能有用」再改一次 producer，會破壞剛建立的治理邊界，也讓凍結變成隨時可談。版本邊界留到 producer、schema、adapter、validator 一起升版時劃，會乾淨得多。

**「先統一部署意圖，不統一部署載荷格式」**：Tru-Mi 是 Windows 端 clone + commit + push；ChannelDeco 是容器端算出 commit object、Windows 端推 SHA。兩者狀態模型相同、載荷不同。強行共用 JSON 只會做出「看起來一致、實際 runtime 不同」的假統一——那正是本檔要避免的 drift 形態。

---

## 2. 已定案：接收原則（fail-closed）

watcher 的 parser 採 fail-closed。四個分支，只有最後一個放行：

```text
schema_version missing
  → LEGACY_V0 / REFUSE_AUTO_EXECUTION

schema_version unsupported
  → UNSUPPORTED_SCHEMA / REFUSE_AUTO_EXECUTION

schema_version supported but validation failed
  → INVALID_ENVELOPE / REFUSE_AUTO_EXECUTION

schema valid + runtime boundary valid + deploy intent authorized
  → ACCEPTED
```

**推測可以用來分類 legacy，但不能成為自動執行授權。**
watcher 可以靠檔名或 `pipeline` 欄推測「這大概是 Tru-Mi 的 v0 檔」以便分類與告警，但**不得**據此繼續執行部署。缺版本就是拒絕，沒有「合理推斷後照樣處理」這個分支。

拒絕不等於失敗——對 v0 envelope 而言，`LEGACY_V0 / REFUSE_AUTO_EXECUTION` 是**預期且正確**的結果。

---

## 3. 已定案：授權邊界

**授權來源是 watcher 側的靜態政策，不是 envelope 的內容。**

| 角色 | 定位 |
|---|---|
| envelope 的 `deploy_intent` | **宣告**。用於與政策比對，宣告與政策不符即 REFUSE |
| watcher 側 allowlist（`project → adapter → repo`） | **授權**。唯一的授權來源 |

**理由（這條是安全性的，不是整潔度的）**：
envelope 由容器端寫出，而容器依設計**不該有部署能力**。watcher 跑在持有 `gh` 憑證的 Windows 主機上。若 watcher 信任檔案內容來決定推不推、推到哪個 repo，等於讓「能寫這個檔的東西」自己授權自己被部署——部署權會沿另一條路徑從 Windows 遞回容器。

這與 2026-09-05「為了讓容器能推而加裝憑證」是同一個形狀，只是換了介面。`GITHUB-AUTH-STANDARD.md` 擋住了「把憑證塞進容器」，本節擋的是「讓容器間接指揮持有憑證的主機」。

---

## 4. 已定案：證據與狀態階梯

四個階段語意互斥，**不得跳格**，也不得用前一格當後一格的證據：

| 階段 | 意義 | 最低證據 |
|---|---|---|
| `emitted` | 派送物件已產出 | producer 成功產出紀錄、schema／內容可解析、artifact hash 已記錄 |
| `accepted` | watcher 已收件並通過驗證 | watcher 接收紀錄與所套用的政策、schema 驗證結果 |
| `executed` | 部署動作已執行 | 實際部署命令的結果，及對應的 artifact／commit 識別 |
| `remote verified` | 遠端內容＝本次部署的內容 | 遠端目標內容與**本次部署所固定的** artifact hash 一致 |

> **`DEPLOY_READY.json` 的存在本身不是成功證據。** 檔案存在只代表磁碟上有一個檔，
> 不代表它可解析、內容有效、或 hash 已記錄。`emitted` 的最低證據是上表第一列，不是「檔案在」。

升級為 `DEPLOY_VERIFIED` 的必要條件摘要：

```text
DEPLOY_READY
+ watcher accepted
+ deploy execution evidence
+ remote hash verification
= DEPLOY_VERIFIED
```

> ⚠️ 這是**必要條件的摘要，不是判定式**。四個字串各自存在不代表條件成立——
> 仍須驗證它們指向**同一個** request／job、**同一組** artifact、**同一次**部署證據。
> 四項來自不同批次卻被湊在一起，是這個模型最容易被繞過的方式；
> 關聯鍵怎麼設（`request_id` / `job_id` / artifact hash 的綁定關係）屬第 5 節待決。

目前只成立第一項。

### 三行報告契約（**本節是唯一已上線生效的部分**）

已寫入 `tru-mi-daily-threads-update` 排程 prompt：

```text
Dispatch : 派送物件有沒有產生
Executor : 有沒有人／程式真正接手
Action   : 下一步到底是人工還是自動
```

現階段固定值（watcher 實測通過前不得改動、不得依當次執行狀況自行判斷）：

```text
Dispatch : DEPLOY_READY artifact emitted
Executor : NOT_AVAILABLE
Action   : MANUAL_WINDOWS_DEPLOY_REQUIRED
```

watcher v1 通過第 6 節全部八步後，才允許：

```text
Executor : WINDOWS_WATCHER
Action   : QUEUED / CONSUMED
```

---

## 5. v1 待決（**尚未定案，不得當成規則實作**）

### 5.1 拒絕後的處置語意（quarantine）

**需求（已定案）**：拒絕後**不得無限重讀**，也**不得刪除診斷證據**。
壞掉的 envelope 若原地保留，每個輪詢週期會重觸發一次告警；直接刪除則失去事後追查依據。

**機制（未定案）**：
> ⚠️ **不要重用 `consumed_by` / `consumed_at` 表示拒絕。**
> `consumed` 的通常語意是「已被接收或處理」。若同一組欄位同時承載拒絕、接收、執行三種狀態，會再次把第 4 節剛拆乾淨的東西混回去。

候選方向（擇一或組合，等 v1 schema 一起決定）：獨立狀態欄位／獨立 quarantine manifest／移檔至 quarantine 目錄並保留原件。

### 5.2 TOCTOU：驗證的 bytes 必須就是部署的 bytes

**風險**：envelope 記錄 artifact hash 的時點（emit）與實際讀檔部署的時點（consume）之間，檔案可能已被下一次排程覆寫。每日排程 09:10 產出，watcher 若稍晚取件即有機會撞上。

**已知不足的解法**：「推送前重算一次 hash 比對」**不足以解決**——重算完到實際讀取之間仍有覆寫窗口，只是把競爭窗口縮小，沒有消除。

**核心要求（已定案）**：驗證的 bytes 必須就是實際部署的 bytes。

**機制（未定案）**：immutable snapshot／content-addressed staging／互斥鎖保護下複製並驗證固定版本再由該版本部署。

### 5.3 adapter 與 repo allowlist 的具體結構

第 3 節定了「授權在 watcher 側」，但政策表的實際形狀未定：`project` 與 `deploy_adapter` 的對應關係、repo allowlist 的表達方式、以及 runtime boundary 的驗證要驗到什麼程度。

### 5.4 參考：canonical envelope 的預期界線（草案，非規範）

v1 設計時的起點，**不是現行格式**：

```text
Canonical Envelope
├─ schema_version
├─ request_id
├─ project
├─ state = DEPLOY_READY
├─ runtime_boundary = windows-host
├─ artifacts[]
├─ validation
├─ created_at
├─ consumed_by
└─ payload
    └─ project-specific
```

Envelope 統一，Payload 不統一。watcher 只先處理 envelope，再依 `project` / `deploy_adapter` 路由。
其他曾討論到的共用欄位：`job_id`、`artifact_hashes`、`validation_status`、`deploy_intent`、`execution_evidence`。

---

## 6. Migration 順序（八步，未開始）

```text
1. 定義 canonical envelope schema v1
2. 定義 Tru-Mi payload adapter
3. 定義 ChannelDeco payload adapter
4. watcher 實作 schema validation
5. producer 改產生 schema_version = 1
6. fixture / negative controls
7. Windows 實測一輪
8. 通過後才允許 WINDOWS_WATCHER / QUEUED / CONSUMED
```

**第 7 步實測通過前，不得啟用自動部署。** 第 8 步是唯一可以動第 4 節那兩個固定值的時機。
producer（第 5 步）刻意排在 validator（第 4 步）之後：先有能拒絕的驗證器，才開始產生新版本，否則沒東西能擋住寫壞的 envelope。

---

## 7. 非目標

- ❌ 不新增任何憑證，不改變憑證存放方式（見 `GITHUB-AUTH-STANDARD.md`）
- ❌ 不讓容器取得部署權，不在容器內裝 `gh`、硬編路徑或建 token 檔
- ❌ 不修改現行 v0 producer（含不補 `schema_version`）
- ❌ 不提前建立 watcher，不寫「先跑起來再說」的暫時版
- ❌ 不為了格式一致，強迫 Tru-Mi 與 ChannelDeco 兩套部署機制假裝相同
- ❌ 不把尚未實作的設計決策當成已生效規則（見第 0 節警告；本檔唯一已生效者為第 4 節的三行報告契約）

---

## 8. 決策脈絡

三次同源事故推出本檔：

| 日期 | 現象 | 根因 | 出處 |
|---|---|---|---|
| 2026-09-05 | Tru-Mi 排程「找不到 gh」 | 容器與 Windows 是不同 execution boundary；當時被誤判為環境故障 | 轉錄自 `_routine_daily_A_sweep.md` 步驟 9 |
| 2026-09-06 | ChannelDeco `could not read Username for 'https://github.com'` | 同上。SOP 把「內容完成」與「發布完成」寫成同一狀態，撞邊界時 Agent 會去找繞路 | 同上 |
| 2026-09-07 | 週一版排程 prompt **保留已廢止的認證指示**（內容宣稱 PAT 存放於 `channeldeco` remote URL，並要求修復 `.git/config` 時「把含 token 的 url 原樣保留貼回去」） | `daily-sop.md` 與 `GITHUB-AUTH-STANDARD.md` 早已 migrate，但排程 prompt 落後——**決策做了，沒寫到下一個 agent 會讀的地方** | 本次執行實測 |

> **關於第三列的範圍**：這一列描述的是**文件內容過期**，不是當日存在有效憑證。
> 2026-09-07 實測時 `.git/config` 的 `channeldeco` remote 為無憑證形式，
> 憑證 pattern 命中數 0；該次 push 因此以「無 credential」失敗，由人工在 Windows 端完成。
> 舊 prompt 的指示已於同日改寫。
>
> 前兩列為既有文件之轉錄，其日期、原文與因果**以正式事故報告為準**；
> 若與事故報告有出入，以報告為準並回頭修訂本表。
> 本表僅用於說明本檔的成因，**不構成 credential incident 的狀態變更**——
> incident 狀態一律以 `GITHUB-AUTH-STANDARD.md` 第六、八節為準（兩條狀態線互不影響）。

第三列是本檔存在的直接理由：把決策留在對話裡，等同於沒做。

---

## 9. 變更紀錄

| 日期 | 變更 |
|---|---|
| 2026-09-07 | 建檔。記錄凍結狀態、fail-closed 接收原則、授權邊界、狀態階梯、三項 v1 待決、八步 migration |
| 2026-09-07 | 文字修訂（不改變任何已定案架構）：① 第 0／7 節統一「生效」範圍，明列三行報告契約為唯一例外 ② 第 4 節證據表改為「最低證據」，並標註四項升級條件為必要條件摘要、須驗證同一 request／artifact／部署證據的關聯 ③ 第 8 節加註出處與範圍，第三列改述為「舊版 prompt 保留已廢止的認證指示」 |
