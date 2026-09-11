create extension if not exists pgcrypto;

create table if not exists public.employees (
  id uuid primary key default gen_random_uuid(),
  employee_no text not null unique,
  name text not null,
  department text not null,
  job_title text,
  email text,
  line_user_id text unique,
  hire_date date,
  shift_name text not null default '固定班',
  status text not null default 'active' check (status in ('active', 'inactive', 'resigned', 'suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.gps_locations (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  latitude numeric(10, 7),
  longitude numeric(10, 7),
  radius_meters integer not null default 100,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.shifts (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  starts_at time,
  ends_at time,
  break_minutes integer not null default 60,
  grace_minutes integer not null default 10,
  is_flexible boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  punch_type text not null check (punch_type in ('clock_in', 'clock_out', 'break_out', 'break_in', 'field_work', 'overtime_start', 'overtime_end')),
  punched_at timestamptz not null default now(),
  latitude numeric(10, 7),
  longitude numeric(10, 7),
  location_name text,
  distance_meters integer,
  device text,
  ip_address inet,
  line_user_id text,
  source text not null default 'web_liff',
  status text not null default 'normal' check (status in ('normal', 'late', 'early_leave', 'absent', 'missing_punch', 'gps_abnormal', 'off_schedule', 'holiday', 'needs_location')),
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.leave_requests (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  leave_type text not null,
  start_date date not null,
  end_date date not null,
  reason text,
  approval_level integer not null default 1,
  status text not null default 'pending_manager' check (status in ('pending_manager', 'pending_hr', 'approved', 'rejected', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.correction_requests (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  punch_type text not null check (punch_type in ('clock_in', 'clock_out', 'break_out', 'break_in', 'field_work', 'overtime_start', 'overtime_end')),
  requested_at timestamptz not null,
  location_name text,
  reason text,
  status text not null default 'pending_manager' check (status in ('pending_manager', 'pending_hr', 'approved', 'rejected', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.approval_logs (
  id uuid primary key default gen_random_uuid(),
  request_table text not null check (request_table in ('leave_requests', 'correction_requests')),
  request_id uuid not null,
  approver_employee_id uuid references public.employees(id) on delete set null,
  action text not null,
  comment text,
  created_at timestamptz not null default now()
);

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  is_published boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.line_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,
  line_user_id text,
  payload jsonb not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_attendance_employee_time on public.attendance_records(employee_id, punched_at desc);
create index if not exists idx_leave_employee_status on public.leave_requests(employee_id, status);
create index if not exists idx_correction_employee_status on public.correction_requests(employee_id, status);
create index if not exists idx_line_events_user_time on public.line_events(line_user_id, created_at desc);

alter table public.employees enable row level security;
alter table public.gps_locations enable row level security;
alter table public.shifts enable row level security;
alter table public.attendance_records enable row level security;
alter table public.leave_requests enable row level security;
alter table public.correction_requests enable row level security;
alter table public.approval_logs enable row level security;
alter table public.announcements enable row level security;
alter table public.line_events enable row level security;

insert into public.shifts (name, starts_at, ends_at, break_minutes, grace_minutes, is_flexible)
values
  ('固定班', '09:00', '18:00', 60, 10, false),
  ('晚班', '14:00', '23:00', 60, 10, false),
  ('外勤班', null, null, 60, 0, true)
on conflict (name) do nothing;

insert into public.gps_locations (name, latitude, longitude, radius_meters)
values
  ('台北總公司', 25.033964, 121.564468, 100),
  ('高雄工地', 22.627278, 120.301435, 300),
  ('客戶 A', 25.047760, 121.517030, 500)
on conflict (name) do nothing;

insert into public.employees (employee_no, name, department, job_title, email, shift_name, status)
values
  ('EMP-001', '王小美', '設計部', '設計師', 'mei@channeldeco.com', '固定班', 'active'),
  ('EMP-002', '林主管', '設計部', '主管', 'manager@channeldeco.com', '固定班', 'active'),
  ('EMP-003', '陳人資', '人資部', 'HR', 'hr@channeldeco.com', '固定班', 'active'),
  ('EMP-004', '林志豪', '工程部', '現場主管', 'hao@channeldeco.com', '外勤班', 'active'),
  ('EMP-005', '張雅婷', '業務部', '業務', 'ting@channeldeco.com', '外勤班', 'active')
on conflict (employee_no) do nothing;

insert into public.announcements (title, body)
values
  ('上午 09:10 尚未打卡', '系統會自動提醒尚未完成上班打卡的人員。'),
  ('請假簽核上線', '員工可從 LINE Rich Menu 進入請假與補卡申請。')
on conflict do nothing;
