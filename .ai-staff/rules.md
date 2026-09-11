# ChannelDeco 做事規則庫

> 由 session-miner 累積。每條規則都來自一次實際踩到的坑，寫下來是為了不再犯第二次。
> 只放「做事的規則」；品牌事實、專案狀態請放 memory 檔。
> 固定結構的保留規範另見 `_routine_persist_rules.md`，兩份互補、不重複。

---

## 一、GitHub 推送

### R-001｜GitHub 認證一律走 gh CLI，禁止明碼 token（2026-09-05 改寫）
- **日期**：2026-08-19 立規／2026-09-05 全面改寫
- **舊規則（已作廢）**：原本寫「token 過期時請使用者自行更新 `.git/config`」，前提是憑證放在 remote URL 裡。
- **作廢原因**：2026-09-05 發現 `chanel deco` 的 remote URL 內含明碼 PAT，且知識庫另有 4 個明碼 token 檔。憑證已全面遷移到 `gh auth login` + credential helper（Windows keyring）。
- **現行規則**：
  - Git remote **必須維持無憑證形式** `https://github.com/OWNER/REPO.git`。
  - 憑證只放 Windows 主機的 `gh auth login` keyring；**不要**索取 token 字串、**不要**建立 `.github_token`／`token.txt`、**不要**把 token 拼回 remote URL 或 `.git/config`。
  - 推送成功時不要在報告裡提認證，那是雜訊。
- **2026-09-06 追加**：`gh auth status` 這一步**只在 Windows 端有意義**。排程容器裡沒有 gh（見 R-004），容器端不 push 也不查認證。
- **完整標準**：見 [`GITHUB-AUTH-STANDARD.md`](../GITHUB-AUTH-STANDARD.md)。

### R-002｜雲端掛載資料夾一律用 plumbing 指令，warning 可忽略
- **日期**：2026-08-19
- **實況**：`git hash-object -w` / `git mktree` / `git commit-tree` 過程會噴 `warning: unable to unlink '.git/objects/../tmp_obj_XXXX': Operation not permitted`。
- **規則**：這是雲端同步資料夾的檔案鎖造成的，**物件其實已寫入成功**，不要因此重試或改用一般 `git add/commit`。看 hash 有正常回傳就繼續下一步。

### R-003｜`git ls-tree` 必須用 FETCH_HEAD
- **規則**：這個 remote 沒設定 fetch refspec，`channeldeco/main` 不存在。一律 `git fetch channeldeco main` 之後用 `FETCH_HEAD`，`-p` 的 parent 也用 `git rev-parse FETCH_HEAD` 的值。
- **驗收**：push 完再 `git fetch channeldeco main`，`git diff FETCH_HEAD -- index.html | wc -l` 要等於 0 才算成功。

---

### R-004｜容器不 push：執行與發布是兩個 execution boundary（2026-09-06）
- **日期**：2026-09-06
- **實況**：排程在容器內跑完 plumbing、算出 commit `ecf26850`，`git push` 回 `could not read Username for 'https://github.com'`。remote URL 是無憑證形式（正確），容器內沒有 `gh`、沒有 credential helper。
- **誤判警告**：這**不是** PATH 沒傳、**不是** token 過期、**不是**環境壞了。排程容器（Ubuntu）與 Windows 主機是**不同的安全邊界**，Windows keyring 不可能被容器繼承。
- **規則**：
  - 容器端做到 `git commit-tree` 算出 commit SHA 為止，**不執行 `git push`**，也不跑 `gh auth status`。
  - 報告最後附上可直接貼的 `git push channeldeco <sha>:refs/heads/main`，由使用者在 Windows PowerShell 執行。
  - ⛔ **禁止**為了讓容器能推而硬編 `gh` 路徑、做 PATH fallback、或建 token 檔——**後者正是 2026-09-05 明碼 PAT 外洩的成因**。
  - 完成語意拆四段：`CONTENT_COMPLETE → DEPLOY_WAITING → DEPLOY_PUSHED → DEPLOY_VERIFIED`。容器端最多只能宣告 `CONTENT_COMPLETE`，**未經遠端驗證不得說「發布完成」**。
  - 架構上推不動記 `DEPLOY_BLOCKED`，**不是 `PENDING`**——後者的語意是「等一下可能自己好」，會讓下一輪 Agent 一直重試一件不可能成功的事。
- **完整標準**：`000_Agent/knowledge/EXECUTION-BOUNDARY-STANDARD.md`

### R-005｜匿名讀得到 ≠ 推得動（2026-09-06）
- **規則**：`git ls-remote` 只驗 **read reachability**；這個 repo 是公開的，無憑證也會 exit 0，**不得**拿它當「有推送權限」的證據。要驗當前 runtime 的推送能力用 `git push --dry-run`。
- **延伸**：`git push` 的 exit code 也只代表「推送這個動作的結果」，不代表遠端內容等於本機內容。後者要跑 `bash tools/deploy_verify.sh`（退出碼 0=DEPLOY_VERIFIED／1=遠端落後／2=UNKNOWN）。
- **UNKNOWN 不是 0**：讀不到遠端時記 `UNKNOWN`，不得宣稱已發布，也不得記成「無變更」。

### R-006｜資料源掛掉：3-surface cutoff，不要用擴大關鍵字硬撐（2026-09-06）
- **實況**：2026-09-05 Threads 搜尋結果頁全站異常，前一輪排程輪完關鍵字花掉大量時間才判定失敗。
- **規則**：節流（回傳量變少）→ 拉長間隔、換 tab、scroll；**endpoint 掛掉**（連續錯誤頁／空頁）→ 停止擴大關鍵字。同一輪中 3 個**相互獨立**的 surface 均持續失敗（A `/search?q=…`、B `/tag/軟裝設計`、C `/@channel.deco/replies`）即進 DEGRADED。
- **重試上限**：`A fail → wait 20-30s → B fail → wait 20-30s → C fail → DEGRADED`。先看首頁 `https://www.threads.com/` 正不正常，用來區分平台端異常與登入失效。
- **記法**：`Discovery = DEGRADED`／`Intent analysis = SKIP — insufficient reliable input`／`Comment audit = UNKNOWN`。⛔ **不得記成「0 則新貼文」**——那會讓「量到 0」和「量不到」在歷史紀錄裡長得一樣。

### R-007｜稽核輸出本身也是秘密（2026-09-06）
- **實況**：為了查 09-05 事件的第 4 把 token，`Select-String 'github_pat_'` 的輸出被原樣貼進 AI 對話——**用來找秘密的指令，其輸出反而新增了一個 exposure surface**。
- **規則**：憑證稽核只回報 ①命中筆數 ②來源類型 ③行號位置 ④憑證類型 ⑤已撤銷／待處理。不得輸出、複製、回傳任何疑似 token／PAT／API key／password 的完整內容。
- **驗證清乾淨的正確寫法**：回報 `pattern count = 0`，不是把命中行列出來。
- **讀取 ≠ 輸出**：在受控環境讀取秘密以完成判定是允許的；把原值送到終端、log、AI 對話、報告才是違規。要比對兩個來源是不是同一把，用本機 `sha256sum` 只回報「相同／不同」。⛔ 不要寫成「比對需要讀取原值所以不能做」——那是把讀取誤當成輸出。
- **Exposure surface 清單**：shell history、終端輸出、AI 對話逐字稿、CI/CD log、debug log、錯誤訊息、螢幕截圖、issue／PR 內容。
- **失效 ≠ 不存在**：逐字稿裡的 token 撤銷後標 `REVOKED / RESIDUAL RETENTION`，不要標「已關閉」——撤銷是 containment，字串仍在留存面。
- **完整標準**：[`../GITHUB-AUTH-STANDARD.md`](../GITHUB-AUTH-STANDARD.md) 第五節

### R-008｜incident 與部署是兩條獨立狀態線（2026-09-06）
- **規則**：credential incident 開啟**不會**讓已驗證的部署回退。2026-09-06 `DEPLOY_VERIFIED`（`ecf2685`）維持結案，同時 `CREDENTIAL INCIDENT — OPEN` 各自追蹤。
- **反向也成立**：部署成功不代表 incident 可以關閉。incident 關閉條件是四項全部成立——舊 PAT 已撤銷、明碼檔無 credential、history pattern count=0、`gh auth status` 與 Git 操作仍正常。
- **2026-09-07 擴充：阻擋範圍只涵蓋自己那條狀態線。** 一個 incident 或 verification request 未關閉，**只阻擋它自己的 closure 判定**，不凍結整個專案——內容生產、Skill 安裝、文件工作、其他 request 都照常進行，已驗證的部署狀態也不回退。寫回報時要明講阻擋對象，避免下一個 Agent 把「尚未 CLOSED」讀成全案 freeze。
- **狀態鏈不得跳格**：`AUTHORIZED → DISPATCHED → EXECUTED → VERIFIED → CLOSED`。「已派送」只代表工作被核准並登錄，**不代表檔案已變更**；未經 execution evidence（before/after hash）與內容層驗證，不得宣告 CLOSED。*依據*：2026-09-07 `dispatch.py verify` 用 dispatch evidence 的 SUCCESS 直接判 `INCIDENT_CLOSED`，把 DISPATCHED 當成 EXECUTED——negative control 擋得住越權，卻沒測到成功路徑少一層 gate。

## 二、Threads 掃描

### R-101｜搜尋一定要加 `&filter=recent`，否則只拿得到 1～2 則舊貼文 ★最重要
- **日期**：2026-08-19
- **背景**：用排程指定的 `https://www.threads.com/search?q=關鍵字&serp_type=default` 掃「軟裝設計」，等 4 秒後 `get_page_text` **只回傳 1 則 2025 年 9 月的貼文**，再怎麼捲動、再等 5 秒都一樣。差點誤判成「今日無新 A 級」。
- **原因**：預設是「最相關」排序，會回傳極少量的高權重舊文。
- **規則**：**所有關鍵字搜尋網址一律接 `&filter=recent`**（等同點頁面上的「最近」）。切過去之後同一組關鍵字可以拿到 10～20 則當日貼文。
  - 正確：`https://www.threads.com/search?q=%E8%BB%9F%E8%A3%9D%E8%A8%AD%E8%A8%88&serp_type=default&filter=recent`
  - 若不確定，也可先 `find` 出「最近」連結再點一次，網址會自己補上 `filter=recent`。

### R-102｜取單篇連結：點貼文文字區沒有用，要抓時間戳 permalink
- **日期**：2026-08-19
- **背景**：`find` 到貼文內文元素後 `left_click`，網址完全沒變，仍停在個人頁。
- **規則**：改用 `find` 找「時間戳連結」（例：查詢 `timestamp permalink link "1小時"`），回傳結果會直接帶出 `href="/@user/post/POSTID"`，**直接 navigate 到那個完整網址**即可，不用真的點。
- **附帶好處**：進到單篇頁後 `get_page_text` 會一併吐出瀏覽次數與完整留言串，一次拿齊。

### R-103｜同一 tab 反覆 timeout 就換新 tab
- **實況**：連續掃到第 7 個關鍵字時，`get_page_text` 連兩次回 `Page still loading (waited 45000ms)`。
- **規則**：不要在同一個 tab 硬等第三次。`tabs_create_mcp` 開新 tab、重新 navigate，通常一次就過。舊 tab 收尾時記得關掉。

### R-104｜A 級門檻要嚴守，寧缺勿濫
- **日期**：2026-08-19
- **實況**：7 個關鍵字掃下來，八成以上是房仲物件文、設計公司罐頭自薦、代繪接案廣告。真正符合的只有 2 則。
- **規則**：A ＝**同時**有「地區」＋（預算／時程／明確求設計師統包推薦）任一。缺地區就不是 A，**即使互動數很高也不收**。
  - 實例：`@three.small.la` 預算 200 萬、2 年後交屋、18 坪、197 讚 102 留言 —— 因為**通篇沒有地區**，判定不收。
  - 實例：`@s.hsuan___` 開店裝潢求設計師、40 讚 —— 無地區，不收。
- **非服務區怎麼辦**：地區在高雄／屏東／台南／桃園／新北／台北之外（例：嘉義、彰化、台中）**仍可收為 A**，但「ChannelDeco 商機」欄要誠實寫明不在核心服務區，並改寫成「內容素材價值」角度（這類通用提問服務區內的受眾一樣會有共鳴）。
- **不收的例外**：同業找工班／找合作夥伴的 B2B 貼文（例：`@xinone777` 彰化找工班、`@house.renovation.taiwan` 徵設計師夥伴）不是客戶，跳過。

### R-105｜留言區的「反差」就是切入點，值得標 ⚡
- **觀察**：高意圖貼文的留言區幾乎都是「來找我吧」「歡迎討論」這類罐頭自薦，**極少有人真正回答提問本身**。
- **規則**：發現這種反差就在透視分析標 ⚡，並讓 `data-draft` 直接回答對方的問題（先解題、給具體方向），這是最低成本的差異化。草稿仍嚴守：不放連結、不自薦、不批評同業。

---

## 三、index.html 維護

### R-201｜數字一律用 grep／python 實算，絕不沿用舊值往上加
- **日期**：2026-08-19
- **實況**：header 標「共 206 則」、A 級 KPI 標 80、`.cs` 全部標 202、室內設計標 56 —— **四個數字彼此不一致，且都跟實際不符**（實際 A 級是 86）。若照「舊值 +N」的做法，錯誤會一路累積下去。
- **規則**：每次更新都用下列腳本重算全部數字，然後**覆蓋**而非累加：

```bash
python3 -c "
import re
from collections import Counter
h=open('index.html',encoding='utf-8').read()
cards=re.findall(r'<div class=\"post-card\"[^>]*>',h)
print('cards',len(cards))
lv=Counter(); kw=Counter()
for c in cards:
    m=re.search(r'data-level=\"([^\"]*)\"',c); lv[m.group(1) if m else 'NONE']+=1
    m=re.search(r'data-kw=\"([^\"]*)\"',c);    kw[m.group(1) if m else 'NONE']+=1
print(dict(lv)); print(dict(kw))
"
```

- **要同步的四處**：① header `<strong>YYYY年M月D日</strong>` 與「共 N 則貼文」 ② `.cs[data-kw="all"]` 的 `.num` ③ 各 `.cs` 類別 `.num` ④ 五個 `.kpi-box` 的 `.kn`（A/B/C/D/風險）。
- **注意**：直接 `grep -c 'data-kw='` 會**多算**，因為 `.cs` 篩選鈕與 CSS 選擇器也帶這些屬性；一定要限定在 `class="post-card"` 的 div 上。

### R-202｜div 平衡檢查的正確做法（避免 off-by-one 誤判）
- **實況**：從 `id="postsGrid"` 這個字串位置起算深度，會漏掉外層 grid 的開頭 div，導致**所有**卡片都報 depth 0、最終 depth -1，看起來像全部出錯。
- **規則**：兩個檢查分開看，才不會被假警報誤導：
  1. **全檔平衡**：`grep -o '<div' | wc -l` 要等於 `grep -o '</div>' | wc -l`。
  2. **有無巢狀**：只要**所有** `.post-card` 回報的深度數值**彼此一致**就代表沒有巢狀，絕對值是幾不重要。有一張跟其他不同才是真的出事。
- **插卡收尾**：每張卡務必 3 個 `</div>`（analysis 區、comments-section、post-card 各一）。

### R-203｜data-draft 屬性的禁用字元
- 不可有半形雙引號 `"`（會截斷屬性）→ 用『』「」或全形。
- 不可有 `<` `>`。
- 寫完用這行驗：`[d for d in re.findall(r'data-draft="([^"]*)"',h) if '<' in d or '>' in d]` 應為空。

### R-204｜卡片插在 posts-grid 最前面，並留日期註解
- 整份只有一個 `<div class="posts-grid" id="postsGrid">`，分類是靠 JS 依 `data-kw` 篩選，**不是**每類一個面板。新卡一律插在 grid 最前面（排序註解之後）。
- 每批新增前加一行註解方便日後回溯：
  `<!-- 以下 N 則為 threads-home-deco-daily-a-sweep 每日輕量掃描新增（YYYY-M-D） -->`
- 這樣週一的完整版排程與每日 A 掃各自成塊，不會互相覆蓋。

### R-205｜留言拿不到讚數就不要編
- **實況**：單篇頁的留言在 `get_page_text` 裡**沒有讚數**（只有帳號、時間、內容）。
- **規則**：拿不到就**整個省略** `<span class="likes">`，不要填 0 也不要臆測數字。同理，取不到留言時才填「🔄 留言將於下次更新補充」。
- 貼文層級的 `📤 分享數`若抓不到，改用 `👁 瀏覽次數`（單篇頁上方會顯示「N次瀏覽」），比硬湊誠實。

---

## 四、報告口徑

### R-301｜無新 A 級就不重建、不推送
- 當天沒有符合門檻的貼文，只回報「今日無新 A 級貼文」，**不要**為了有產出而放寬標準或動 index.html。

### R-302｜報告只講結果，不複述步驟
- 使用者是一路看著跑完的，不需要逐步回顧。報告固定四塊：新增幾則（帳號＋地區＋需求＋熱度）、最有價值的那則為什麼、儀表板數字變動、commit SHA 與 repo 連結。
