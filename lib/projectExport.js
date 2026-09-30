// lib/projectExport.js
import { supabase } from "./supabaseClient";

// سطل عمومی روی Supabase Storage برای فایل‌های خروجی (PDF/Excel) پروژه‌ها.
// این سطل باید در پنل Supabase به‌صورت Public ساخته شود (مثل messenger-attachments).
export const EXPORT_BUCKET = "project-exports";

const DIRECTION_LABELS = { incoming: "وارده", outgoing: "صادره" };
const QC_STATUS_LABELS = { pass: "قبول", fail: "رد", pending: "در انتظار" };
const ATTENDANCE_STATUS_LABELS = { present: "حاضر", absent: "غایب", half: "نیمه‌روز" };
const WORKORDER_ACTION_STATUS = { done: "انجام‌شده", pending: "در انتظار" };
const INVENTORY_TYPE_LABELS = { in: "ورود", out: "خروج" };

// تعریف تمام بخش‌های قابل‌خروجی پروژه. هر بخش می‌داند از کدام جدول و چطور بخواند.
export const EXPORT_SECTION_DEFS = [
  { key: "correspondence", label: "نامه‌ها / مکاتبات" },
  { key: "dailyreport", label: "گزارش روزانه" },
  { key: "reports", label: "گزارش کار" },
  { key: "supervision", label: "نظارت" },
  { key: "gantt", label: "برنامه زمان‌بندی" },
  { key: "workorder", label: "دستور کار" },
  { key: "qc", label: "کنترل کیفیت" },
  { key: "documents", label: "دفتر فنی / اسناد" },
  { key: "inventory", label: "انبار" },
  { key: "attendance", label: "حضور و غیاب" },
  { key: "photos", label: "گالری تصاویر" },
  { key: "announcements", label: "اطلاعیه‌ها" },
];

function fmtDate(v) {
  if (!v) return "—";
  return String(v).slice(0, 10);
}

async function fetchProfilesMap(ids) {
  const unique = [...new Set(ids.filter(Boolean))];
  if (unique.length === 0) return {};
  const { data } = await supabase.from("profiles").select("id, name").in("id", unique);
  const map = {};
  (data || []).forEach((p) => { map[p.id] = p.name; });
  return map;
}
const nameOf = (map, id) => (id && map[id]) || (id ? "—" : "—");

// تمام داده‌های خام لازم برای همه‌ی بخش‌ها را واکشی می‌کند (به‌صورت موازی).
export async function fetchAllProjectData(projectId) {
  const [
    correspondence, dailyReports, updates, supervision, gantt,
    workOrders, qcItems, documents, inventory,
    attendance, photos, announcements,
  ] = await Promise.all([
    supabase.from("project_correspondence").select("*").eq("project_id", projectId).order("correspondence_date", { ascending: false }),
    supabase.from("project_daily_reports").select("*").eq("project_id", projectId).order("report_date", { ascending: false }),
    supabase.from("project_updates").select("id, report_type, body, created_at, author_id").eq("project_id", projectId).order("created_at", { ascending: false }),
    supabase.from("reports").select("*").eq("project_id", projectId).order("created_at", { ascending: false }),
    supabase.from("project_gantt_tasks").select("*").eq("project_id", projectId).order("order_index"),
    supabase.from("project_work_orders").select("*").eq("project_id", projectId).order("meeting_date", { ascending: false }),
    supabase.from("project_qc_items").select("*").eq("project_id", projectId).order("order_index"),
    supabase.from("project_documents").select("*").eq("project_id", projectId).order("created_at", { ascending: false }),
    supabase.from("project_inventory_transactions").select("*").eq("project_id", projectId).order("transaction_date", { ascending: false }),
    supabase.from("project_attendance").select("*").eq("project_id", projectId).order("attendance_date", { ascending: false }),
    supabase.from("project_photos").select("*").eq("project_id", projectId).order("taken_date", { ascending: false }),
    supabase.from("announcements").select("*").eq("project_id", projectId).order("created_at", { ascending: false }),
  ]);

  const woIds = (workOrders.data || []).map((w) => w.id);
  let actionsData = [];
  if (woIds.length > 0) {
    const { data } = await supabase.from("project_work_order_actions").select("*").in("work_order_id", woIds).order("order_index");
    actionsData = data || [];
  }

  const allPersonIds = []
    .concat((correspondence.data || []).map((r) => r.created_by))
    .concat((dailyReports.data || []).map((r) => r.created_by))
    .concat((updates.data || []).map((r) => r.author_id))
    .concat((supervision.data || []).map((r) => r.by))
    .concat((gantt.data || []).map((r) => r.created_by))
    .concat((workOrders.data || []).map((r) => r.created_by))
    .concat((documents.data || []).map((r) => r.uploaded_by))
    .concat((inventory.data || []).map((r) => r.created_by))
    .concat((attendance.data || []).map((r) => r.recorded_by))
    .concat((photos.data || []).map((r) => r.uploaded_by))
    .concat((announcements.data || []).map((r) => r.by));
  const profilesMap = await fetchProfilesMap(allPersonIds);

  return {
    correspondence: correspondence.data || [],
    dailyReports: dailyReports.data || [],
    updates: updates.data || [],
    supervision: supervision.data || [],
    gantt: gantt.data || [],
    workOrders: workOrders.data || [],
    workOrderActions: actionsData,
    qcItems: qcItems.data || [],
    documents: documents.data || [],
    inventory: inventory.data || [],
    attendance: attendance.data || [],
    photos: photos.data || [],
    announcements: announcements.data || [],
    profilesMap,
  };
}

// داده‌ی خام هر بخش را به { headers, rows } یکنواخت برای رندر جدول/PDF/اکسل تبدیل می‌کند.
export function buildReportSections(raw, selectedKeys) {
  const p = raw.profilesMap;
  const sections = [];

  const push = (key, label, headers, rows) => {
    if (selectedKeys && !selectedKeys.includes(key)) return;
    sections.push({ key, label, headers, rows });
  };

  push("correspondence", "نامه‌ها / مکاتبات",
    ["تاریخ", "جهت", "شماره نامه", "موضوع", "طرف مقابل", "متن/خلاصه"],
    raw.correspondence.map((r) => [fmtDate(r.correspondence_date), DIRECTION_LABELS[r.direction] || r.direction, r.letter_number || "—", r.subject || "—", r.counterparty || "—", r.content || "—"]));

  push("dailyreport", "گزارش روزانه",
    ["تاریخ", "آب‌وهوا", "نیروی انسانی", "یادداشت تجهیزات", "فعالیت‌ها", "مشکلات"],
    raw.dailyReports.map((r) => [fmtDate(r.report_date), r.weather || "—", r.workforce_count ?? "—", r.equipment_notes || "—", r.activities || "—", r.issues || "—"]));

  push("reports", "گزارش کار",
    ["تاریخ", "نوع گزارش", "نویسنده", "متن"],
    raw.updates.map((r) => [fmtDate(r.created_at), r.report_type || "—", nameOf(p, r.author_id), r.body || "—"]));

  push("supervision", "نظارت",
    ["تاریخ", "ثبت‌کننده", "متن یادداشت"],
    raw.supervision.map((r) => [fmtDate(r.created_at), nameOf(p, r.by), r.text || "—"]));

  push("gantt", "برنامه زمان‌بندی",
    ["فعالیت", "تاریخ شروع", "مدت (روز)", "درصد پیشرفت"],
    raw.gantt.map((r) => [r.name || "—", fmtDate(r.start_date), r.duration_days ?? "—", (r.progress_percent ?? 0) + "%"]));

  {
    const actionsByOrder = {};
    raw.workOrderActions.forEach((a) => {
      (actionsByOrder[a.work_order_id] = actionsByOrder[a.work_order_id] || []).push(a);
    });
    const rows = [];
    raw.workOrders.forEach((w) => {
      rows.push([fmtDate(w.meeting_date), w.title || "—", w.attendees || "—", w.content || "—", "—"]);
      (actionsByOrder[w.id] || []).forEach((a) => {
        rows.push(["", "  ↳ " + (a.text || "—"), a.assignee || "—", a.due_date ? "مهلت: " + fmtDate(a.due_date) : "", WORKORDER_ACTION_STATUS[a.status] || a.status || "—"]);
      });
    });
    push("workorder", "دستور کار", ["تاریخ جلسه", "عنوان / اقدام", "حاضرین / مسئول", "متن / مهلت", "وضعیت"], rows);
  }

  push("qc", "کنترل کیفیت",
    ["فاز", "آیتم", "وضعیت", "یادداشت"],
    raw.qcItems.map((r) => [r.phase || "—", r.item_text || "—", QC_STATUS_LABELS[r.status] || r.status || "در انتظار", r.notes || "—"]));

  push("documents", "دفتر فنی / اسناد",
    ["تاریخ", "عنوان", "دسته‌بندی", "آپلودکننده", "لینک فایل"],
    raw.documents.map((r) => [fmtDate(r.created_at), r.title || "—", r.category || "—", nameOf(p, r.uploaded_by), r.file_url || "—"]));

  push("inventory", "انبار",
    ["تاریخ", "کد کالا", "نام کالا", "واحد", "نوع تراکنش", "مقدار", "یادداشت"],
    raw.inventory.map((r) => [fmtDate(r.transaction_date), r.material_code || "—", r.material_name || "—", r.unit || "—", INVENTORY_TYPE_LABELS[r.transaction_type] || r.transaction_type || "—", r.quantity ?? "—", r.notes || "—"]));

  push("attendance", "حضور و غیاب",
    ["تاریخ", "نام نیرو", "تخصص", "وضعیت"],
    raw.attendance.map((r) => [fmtDate(r.attendance_date), r.worker_name || "—", r.trade || "—", ATTENDANCE_STATUS_LABELS[r.status] || r.status || "—"]));

  push("photos", "گالری تصاویر",
    ["تاریخ", "توضیح", "لینک تصویر"],
    raw.photos.map((r) => [fmtDate(r.taken_date), r.caption || "—", r.photo_url || "—"]));

  push("announcements", "اطلاعیه‌ها",
    ["تاریخ", "ثبت‌کننده", "متن"],
    raw.announcements.map((r) => [fmtDate(r.created_at), nameOf(p, r.by), r.text || "—"]));

  return sections;
}

// یک المان HTML (سفید/برای چاپ) از بخش‌های گزارش می‌سازد تا با html2canvas عکس گرفته شود.
export function renderReportHtml(project, sections, generatedAt) {
  const style = `
    <style>
      * { box-sizing: border-box; }
      body, div, td, th { font-family: Tahoma, "Vazirmatn", Arial, sans-serif; }
    </style>
  `;
  const sectionsHtml = sections.map((s) => {
    if (s.rows.length === 0) {
      return `<div style="margin-bottom:22px;">
        <div style="font-size:14px;font-weight:700;color:#7A0224;border-bottom:2px solid #C50337;padding-bottom:4px;margin-bottom:8px;">${s.label}</div>
        <div style="font-size:11.5px;color:#999;">داده‌ای ثبت نشده است.</div>
      </div>`;
    }
    const head = `<tr>${s.headers.map((h) => `<th style="border:1px solid #ccc;padding:5px 6px;background:#f3f1ec;font-size:10.5px;">${h}</th>`).join("")}</tr>`;
    const body = s.rows.map((row) => `<tr>${row.map((c) => `<td style="border:1px solid #ddd;padding:5px 6px;font-size:10.5px;vertical-align:top;">${String(c ?? "—")}</td>`).join("")}</tr>`).join("");
    return `<div style="margin-bottom:22px;">
      <div style="font-size:14px;font-weight:700;color:#7A0224;border-bottom:2px solid #C50337;padding-bottom:4px;margin-bottom:8px;">${s.label} <span style="font-size:11px;color:#888;font-weight:400;">(${s.rows.length} مورد)</span></div>
      <table style="width:100%;border-collapse:collapse;direction:rtl;">${head}${body}</table>
    </div>`;
  }).join("");

  return `${style}
    <div id="engix-report-root" dir="rtl" style="width:760px;background:#fff;color:#222;padding:26px;">
      <div style="text-align:center;margin-bottom:22px;border-bottom:3px solid #C50337;padding-bottom:14px;">
        <div style="font-size:19px;font-weight:800;color:#141318;">گزارش یکپارچه پروژه: ${project?.name || "—"}</div>
        <div style="font-size:11.5px;color:#777;margin-top:6px;">
          ${project?.location ? "محل: " + project.location + " · " : ""}${project?.company_name ? "کارفرما/شرکت: " + project.company_name + " · " : ""}تاریخ تولید گزارش: ${generatedAt}
        </div>
      </div>
      ${sectionsHtml}
    </div>`;
}

// PDF را با گرفتن عکس از HTML رندرشده می‌سازد (پشتیبانی کامل از فارسی/راست‌به‌چپ).
export async function generatePdfBlob(project, sections, generatedAt) {
  const [{ default: jsPDF }, { default: html2canvas }] = await Promise.all([
    import("jspdf"),
    import("html2canvas"),
  ]);

  const container = document.createElement("div");
  container.style.position = "fixed";
  container.style.top = "-99999px";
  container.style.left = "-99999px";
  container.innerHTML = renderReportHtml(project, sections, generatedAt);
  document.body.appendChild(container);

  try {
    const target = container.querySelector("#engix-report-root");
    if (!target) throw new Error("محتوای گزارش برای تبدیل به PDF آماده نشد.");
    const canvas = await html2canvas(target, { scale: 2, backgroundColor: "#ffffff", useCORS: true });
    if (!canvas.width || !canvas.height) throw new Error("تصویر گزارش خالی تولید شد؛ دوباره تلاش کنید.");
    const pdf = new jsPDF({ orientation: "p", unit: "mm", format: "a4" });
    const pageWidth = pdf.internal.pageSize.getWidth();
    const pageHeight = pdf.internal.pageSize.getHeight();
    const imgWidth = pageWidth;
    const imgHeight = (canvas.height * imgWidth) / canvas.width;

    let heightLeft = imgHeight;
    let position = 0;
    const imgData = canvas.toDataURL("image/png");

    pdf.addImage(imgData, "PNG", 0, position, imgWidth, imgHeight);
    heightLeft -= pageHeight;
    while (heightLeft > 0) {
      position = heightLeft - imgHeight;
      pdf.addPage();
      pdf.addImage(imgData, "PNG", 0, position, imgWidth, imgHeight);
      heightLeft -= pageHeight;
    }
    return pdf.output("blob");
  } finally {
    document.body.removeChild(container);
  }
}

// اکسل چندشیتی (هر بخش یک شیت) با کتابخانه‌ی xlsx می‌سازد.
export async function generateExcelBlob(project, sections) {
  const XLSX = await import("xlsx");
  const wb = XLSX.utils.book_new();

  const overviewRows = [
    ["نام پروژه", project?.name || "—"],
    ["محل اجرا", project?.location || "—"],
    ["کارفرما / شرکت", project?.company_name || "—"],
    ["درصد پیشرفت", (project?.progress_percent ?? 0) + "%"],
  ];
  const overviewSheet = XLSX.utils.aoa_to_sheet(overviewRows);
  XLSX.utils.book_append_sheet(wb, overviewSheet, "نمای کلی");

  const usedNames = new Set(["نمای کلی"]);
  sections.forEach((s) => {
    const aoa = [s.headers, ...s.rows];
    const sheet = XLSX.utils.aoa_to_sheet(aoa);
    // نام شیت در اکسل حداکثر ۳۱ کاراکتر است و نباید کاراکترهای \ / ? * [ ] : داشته باشد
    let sheetName = s.label.replace(/[\\/?*\[\]:]/g, "-").slice(0, 31);
    let candidate = sheetName;
    let i = 2;
    while (usedNames.has(candidate)) {
      candidate = sheetName.slice(0, 28) + "-" + i;
      i += 1;
    }
    usedNames.add(candidate);
    XLSX.utils.book_append_sheet(wb, sheet, candidate);
  });

  const arrayBuffer = XLSX.write(wb, { bookType: "xlsx", type: "array" });
  return new Blob([arrayBuffer], { type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" });
}

// فایل خروجی را روی سطل عمومی پروژه‌ها آپلود می‌کند و لینک عمومی برمی‌گرداند.
export async function uploadExportFile(blob, projectId, fileName) {
  const storagePath = `${projectId}/${Date.now()}-${fileName}`;
  const { error } = await supabase.storage.from(EXPORT_BUCKET).upload(storagePath, blob, {
    contentType: blob.type,
    upsert: false,
  });
  if (error) throw new Error("آپلود فایل خروجی ناموفق بود: " + error.message);
  const { data } = supabase.storage.from(EXPORT_BUCKET).getPublicUrl(storagePath);
  return { url: data.publicUrl, storagePath };
}

export function downloadBlob(blob, fileName) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = fileName;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 5000);
}
