import "dotenv/config";
import express from "express";
import cors from "cors";
import helmet from "helmet";
import * as line from "@line/bot-sdk";
import { createClient } from "@supabase/supabase-js";

const app = express();
const port = process.env.PORT || 3000;

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const lineChannelAccessToken = process.env.LINE_CHANNEL_ACCESS_TOKEN;
const lineChannelSecret = process.env.LINE_CHANNEL_SECRET;

if (!supabaseUrl || !supabaseServiceRoleKey) {
  console.warn("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY. API routes will fail until env vars are set.");
}

const supabase = supabaseUrl && supabaseServiceRoleKey
  ? createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false }
    })
  : null;

const lineClient = lineChannelAccessToken
  ? new line.messagingApi.MessagingApiClient({ channelAccessToken: lineChannelAccessToken })
  : null;

app.use(helmet({
  contentSecurityPolicy: false
}));
app.use(cors());

app.post(
  "/line/webhook",
  lineChannelSecret
    ? line.middleware({ channelSecret: lineChannelSecret })
    : express.json(),
  async (req, res) => {
    try {
      const events = req.body.events || [];
      await Promise.all(events.map(handleLineEvent));
      res.status(200).json({ ok: true });
    } catch (error) {
      console.error("LINE webhook error", error);
      res.status(500).json({ error: "LINE webhook failed" });
    }
  }
);

app.use(express.json({ limit: "1mb" }));
app.use(express.static(".", {
  extensions: ["html"],
  index: "line_attendance_system.html"
}));

app.get("/healthz", (_req, res) => {
  res.json({ ok: true, service: "channeldeco-line-attendance" });
});

app.get("/api/bootstrap", async (_req, res) => {
  try {
    const [attendance, employees, gpsLocations, requests, notices] = await Promise.all([
      listAttendance(),
      selectRows("employees", "employee_no,name,department,job_title,email,line_user_id,status", "employee_no"),
      selectRows("gps_locations", "name,latitude,longitude,radius_meters,is_active", "name"),
      listRequests(),
      selectRows("announcements", "title,body,created_at", "created_at", false)
    ]);

    res.json({
      configured: Boolean(supabase),
      metrics: buildMetrics(attendance, requests),
      attendance,
      employees,
      gpsLocations,
      requests,
      notices
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Failed to load bootstrap data" });
  }
});

app.post("/api/punches", async (req, res) => {
  try {
    const { employeeNo = "EMP-001", type, latitude, longitude, locationName, distanceMeters, note } = req.body;
    if (!type) return res.status(400).json({ error: "type is required" });

    const employee = await findEmployee(employeeNo);
    if (!employee) return res.status(404).json({ error: "employee not found" });

    const status = Number(distanceMeters) > 100 ? "gps_abnormal" : "normal";
    const { data, error } = await supabase
      .from("attendance_records")
      .insert({
        employee_id: employee.id,
        punch_type: type,
        latitude,
        longitude,
        location_name: locationName || "台北總公司",
        distance_meters: distanceMeters ?? null,
        source: "web_liff",
        status,
        note
      })
      .select("id,punch_type,punched_at,status,location_name,distance_meters")
      .single();

    if (error) throw error;
    await pushLine(employee.line_user_id, `打卡成功：${labelPunchType(type)} ${formatDateTime(data.punched_at)}。`);
    res.status(201).json({ record: data });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Failed to create punch" });
  }
});

app.post("/api/leave-requests", async (req, res) => {
  try {
    const { employeeNo = "EMP-001", leaveType, startDate, endDate, reason, approvalLevel = 1 } = req.body;
    if (!leaveType || !startDate || !endDate) {
      return res.status(400).json({ error: "leaveType, startDate and endDate are required" });
    }

    const employee = await findEmployee(employeeNo);
    if (!employee) return res.status(404).json({ error: "employee not found" });

    const { data, error } = await supabase
      .from("leave_requests")
      .insert({
        employee_id: employee.id,
        leave_type: leaveType,
        start_date: startDate,
        end_date: endDate,
        reason,
        approval_level: approvalLevel,
        status: "pending_manager"
      })
      .select("id,created_at,leave_type,start_date,end_date,status")
      .single();

    if (error) throw error;
    await pushLine(employee.line_user_id, `請假申請已送出：${leaveType} ${startDate} 至 ${endDate}。`);
    res.status(201).json({ request: data });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Failed to create leave request" });
  }
});

app.post("/api/correction-requests", async (req, res) => {
  try {
    const { employeeNo = "EMP-001", punchType, requestedDate, requestedTime, locationName, reason } = req.body;
    if (!punchType || !requestedDate || !requestedTime) {
      return res.status(400).json({ error: "punchType, requestedDate and requestedTime are required" });
    }

    const employee = await findEmployee(employeeNo);
    if (!employee) return res.status(404).json({ error: "employee not found" });

    const { data, error } = await supabase
      .from("correction_requests")
      .insert({
        employee_id: employee.id,
        punch_type: punchType,
        requested_at: `${requestedDate}T${requestedTime}:00+08:00`,
        location_name: locationName,
        reason,
        status: "pending_manager"
      })
      .select("id,created_at,punch_type,requested_at,location_name,status")
      .single();

    if (error) throw error;
    await pushLine(employee.line_user_id, `補卡申請已送出：${labelPunchType(punchType)} ${requestedDate} ${requestedTime}。`);
    res.status(201).json({ request: data });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Failed to create correction request" });
  }
});

app.patch("/api/requests/:kind/:id/status", async (req, res) => {
  try {
    const { kind, id } = req.params;
    const { status, approverEmployeeNo = "EMP-002", comment } = req.body;
    const table = kind === "leave" ? "leave_requests" : kind === "correction" ? "correction_requests" : null;
    if (!table) return res.status(400).json({ error: "kind must be leave or correction" });
    if (!["approved", "rejected", "pending_hr"].includes(status)) {
      return res.status(400).json({ error: "invalid status" });
    }

    const approver = await findEmployee(approverEmployeeNo);
    const { data, error } = await supabase
      .from(table)
      .update({ status, updated_at: new Date().toISOString() })
      .eq("id", id)
      .select("id,employee_id,status")
      .single();

    if (error) throw error;
    await supabase.from("approval_logs").insert({
      request_table: table,
      request_id: id,
      approver_employee_id: approver?.id,
      action: status,
      comment
    });

    const { data: employee } = await supabase
      .from("employees")
      .select("line_user_id")
      .eq("id", data.employee_id)
      .single();
    await pushLine(employee?.line_user_id, `簽核通知：您的申請已${status === "approved" ? "核准" : status === "rejected" ? "退回" : "送 HR 確認"}。`);
    res.json({ request: data });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Failed to update request" });
  }
});

app.get("/api/attendance.csv", async (_req, res) => {
  try {
    const attendance = await listAttendance();
    const rows = [
      ["員工", "部門", "班別", "打卡時間", "類型", "狀態", "地點"],
      ...attendance.map(row => [row.employee_name, row.department, row.shift_name, row.punched_at, row.punch_type, row.status, row.location_name])
    ];
    res.setHeader("Content-Type", "text/csv; charset=utf-8");
    res.setHeader("Content-Disposition", "attachment; filename=attendance.csv");
    res.send("\uFEFF" + toCsv(rows));
  } catch (error) {
    console.error(error);
    res.status(500).send("export failed");
  }
});

async function handleLineEvent(event) {
  if (!supabase) return;
  await supabase.from("line_events").insert({
    event_type: event.type,
    line_user_id: event.source?.userId,
    payload: event
  });

  if (event.type === "follow") {
    await replyLine(event.replyToken, "歡迎加入 ChannelDeco 打卡系統。請輸入「綁定 EMP-001」完成員工帳號綁定。");
    return;
  }

  if (event.type !== "message" || event.message?.type !== "text") return;
  const text = event.message.text.trim();
  const userId = event.source?.userId;

  if (/^綁定\s+/i.test(text)) {
    const employeeNo = text.replace(/^綁定\s+/i, "").trim().toUpperCase();
    const { data, error } = await supabase
      .from("employees")
      .update({ line_user_id: userId })
      .eq("employee_no", employeeNo)
      .select("name")
      .single();
    await replyLine(event.replyToken, error ? "綁定失敗，請確認員工編號。" : `綁定成功，${data.name} 可以開始使用 LINE 打卡。`);
    return;
  }

  const punchMap = {
    "上班打卡": "clock_in",
    "下班打卡": "clock_out",
    "外出": "break_out",
    "返回": "break_in",
    "外勤": "field_work"
  };

  if (punchMap[text]) {
    const employee = await findEmployeeByLineUserId(userId);
    if (!employee) {
      await replyLine(event.replyToken, "尚未綁定員工帳號，請輸入「綁定 EMP-001」。");
      return;
    }

    await supabase.from("attendance_records").insert({
      employee_id: employee.id,
      punch_type: punchMap[text],
      location_name: "LINE 文字打卡",
      source: "line_chat",
      status: "needs_location",
      note: "文字打卡未附 GPS，建議使用 LIFF 按鈕取得定位。"
    });
    await replyLine(event.replyToken, `${text}已收到。提醒：正式打卡建議從 Rich Menu 開啟 LIFF 取得 GPS。`);
    return;
  }

  await replyLine(event.replyToken, "可輸入：綁定 EMP-001、上班打卡、下班打卡、外出、返回、外勤。");
}

async function selectRows(table, columns, order, ascending = true) {
  if (!supabase) return [];
  const { data, error } = await supabase.from(table).select(columns).order(order, { ascending });
  if (error) throw error;
  return data || [];
}

async function listAttendance() {
  if (!supabase) return [];
  const { data, error } = await supabase
    .from("attendance_records")
    .select("id,punch_type,punched_at,status,location_name,distance_meters,employees(name,department,employee_no,shift_name)")
    .order("punched_at", { ascending: false })
    .limit(80);
  if (error) throw error;
  return (data || []).map(row => ({
    id: row.id,
    employee_name: row.employees?.name || "-",
    employee_no: row.employees?.employee_no || "-",
    department: row.employees?.department || "-",
    shift_name: row.employees?.shift_name || "-",
    punch_type: row.punch_type,
    punched_at: row.punched_at,
    status: row.status,
    location_name: row.location_name,
    distance_meters: row.distance_meters
  }));
}

async function listRequests() {
  if (!supabase) return [];
  const [leave, correction] = await Promise.all([
    supabase.from("leave_requests").select("id,created_at,leave_type,start_date,end_date,status,employees(name,department)").order("created_at", { ascending: false }),
    supabase.from("correction_requests").select("id,created_at,punch_type,requested_at,location_name,status,employees(name,department)").order("created_at", { ascending: false })
  ]);
  if (leave.error) throw leave.error;
  if (correction.error) throw correction.error;
  return [
    ...(leave.data || []).map(row => ({
      id: row.id,
      kind: "leave",
      employee: row.employees?.name,
      dept: row.employees?.department,
      time: row.created_at,
      type: "請假",
      content: `${row.leave_type} ${row.start_date} 至 ${row.end_date}`,
      step: statusStep(row.status),
      status: row.status
    })),
    ...(correction.data || []).map(row => ({
      id: row.id,
      kind: "correction",
      employee: row.employees?.name,
      dept: row.employees?.department,
      time: row.created_at,
      type: "補卡",
      content: `${labelPunchType(row.punch_type)} ${formatDateTime(row.requested_at)} ${row.location_name || ""}`,
      step: statusStep(row.status),
      status: row.status
    }))
  ].sort((a, b) => new Date(b.time) - new Date(a.time));
}

async function findEmployee(employeeNo) {
  if (!supabase) return null;
  const { data, error } = await supabase.from("employees").select("*").eq("employee_no", employeeNo).single();
  if (error) return null;
  return data;
}

async function findEmployeeByLineUserId(lineUserId) {
  if (!supabase || !lineUserId) return null;
  const { data, error } = await supabase.from("employees").select("*").eq("line_user_id", lineUserId).single();
  if (error) return null;
  return data;
}

function buildMetrics(attendance, requests) {
  return {
    present: new Set(attendance.filter(row => row.punched_at?.slice(0, 10) === new Date().toISOString().slice(0, 10)).map(row => row.employee_no)).size,
    late: attendance.filter(row => row.status === "late").length,
    missing: 0,
    leave: requests.filter(row => row.type === "請假" && ["approved", "pending_manager", "pending_hr"].includes(row.status)).length,
    field: attendance.filter(row => row.punch_type === "field_work").length
  };
}

function statusStep(status) {
  return {
    pending_manager: "主管",
    pending_hr: "HR",
    approved: "完成",
    rejected: "員工修正"
  }[status] || "主管";
}

function labelPunchType(type) {
  return {
    clock_in: "上班",
    clock_out: "下班",
    break_out: "外出",
    break_in: "返回",
    field_work: "外勤",
    overtime_start: "加班開始",
    overtime_end: "加班結束",
    "上班": "上班",
    "下班": "下班",
    "外出": "外出",
    "返回": "返回",
    "外勤": "外勤"
  }[type] || type;
}

function formatDateTime(value) {
  return new Date(value).toLocaleString("zh-TW", { hour12: false, timeZone: "Asia/Taipei" });
}

function toCsv(rows) {
  return rows.map(row => row.map(cell => `"${String(cell ?? "").replaceAll('"', '""')}"`).join(",")).join("\n");
}

async function replyLine(replyToken, text) {
  if (!lineClient || !replyToken) return;
  await lineClient.replyMessage({
    replyToken,
    messages: [{ type: "text", text }]
  });
}

async function pushLine(lineUserId, text) {
  if (!lineClient || !lineUserId) return;
  await lineClient.pushMessage({
    to: lineUserId,
    messages: [{ type: "text", text }]
  });
}

app.listen(port, () => {
  console.log(`ChannelDeco attendance app running on port ${port}`);
});
