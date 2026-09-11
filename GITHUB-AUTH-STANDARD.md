# GitHub 認證標準（跨專案唯一事實來源）

> 適用範圍：所有專案、所有排程、所有 Agent、所有腳本。
> 本檔為 canonical 規則。任何其他文件與本檔衝突時，一律以本檔為準。
> 建立日期：2026-09-05｜起因：明碼 PAT 外洩事件收尾
> 2026-09-06 補第五節（Evidence Rule）與執行邊界連結。
>
> **姊妹檔**：`000_Agent/knowledge/EXECUTION-BOUNDARY-STANDARD.md`
> 本檔管「憑證放哪裡」，姊妹檔管「哪個 runtime 有資格用它」。
> 兩份要一起讀——**「為了讓排程容器能 push 而把憑證塞回容器」是本檔最常見的破口**，
> 09-05 的外洩就是這樣長出來的。

---

## 一、標準（必須遵守）

GitHub 操作統一使用 `gh auth login` 建立的系統憑證儲存，並透過 `gh auth setup-git`
設定 Git credential helper（Windows 上由 Windows keyring 保管）。

### 禁止的到底是什麼（2026-09-06 精確化）

日常 Git 操作**不應依賴人工建立、散落於檔案／remote URL／shell history 的 PAT**。
憑證統一由 GitHub CLI／credential helper 的安全儲存機制管理。
若目前沒有其他系統明確依賴既有 fine-grained PAT，可全部撤銷。

> ⚠️ **不要把本檔讀成「帳號上永遠不能存在任何 token 類 credential」。**
> `gh auth login` 本身仍會使用 GitHub 核發的認證憑證。
> 真正禁止的是**人工管理、明碼保存、嵌入指令與 URL 的長期憑證**——
> 差別在「誰管理、存在哪裡、活多久」，不在「是不是 token」。

**禁止**將 PAT 寫入以下任何位置：

- `.github_token`、`token.txt` 或任何同性質的明碼檔
- Shell script（含 `github_push.sh` 這類推送腳本）
- `.git/config`（含其備份檔，例如 `config.bak.YYYYMMDD`）
- Git remote URL（`https://<token>@github.com/...`）
- 環境變數檔、設定檔、文件、註解、聊天訊息

Git remote **必須維持無憑證形式**：

```
https://github.com/OWNER/REPO.git
```

若認證失效，**重新執行 `gh auth login`**。
不得以「建立明碼 token 檔」或「把 token 塞回 remote URL」作為替代方案。

---

## 二、認證流程

### 首次設定（人工，一次即可）

```bash
gh auth login                 # 選 HTTPS，依提示於瀏覽器完成授權
gh auth setup-git             # 讓 git 走 credential helper
```

### 每次推送前檢查（Agent／腳本可執行）

```bash
gh auth status                # 未登入或過期會非零退出
```

`gh auth status` 正常 → 直接用一般 `git push`，不需要任何 token 處理。

### 認證失效時的正確處置

1. 回報使用者：`gh auth status` 失敗，請執行 `gh auth login` 重新登入。
2. **不要**索取 token 字串。
3. **不要**建立明碼 token 檔或改寫 remote URL 當作繞路。
4. 該次排程視為未完成，如實回報，不要偽裝成功。

---

## 三、Agent 行為守則

| 情境 | 正確做法 | 禁止做法 |
|---|---|---|
| 推送前 | `gh auth status` | 讀 `.github_token` / `token.txt` |
| 推送 | `git push`（credential helper 自動帶憑證） | 把 token 拼進 URL |
| 401／403 | 回報請使用者 `gh auth login` | 索取 token、建立明碼檔 |
| 修復 `.git/config` | 只還原 core／remote／branch 區塊，remote URL 保持無憑證 | 「保留原本含 token 的 url 貼回去」 |
| 看到殘留明碼 token | 立即回報並建議 revoke | 拿它來完成任務 |

**特別註記**：舊文件曾寫「修復 `.git/config` 時務必把含 token 的 url 原樣保留貼回去」。
這條指示**已作廢**，它正是這次事件把明碼憑證持續複製下去的主因。

---

## 四、Evidence Rule：什麼才算「有推送能力」的證據

**公開 repo 的 anonymous read 成功，不得視為 write authorization 的證據。**

| 想確認的事 | 正確做法 | 不能用什麼 |
|---|---|---|
| repo 讀得到嗎 | `git ls-remote` | — |
| **這個環境推得動嗎** | `git push --dry-run` | ❌ `git ls-remote`（公開 repo 匿名也會 exit 0） |
| GitHub 上的內容等於本機嗎 | `tools/deploy_verify.sh` | ❌ `git push` 的 exit code |

實測佐證（2026-09-05）：Tru-Mi repo 為公開，無任何憑證下 `ls-remote` exit 0，
但 `push --dry-run` 回 `could not read Username for 'https://github.com'`。

**但日常不必每次先 dry-run 再 push。** Windows Deployment Pipeline 正常運作後，
真正 push 的 exit code ＋ 後端 `deploy_verify.sh` 已經是更直接的 evidence；
`push --dry-run` 是用來**診斷當前 runtime 有沒有資格推**，不是每次推送的前置檢查。

### 推論：容器端不該跑 `gh auth status`

排程容器裡根本沒有 `gh`，問了也沒意義。
容器回報「找不到 gh」時，正確結論是「這個 runtime 不負責部署」，
不是「環境壞了要修」——**不得**硬編路徑或建 token 檔去「修好」它。
細節見 `000_Agent/knowledge/EXECUTION-BOUNDARY-STANDARD.md` Rule ①②。

---

## 五、Credential Audit Output Safety（2026-09-06 定案）

> 訂立起因：2026-09-06 為了查 09-05 事件的第 4 把 token，
> 稽核指令的**輸出**被原樣貼進 AI 對話，等於在稽核過程中新增一個 exposure surface。
> **用來找秘密的指令，其輸出本身也必須依秘密資料處理。**

### 規則

憑證稽核**不得輸出、複製或回傳**任何疑似 token、PAT、API key、password、secret 的完整內容。

稽核結果僅允許回報：

| 允許回報 | 範例 |
|---|---|
| 命中筆數 | `2 findings` |
| 檔案／來源類型 | `plaintext file` / `shell history` / `transcript` |
| 行號或位置 | `行 1、3` |
| 憑證類型 | `fine-grained PAT` |
| 是否已撤銷／待處理 | `REVOKED` / `PENDING` |

### 讀取 vs 輸出（不要混為一談）

**讀取秘密本身不是違規；把秘密輸出到非必要介面才是。**

> Credential audit 可以在受控執行環境內讀取秘密以完成必要判定，
> 但不得將秘密原值輸出至終端、log、AI 對話、報告或其他非必要介面。
> 如需比對，優先使用不可逆 fingerprint、hash、ID 或 metadata。

所以「兩個來源的 token 是不是同一把」是可以回答的——
在本機 `sha256sum` 比對、只回報 `相同／不同`，零暴露。
❌ 錯的寫法是「比對需要讀取原值，所以不能做」，那是把讀取誤當成輸出。

### Exposure surface 清單（都要當秘密資料處理）

Shell history、終端輸出、AI 對話逐字稿、CI/CD log、debug log、
錯誤訊息、螢幕截圖、issue／PR 內容。

### Evidence Gate 補充條款

> **「證明沒有 secret」≠「把搜尋到的 secret 貼出來」。**

要證明清乾淨了，正確做法是回報 **pattern count = 0**，
不是把命中內容列出來給人看。這與 Evidence Rule 同源：
證據要能支撐結論，但不該順手擴大暴露面。

---

## 六、Incident 狀態模型

Credential incident 與部署狀態是**兩條獨立狀態線**。
`DEPLOY_VERIFIED` 不因 credential incident 回退，
credential incident 也不因部署成功而視為關閉。

```text
CREDENTIAL INCIDENT — OPEN

Exposure surfaces
- token.txt             2 findings
- PowerShell history    1 finding
- conversation transcript
                        1 duplicated exposure

Containment required
- revoke obsolete fine-grained PATs
- remove plaintext credential file
- sanitize shell history

Optional retention reduction
- delete transcript containing revoked credential

Deployment
DEPLOY_VERIFIED
commit: ecf2685
credential incident does not roll back deployment state
```

### 關閉條件（四項全部成立才算 CLOSED）

1. GitHub 端相關舊 PAT 已撤銷
2. `token.txt` 不再存在明碼 credential
3. PowerShell history pattern count = `0`
4. `gh auth status` 與正常 Git 操作仍成功

### 逐字稿的狀態：`REVOKED / RESIDUAL RETENTION`

**不要標成「已關閉」。** 撤銷讓其中的 credential 失去授權能力，
但只要對話沒刪，字串本身仍存在於留存面。
Evidence Gate 不得把「**失效**」和「**不存在**」混成同一件事——
前者是 containment 完成，後者才是 exposure 消除。

---

## 七、稽核指令

定期在知識庫根目錄執行，確認沒有回退：

```bash
grep -rniE \
  'github_token|token\.txt|TOKEN_FILE|github_pat_|ghp_|https://[^[:space:]]+@github\.com' \
  . \
  --exclude-dir=.git \
  --exclude-dir=node_modules
```

重點不是找出 `token.txt` 這個檔案本身，而是找出
「請建立 token.txt」「從 `.github_token` 讀 token」「把 token 帶入 URL」
這類**操作說明**——它們才是讓風險重新長回來的來源。

備份檔也要一起看（`.git/config.bak.*`、`*.bak`、`*.old`），
這些是處理過程中最容易新生的明碼副本。

**還要查兩處檔案系統以外的地方**（09-05 事件的第 4 把 token 只留在這裡）：

- PowerShell history：`Get-Content (Get-PSReadlineOption).HistorySavePath | Select-String 'set-url|github_pat_|ghp_'`
- Claude／Codex 逐字稿：`git remote -v` 的原始輸出曾被逐字稿保存下來

再加一條邊界回退的稽核（避免有人把憑證塞回容器）：

```bash
grep -rniE 'where\.exe|Program Files.*gh|gh\.exe|PATH.*fallback.*gh' \
  . --include='*.md' --include='*.sh' --exclude-dir=.git --exclude-dir=node_modules
```

### ⚠️ 稽核指令的輸出要當秘密處理

執行上面任何一條 grep 後，**只回報命中筆數與位置**（見第五節）。
特別是 PowerShell history 那條——09-05 事件的第 4 把 token 就是因為
它的輸出被原樣貼出而多了一個 exposure surface。

正確的驗證寫法（只回一個數字）：

```powershell
$p = (Get-PSReadlineOption).HistorySavePath
(Get-Content $p | Select-String 'github_pat_|ghp_').Count    # 應為 0
```

---

## 八、2026-09-06 incident 處置紀錄

### ✅ INCIDENT_CLOSED（2026-09-07 11:29:16）

三項人工 Gate 全數 PASS，由 Tilandky 在 Windows security boundary 完成驗證並核准
（`VR-2026-09-06-CRED`）。Agent 未參與任何 credential 或帳號操作。

| Gate | 項目 | 結果 | 檢查範圍 |
|---|---|---|---|
| G1 | PAT revocation | PASS | 不再需要的舊 fine-grained PAT 全部撤銷 |
| G2 | PowerShell history residue | PASS | **僅限** `(Get-PSReadlineOption).HistorySavePath` 指向的 PSReadLine history 檔，**僅比對** `github_pat_` 與 `ghp_` 兩個前綴，命中數 0；操作者確認已完成本次事件要求的殘留處理 |
| G3 | Windows gh authentication | PASS | Windows GitHub CLI authentication: VERIFIED |

> ⛔ **G2 不是「全機已無任何憑證殘留」的證明。** 其他 shell history、log、備份、
> 不同前綴或已編碼的憑證均不在該檢查範圍內。結論不得擴大宣稱。

**closure 判定**：`INCIDENT_CLOSED`

**阻擋範圍**：本 incident 只阻擋自己的 closure 判定，不凍結其他工作——
內容生產、Skill 安裝、文件工作、其他 verification request 均不受影響；
`DEPLOY_VERIFIED`（`ecf2685`）不因本 incident 回退。


| Exposure surface | findings | 類型 | 位置 | 狀態 |
|---|---|---|---|---|
| `Tru-Mi專區/token.txt` | 2 | fine-grained PAT | 行 1、3 | `SANITIZED / TOMBSTONE REMAINS` — 明碼命中 2 → 0（2026-09-06 覆寫為 metadata tombstone）。檔案本體仍在，屬**檔案系統清理**，已非 credential exposure，**不列為 closure 條件** |
| PowerShell history | 1 | fine-grained PAT | `git remote set-url` 那行 | ✅ 已清除，指定範圍命中數 0（G2 PASS，範圍見上表註記） |
| AI 對話逐字稿 | 1（重複曝光） | 同上 | — | `REVOKED / RESIDUAL RETENTION` — G1 PASS 後其中的 credential 已失去授權能力；字串仍存在於留存面，**失效 ≠ 不存在**，刪除對話屬 residual cleanup，不阻擋 closure |

**未做比對**：`token.txt` 的 2 筆與 history 那 1 筆是否重複，未進行 fingerprint 比對——
因為這批 PAT 已無保留需求，「全部撤銷」是最少暴露面的處置，比對結果不影響任何決策。
（技術上可用本機 `sha256sum` 比對而不輸出原值，見第五節。）

**影響範圍檢查**：刪除 `token.txt` 前已確認全庫無任何腳本或文件引用它
（`github_push.sh` 走 `gh` ＋ clone，不讀 token 檔），移除不會破壞任何流程。

### credential migration

**Windows GitHub CLI authentication: VERIFIED**（2026-09-07 11:29:16）

憑證已由「人工管理的明碼 PAT」遷移到 `gh auth login` 建立的 credential helper
（Windows keyring）。依第五節，此處只記結論字串，
**不記帳號名稱、token id、scope 或到期日**。

---

## 九、殘留來源追蹤（跨 incident，持續維護）

> 第八節的 exposure 表記錄的是 **2026-09-06 incident 當時已知的來源**。
> 本節追蹤**每一個已知殘留來源及其處置狀態**，不受任一 incident 的 closure 影響。
> 新增殘留**不自動繼承**既有 incident 的撤銷結論或核准範圍。

### VR-2026-09-07-CONFIG-BAK｜Git config 備份殘留

**獨立調查，不變更第八節的 `INCIDENT_CLOSED` 判定。**
第八節 G2 的範圍註記已明載「其他 shell history、log、**備份**、不同前綴或已編碼的憑證
均不在該檢查範圍內」——本殘留正落在該 closure 未涵蓋的範圍，兩者不衝突。

| 欄位 | 內容 |
|---|---|
| 來源 | `chanel deco/.git/config.bak.20260905`（本機備份檔） |
| 命中 | 2 筆・行 9、15 |
| 類型 | fine-grained PAT（`github_pat_` 前綴） |
| 內容 fingerprint | `sha256:8cddcbd5e7649ab0`（前 16 碼）・兩筆為**同一把**（unique fingerprint 數 = 1） |
| 檔案 sha256 | `7909795733ae4ea0…` |
| 檔案 mtime | 2026-09-05 08:06:55 +0800 |
| Repository exposure | **未發現進入 Git 追蹤範圍**（遠端 tree 僅 `index.html`／`_routine_daily_A_sweep.md`／`_routine_persist_rules.md`／`skills`） |
| 狀態 | **`IDENTITY_UNCONFIRMED`**（登錄時為 `PENDING_IDENTIFICATION`，唯讀比對後未能確認身分） |
| 清理狀態 | **`SANITIZED / TOMBSTONE REMAINS`**（2026-09-07，明碼命中 2 → 0） |

### 清理結果（2026-09-07）

```text
VR-2026-09-07-CONFIG-BAK
File residual       : SANITIZED（明碼命中 2 → 0；tombstone 保留）
Cleanup verification: PASS
Credential identity : IDENTITY_UNCONFIRMED
Revocation status   : REVOKED_BY_SCOPE（2026-09-07）
```

> **`SANITIZED` 只描述檔案，不描述憑證。** 明碼已從磁碟移除，
> 這件事本身**不會**讓憑證失效；撤銷狀態獨立於清理狀態記錄。

### 撤銷判定：`REVOKED_BY_SCOPE`（非 `REVOKED_CONFIRMED`）

**依據**：操作者 Tilandky 於 2026-09-07 在 Windows security boundary 完成
**帳號全部 fine-grained PAT 撤銷**（人工 attestation）。
本殘留已確認為 `github_pat_` 前綴（fine-grained PAT），故**必然落在該撤銷範圍內**——
不需要先確認是哪一把，結論即成立。

**為什麼不是 `REVOKED_CONFIRMED`**：`Credential identity` 仍為 `IDENTITY_UNCONFIRMED`。
本案從未取得可對應的 fingerprint 或 token ID，因此能證明的是
「**這一類憑證全部失效**」，不是「**這一把已被逐一指認並撤銷**」。
兩者的證明結構不同，不得互相替代；日後若出現逐把識別需求，本案不可被引用為已識別案例。

**證據限制**

1. 撤銷為人工 attestation，Agent 未參與、亦無唯讀查證能力（本 runtime 無 `gh`、無授權憑證）。
2. 成立前提為該 PAT 屬於同一帳號（remote 與 `gh auth status` 均指向同一 GitHub 帳號）。
   若該 PAT 實際由其他帳號或組織核發，帳號層級的全撤銷不必然涵蓋——此前提未經獨立驗證。
3. `REVOKED_BY_SCOPE` 涵蓋的是**憑證授權能力**，不涵蓋殘留字串的存在
   （第五節：**失效 ≠ 不存在**）。

**處置方式**：覆寫為 metadata tombstone（沿用 `Tru-Mi專區/token.txt` 的既有作法），
未執行 hard delete。保留 fingerprint、原檔 hash、命中位置與 mtime 作為證據鏈。

**還原價值評估（為什麼可以清）**：清理前已逐項比對，該備份的區段與 key 結構
（`core` / `remote "origin"` / `branch "main"` / `remote "channeldeco"`）與當時的
`.git/config` **完全相同**，唯一差異是 remote URL 內嵌憑證。還原它等同把明碼 PAT 放回去，
故無保留必要。全庫亦無任何腳本或文件引用此備份。

**清理後驗證（六項全數 PASS）**

| 驗證項目 | 預期 | 實際 |
|---|---|---|
| 目標備份檔明碼 | 0 | 0 ✅ |
| 同類備份檔掃描 | 0 | 6 檔全數 0 ✅ |
| 現行 `.git/config` | 無嵌入憑證 | 0 ✅ |
| Git remote | 無憑證 URL | `channeldeco`／`origin` 皆為無憑證形式 ✅ |
| git 設定可讀 | 正常 | `git config --get` 正常回傳 ✅ |
| Windows `gh auth status` | 正常 | 已登入・keyring・HTTPS ✅ |

同類備份檔掃描範圍：`*.bak*`／`*.old`／`config*`／`*.orig`，排除 `node_modules`，共 6 檔。

> ⛔ **範圍限制（不得擴大宣稱）**：以上「命中 0」僅涵蓋本 runtime 可讀取且已掃描的路徑。
> 其他 shell history、log、AI 對話逐字稿、不同前綴或已編碼形式的憑證，
> 以及本 runtime 讀不到的 Windows 端位置**均不在範圍內**。
> 本節**不構成**「全機零殘留」的證明，其他來源各自保留追蹤狀態。

**未執行**：撤銷或建立任何憑證、變更 Git remote、hard delete、`git push`。

**比對方法**：於記憶體中以 `sha256sum` 計算，僅輸出不可逆 fingerprint 與比對結果，
未輸出完整 PAT、含 PAT 的 URL、原始行內容或任何可還原憑證的片段，未建立任何明碼暫存檔。

**判定（逐筆）**

| 命中 | 判定 | 依據 |
|---|---|---|
| 行 9 | `IDENTITY_UNCONFIRMED` | 無可比對之既有 fingerprint 或 token ID |
| 行 15 | `IDENTITY_UNCONFIRMED` | 同上（與行 9 為同一把） |

**證據限制（為什麼停在 UNCONFIRMED）**

1. **既有證據不含可比對識別資訊。** 第八節明載「未做比對…未進行 fingerprint 比對」；
   credential migration 段亦明載「不記帳號名稱、token id、scope 或到期日」。
   `Tru-Mi專區/token.txt` 已覆寫為 tombstone，其中不含 fingerprint、token ID 或撤銷時間
   （唯讀確認：明碼命中 0、識別關鍵字命中 0）。全庫除本標準檔外無其他保存 fingerprint 的檔案。
2. **GitHub 端查詢在本 runtime 不可行。** 容器無 `gh`、無任何已授權的唯讀憑證，
   依第三節與本次授權範圍不得建立憑證，故未進行、也不得推定。
3. **G1「舊 PAT 全部撤銷」是人工總括聲明，非逐把紀錄。** 無 token ID 可與本殘留對應。
4. 檔名日期（`20260905`）、mtime 與 incident 期間相近，**僅為線索**；
   依規定不得以前綴、檔名或建立時間相近推定為同一憑證。

**同期掃描結果（同一 fingerprint 是否另有散布）**

限 `*.bak*`／`*.old`／`config*`／`*.orig`（排除 `node_modules`）：
除本檔外，`.git/config`、`.git/gk/config`、`config.js`、
`index.html.bak_before_optimize_20260725`、`index.html.bak_before_theo` 命中數皆為 **0**。

**尚未涵蓋**：`.git` 以外的其他 history／log／逐字稿／不同前綴或已編碼形式，
以及本 runtime 無法讀取的 Windows 端位置。**不得**據本節宣稱「全機已無殘留」。

**本次未執行（未獲核准）**：刪除或修改備份檔、撤銷或建立任何憑證、
變更 Git remote、修改 producer／prompt／watcher／部署程式、`git push`。

