# ChannelDeco LINE 雲端打卡系統

這個專案包含：

- `line_attendance_system.html`：打卡系統前端頁面
- `app.js`：前端 API 串接
- `server.js`：Render 上運行的 Node/Express 後端
- `supabase/schema.sql`：Supabase 資料表與範例資料
- `render.yaml`：Render 部署設定

## 1. 建立 Supabase 資料庫

1. 到 Supabase 建立新專案。
2. 進入 SQL Editor。
3. 貼上 `supabase/schema.sql` 全部內容並執行。
4. 到 Project Settings > API 取得：
   - `SUPABASE_URL`
   - `service_role` key

後端使用 `service_role` 寫資料，請只放在 Render 環境變數，不要放到前端或公開頁面。

## 2. 本機測試

```bash
npm install
copy .env.example .env
npm run dev
```

開啟：

```text
http://localhost:3000
```

## 3. 放到 GitHub

```bash
git init
git add .
git commit -m "Add LINE attendance system"
git branch -M main
git remote add origin https://github.com/YOUR_ACCOUNT/YOUR_REPO.git
git push -u origin main
```

## 4. Render 部署

1. Render 建立 Web Service。
2. 連接 GitHub repository。
3. Build Command：`npm install`
4. Start Command：`npm start`
5. 加入環境變數：
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `LINE_CHANNEL_ACCESS_TOKEN`
   - `LINE_CHANNEL_SECRET`

部署完成後網站網址會像：

```text
https://channeldeco-line-attendance.onrender.com
```

## 5. LINE 官方帳號串接

在 LINE Developers 後台設定 Messaging API：

- Webhook URL：

```text
https://你的-render網址.onrender.com/line/webhook
```

- 啟用 Use webhook。
- 關閉或調整 Auto-reply，避免自動回覆蓋過 webhook 回覆。
- 將 Channel access token 與 Channel secret 填到 Render 環境變數。

目前 webhook 支援：

- `綁定 EMP-001`
- `上班打卡`
- `下班打卡`
- `外出`
- `返回`
- `外勤`

正式使用 GPS 打卡時，建議把 LINE Rich Menu 按鈕連到：

```text
https://你的-render網址.onrender.com/line_attendance_system.html
```

之後可再接 LIFF ID，讓 LINE 內建瀏覽器取得登入身分與 GPS。
