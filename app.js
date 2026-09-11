const api = {
  base: (window.CHANNELDECO_CONFIG?.apiBase || "").replace(/\/$/, ""),
  async get(path) {
    const response = await fetch(`${this.base}${path}`);
    if (!response.ok) throw new Error(await response.text());
    return response.json();
  },
  async send(path, method, body) {
    const response = await fetch(`${this.base}${path}`, {
      method,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body)
    });
    if (!response.ok) throw new Error(await response.text());
    return response.json();
  }
};

const state = {
  gps: { label: "台北總公司", distance: 82, ok: true },
  attendance: [],
  employees: [],
  gpsLocations: [],
  requests: [],
  punches: JSON.parse(localStorage.getItem("cd_local_punches") || "[]"),
  notices: [],
  metrics: { present: 42, late: 3, missing: 5, leave: 4, field: 7 },
  usingBackend: false
};

const sample = {
  attendance: [
    { employee_name: "王小美", department: "設計部", shift_name: "固定班", punch_type: "clock_in", punched_at: new Date().toISOString(), status: "normal", location_name: "台北總公司" },
    { employee_name: "林志豪", department: "工程部", shift_name: "外勤班", punch_type: "clock_in", punched_at: new Date().toISOString(), status: "late", location_name: "高雄工地" },
    { employee_name: "張雅婷", department: "業務部", shift_name: "外勤班", punch_type: "field_work", punched_at: new Date().toISOString(), status: "normal", location_name: "客戶 A" },
    { employee_name: "李冠廷", department: "行政部", shift_name: "固定班", punch_type: "-", punched_at: "", status: "missing_punch", location_name: "-" }
  ],
  employees: [
    { employee_no: "EMP-001", name: "王小美", department: "設計部", job_title: "設計師", email: "mei@channeldeco.com", line_user_id: "待綁定", status: "active" },
    { employee_no: "EMP-002", name: "林主管", department: "設計部", job_title: "主管", email: "manager@channeldeco.com", line_user_id: "待綁定", status: "active" },
    { employee_no: "EMP-003", name: "陳人資", department: "人資部", job_title: "HR", email: "hr@channeldeco.com", line_user_id: "待綁定", status: "active" }
  ],
  gpsLocations: [
    { name: "台北總公司", latitude: "25.033964", longitude: "121.564468", radius_meters: 100, is_active: true },
    { name: "高雄工地", latitude: "22.627278", longitude: "120.301435", radius_meters: 300, is_active: true },
    { name: "客戶 A", latitude: "25.047760", longitude: "121.517030", radius_meters: 500, is_active: true }
  ],
  notices: [
    { title: "上午 09:10 尚未打卡", body: "系統會自動提醒尚未完成上班打卡的人員。" },
    { title: "請假簽核上線", body: "員工可從 LINE Rich Menu 進入請假與補卡申請。" }
  ],
  requests: []
};

const titleMap = {
  dashboard: ["總覽儀表板", "即時掌握今日出勤、遲到、請假、外勤與未打卡狀態。"],
  line: ["LINE 打卡", "員工不用下載 App，從 LINE Rich Menu 進入即可完成打卡。"],
  leave: ["請假補卡", "員工可送出請假、補卡、加班申請，主管與 HR 線上簽核。"],
  approval: ["主管簽核", "主管可查看部門申請並核准或退回。"],
  hr: ["HR 後台", "管理員工、排班、報表與出缺勤資料。"],
  settings: ["系統設定", "設定 LINE、GPS、權限、安全與 API。"]
};

const punchMap = {
  "上班": "clock_in",
  "下班": "clock_out",
  "外出": "break_out",
  "返回": "break_in",
  "外勤": "field_work",
  "加班開始": "overtime_start",
  "加班結束": "overtime_end"
};

function $(selector) {
  return document.querySelector(selector);
}

function $all(selector) {
  return Array.from(document.querySelectorAll(selector));
}

function showToast(message) {
  const toast = $("#toast");
  toast.textContent = message;
  toast.classList.add("show");
  setTimeout(() => toast.classList.remove("show"), 3200);
}

function setView(view) {
  $all(".panel").forEach(panel => panel.classList.toggle("active", panel.id === view));
  $all(".nav button").forEach(btn => btn.classList.toggle("active", btn.dataset.view === view));
  $("#pageTitle").textContent = titleMap[view][0];
  $("#pageSub").textContent = titleMap[view][1];
}

function renderClock() {
  const now = new Date();
  $("#clockTime").textContent = now.toLocaleTimeString("zh-TW", { hour: "2-digit", minute: "2-digit" });
  $("#clockDate").textContent = now.toLocaleDateString("zh-TW");
}

function labelPunch(type) {
  return {
    clock_in: "上班",
    clock_out: "下班",
    break_out: "外出",
    break_in: "返回",
    field_work: "外勤",
    overtime_start: "加班開始",
    overtime_end: "加班結束"
  }[type] || type || "-";
}

function labelStatus(status) {
  return {
    normal: "正常",
    late: "遲到",
    early_leave: "早退",
    absent: "曠職",
    missing_punch: "未打卡",
    gps_abnormal: "GPS 異常",
    off_schedule: "未排班",
    holiday: "假日",
    needs_location: "需補定位",
    pending_manager: "待主管簽核",
    pending_hr: "待 HR 確認",
    approved: "核准",
    rejected: "退回",
    cancelled: "取消",
    active: "在職"
  }[status] || status || "-";
}

function statusClass(status) {
  if (["normal", "approved", "active"].includes(status)) return "ok";
  if (["late", "pending_manager", "pending_hr", "needs_location"].includes(status)) return "warn";
  if (["gps_abnormal", "missing_punch", "rejected", "absent"].includes(status)) return "bad";
  return "info";
}

function formatDateTime(value) {
  if (!value) return "-";
  return new Date(value).toLocaleString("zh-TW", { hour12: false });
}

function renderMetrics() {
  $("#metricPresent").textContent = state.metrics.present ?? 0;
  $("#metricLate").textContent = state.metrics.late ?? 0;
  $("#metricMissing").textContent = state.metrics.missing ?? 0;
  $("#metricLeave").textContent = state.metrics.leave ?? 0;
  $("#metricField").textContent = state.metrics.field ?? 0;
}

function renderAttendance() {
  $("#attendanceRows").innerHTML = state.attendance.map(row => `
    <tr>
      <td>${row.employee_name || "-"}</td>
      <td>${row.department || "-"}</td>
      <td>${row.shift_name || "-"}</td>
      <td>${row.punch_type === "clock_in" ? formatDateTime(row.punched_at) : "-"}</td>
      <td>${row.punch_type === "clock_out" ? formatDateTime(row.punched_at) : "-"}</td>
      <td><span class="status ${statusClass(row.status)}">${labelStatus(row.status)}</span></td>
      <td>${row.location_name || "-"}</td>
    </tr>
  `).join("");
}

function renderEmployees() {
  $("#employeeRows").innerHTML = state.employees.map(row => `
    <tr>
      <td>${row.employee_no}</td>
      <td>${row.name}</td>
      <td>${row.department}</td>
      <td>${row.job_title || "-"}</td>
      <td>${row.email || "-"}</td>
      <td>${row.line_user_id ? "已綁定" : "未綁定"}</td>
      <td><span class="status ${statusClass(row.status)}">${labelStatus(row.status)}</span></td>
    </tr>
  `).join("");
}

function renderSites() {
  $("#siteList").innerHTML = state.gpsLocations.map(site => `
    <div class="site">
      <div><b>${site.name}</b><span>經度 ${site.longitude || "-"}｜緯度 ${site.latitude || "-"}｜允許半徑 ${site.radius_meters || "-"}m</span></div>
      <span class="status ${site.is_active ? "ok" : "bad"}">${site.is_active ? "啟用" : "停用"}</span>
    </div>
  `).join("");
}

function renderNotices() {
  $("#noticeList").innerHTML = state.notices.map(item => `
    <div class="notice"><b>${item.title}</b><p>${item.body}</p></div>
  `).join("");
}

function renderPunches() {
  if (!state.punches.length) {
    $("#punchTimeline").innerHTML = `<div class="notice"><b>尚無今日打卡紀錄</b><p>點選手機畫面中的打卡按鈕即可新增紀錄。部署 Supabase 後會同步寫入資料庫。</p></div>`;
    return;
  }
  $("#punchTimeline").innerHTML = state.punches.map(row => `
    <div class="event">
      <time>${row.time}</time>
      <div><b>${labelPunch(row.type)}</b><span>${row.site}｜GPS ${row.distance}m｜${state.usingBackend ? "Supabase 已儲存" : "本機暫存"}</span></div>
      <span class="status ${row.ok ? "ok" : "bad"}">${row.ok ? "成功" : "異常"}</span>
    </div>
  `).join("");
}

function renderRequests() {
  const rows = state.requests.length ? state.requests : sample.requests;
  $("#requestRows").innerHTML = rows.map(row => `
    <tr>
      <td>${formatDateTime(row.time)}</td>
      <td>${row.type}</td>
      <td>${row.content}</td>
      <td>${row.step || "-"}</td>
      <td><span class="status ${statusClass(row.status)}">${labelStatus(row.status)}</span></td>
    </tr>
  `).join("");

  $("#approvalRows").innerHTML = rows.map(row => `
    <tr>
      <td>${row.employee || "王小美"}</td>
      <td>${row.dept || "設計部"}</td>
      <td>${row.type}</td>
      <td>${row.content}</td>
      <td>${formatDateTime(row.time)}</td>
      <td><span class="status ${statusClass(row.status)}">${labelStatus(row.status)}</span></td>
      <td>
        <button class="btn secondary" data-approve="${row.kind || ""}" data-id="${row.id || ""}">核准</button>
        <button class="btn danger" data-reject="${row.kind || ""}" data-id="${row.id || ""}">退回</button>
      </td>
    </tr>
  `).join("");
}

function renderAll() {
  renderMetrics();
  renderAttendance();
  renderEmployees();
  renderSites();
  renderNotices();
  renderPunches();
  renderRequests();
}

async function loadBootstrap() {
  try {
    const data = await api.get("/api/bootstrap");
    if (!data.configured) throw new Error("Supabase is not configured");
    state.usingBackend = true;
    state.metrics = data.metrics || state.metrics;
    state.attendance = data.attendance?.length ? data.attendance : sample.attendance;
    state.employees = data.employees?.length ? data.employees : sample.employees;
    state.gpsLocations = data.gpsLocations?.length ? data.gpsLocations : sample.gpsLocations;
    state.requests = data.requests || [];
    state.notices = data.notices?.length ? data.notices : sample.notices;
    renderAll();
    showToast("已連線後端 API，資料將儲存到 Supabase。");
  } catch (_error) {
    state.usingBackend = false;
    state.attendance = sample.attendance;
    state.employees = sample.employees;
    state.gpsLocations = sample.gpsLocations;
    state.notices = sample.notices;
    state.requests = [];
    renderAll();
    showToast("目前使用預覽資料。設定 Supabase 環境變數後會改寫資料庫。");
  }
}

function updateGps(useReal) {
  if (useReal && navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(() => {
      state.gps = { label: "台北總公司", distance: Math.floor(20 + Math.random() * 80), ok: true };
      $("#gpsBadge").textContent = `GPS：${state.gps.label} ${state.gps.distance}m 內`;
      showToast("已取得 GPS，目前在允許範圍內。");
    }, () => {
      state.gps = { label: "範圍外", distance: 680, ok: false };
      $("#gpsBadge").textContent = "GPS：範圍外 680m";
      showToast("無法取得精準位置，已標記為 GPS 異常。");
    });
    return;
  }
  state.gps = Math.random() > .25
    ? { label: "台北總公司", distance: Math.floor(30 + Math.random() * 85), ok: true }
    : { label: "範圍外", distance: Math.floor(520 + Math.random() * 500), ok: false };
  $("#gpsBadge").textContent = state.gps.ok ? `GPS：${state.gps.label} ${state.gps.distance}m 內` : `GPS：${state.gps.label} ${state.gps.distance}m`;
}

async function punch(label) {
  const type = punchMap[label] || label;
  const now = new Date();
  const localRow = {
    type,
    time: now.toLocaleTimeString("zh-TW", { hour: "2-digit", minute: "2-digit" }),
    site: state.gps.label,
    distance: state.gps.distance,
    ok: state.gps.ok
  };

  try {
    await api.send("/api/punches", "POST", {
      employeeNo: "EMP-001",
      type,
      latitude: null,
      longitude: null,
      locationName: state.gps.label,
      distanceMeters: state.gps.distance,
      note: "LIFF prototype punch"
    });
    state.usingBackend = true;
    state.punches.unshift(localRow);
    localStorage.setItem("cd_local_punches", JSON.stringify(state.punches));
    await loadBootstrap();
    showToast(`LINE 推播：${label}打卡成功，已寫入 Supabase。`);
  } catch (_error) {
    state.punches.unshift(localRow);
    localStorage.setItem("cd_local_punches", JSON.stringify(state.punches));
    renderPunches();
    showToast(`後端尚未連線，${label}打卡先暫存在本機。`);
  }
}

async function submitLeave(form) {
  const data = new FormData(form);
  try {
    await api.send("/api/leave-requests", "POST", {
      employeeNo: "EMP-001",
      leaveType: data.get("type"),
      startDate: data.get("start"),
      endDate: data.get("end"),
      reason: data.get("reason"),
      approvalLevel: data.get("levels") === "主管" ? 1 : data.get("levels") === "主管 + HR" ? 2 : 3
    });
    form.reset();
    await loadBootstrap();
    showToast("請假申請已寫入 Supabase，並可推播 LINE 通知。");
  } catch (_error) {
    showToast("請假送出失敗，請確認 Render 與 Supabase 環境變數。");
  }
}

async function submitCorrection(form) {
  const data = new FormData(form);
  try {
    await api.send("/api/correction-requests", "POST", {
      employeeNo: "EMP-001",
      punchType: punchMap[data.get("type")] || data.get("type"),
      requestedDate: data.get("date"),
      requestedTime: data.get("time"),
      locationName: data.get("site"),
      reason: data.get("reason")
    });
    form.reset();
    await loadBootstrap();
    showToast("補卡申請已寫入 Supabase，等待主管簽核。");
  } catch (_error) {
    showToast("補卡送出失敗，請確認 Render 與 Supabase 環境變數。");
  }
}

async function updateRequestStatus(kind, id, status) {
  if (!kind || !id) {
    showToast("這是範例資料。請先建立真實申請後再簽核。");
    return;
  }
  try {
    await api.send(`/api/requests/${kind}/${id}/status`, "PATCH", { status });
    await loadBootstrap();
    showToast(status === "approved" ? "申請已核准，LINE 通知已送出。" : "申請已退回，LINE 通知已送出。");
  } catch (_error) {
    showToast("簽核失敗，請確認後端服務狀態。");
  }
}

function exportCsv(filename, rows) {
  const csv = rows.map(row => row.map(cell => `"${String(cell ?? "").replaceAll('"', '""')}"`).join(",")).join("\n");
  const blob = new Blob(["\uFEFF" + csv], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

function bindEvents() {
  $all(".nav button").forEach(btn => btn.addEventListener("click", () => setView(btn.dataset.view)));
  $all("[data-nav]").forEach(btn => btn.addEventListener("click", () => setView(btn.dataset.nav)));
  $all("[data-punch]").forEach(btn => btn.addEventListener("click", () => punch(btn.dataset.punch)));
  $all("[data-hr-tab]").forEach(btn => btn.addEventListener("click", () => {
    $all("[data-hr-tab]").forEach(tab => tab.classList.toggle("active", tab === btn));
    $all(".hr-panel").forEach(panel => panel.classList.toggle("active", panel.id === btn.dataset.hrTab));
  }));

  $("#useGpsBtn").addEventListener("click", () => updateGps(true));
  $("#clearPunchBtn").addEventListener("click", () => {
    state.punches = [];
    localStorage.removeItem("cd_local_punches");
    renderPunches();
    showToast("已清除本機測試打卡紀錄。");
  });
  $("#sendReminderBtn").addEventListener("click", () => showToast("LINE 推播：上午 09:10 尚未打卡，請開啟 Rich Menu 完成上班打卡。"));
  $("#exportTodayBtn").addEventListener("click", () => {
    if (state.usingBackend) {
      window.location.href = `${api.base}/api/attendance.csv`;
      return;
    }
    exportCsv("channeldeco_today_attendance.csv", [["員工", "部門", "班別", "打卡時間", "類型", "狀態", "地點"], ...state.attendance.map(row => [row.employee_name, row.department, row.shift_name, formatDateTime(row.punched_at), labelPunch(row.punch_type), labelStatus(row.status), row.location_name])]);
  });
  $("#exportMonthBtn").addEventListener("click", () => exportCsv("channeldeco_monthly_report.csv", [["項目", "數值"], ["出勤率", "94%"], ["遲到率", "6%"], ["加班工時", "128h"], ["請假時數", "32h"], ["GPS 異常", "11"]]));
  $("#printReportBtn").addEventListener("click", () => window.print());

  $("#leaveForm").addEventListener("submit", event => {
    event.preventDefault();
    submitLeave(event.target);
  });
  $("#correctionForm").addEventListener("submit", event => {
    event.preventDefault();
    submitCorrection(event.target);
  });

  document.body.addEventListener("click", event => {
    const approve = event.target.closest("[data-approve]");
    const reject = event.target.closest("[data-reject]");
    if (approve) updateRequestStatus(approve.dataset.approve, approve.dataset.id, "approved");
    if (reject) updateRequestStatus(reject.dataset.reject, reject.dataset.id, "rejected");
  });
}

function init() {
  renderClock();
  setInterval(renderClock, 1000);
  updateGps(false);
  bindEvents();
  loadBootstrap();
}

init();
