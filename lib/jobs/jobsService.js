import { supabase } from "../supabaseClient";

export async function fetchJobPosts(filterType) {
  var query = supabase
    .from("job_posts")
    .select("*")
    .eq("status", "open")
    .order("created_at", { ascending: false });

  if (filterType) {
    query = query.eq("type", filterType);
  }

  const { data, error } = await query;
  if (error) throw new Error(error.message);
  return data || [];
}

export async function fetchMyJobPosts(userId) {
  const { data, error } = await supabase
    .from("job_posts")
    .select("*")
    .eq("posted_by", userId)
    .order("created_at", { ascending: false });
  if (error) throw new Error(error.message);
  return data || [];
}

export async function createJobPost(params) {
  const row = {
    type: params.type,
    title: params.title,
    description: params.description || null,
    posted_by: params.postedBy,
    budget: params.budget || null,
    location: params.location || null,
    status: "pending_payment",
  };
  const { data, error } = await supabase.from("job_posts").insert(row).select().single();
  if (error) throw new Error(error.message);

  const paymentUrl = await requestJobPostPayment(params.postedBy, data.id);
  return { jobPost: data, paymentUrl };
}

// درخواست پرداخت زرین‌پال برای آگهی کار/پروژه ساخته‌شده
export async function requestJobPostPayment(userId, jobPostId, meta = {}) {
  const { data: sessionData } = await supabase.auth.getSession();
  const token = sessionData?.session?.access_token;
  if (!token) throw new Error("لطفاً دوباره وارد شوید.");

  const res = await fetch("/api/payments/request", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify({
      itemType: "job_post",
      itemId: jobPostId,
      description: "هزینه ثبت آگهی کار/پروژه",
      mobile: meta.mobile,
      email: meta.email,
    }),
  });
  const json = await res.json();
  if (!res.ok) throw new Error(json.error || "خطا در اتصال به درگاه پرداخت");
  return json.paymentUrl;
}

export async function closeJobPost(jobPostId) {
  const { error } = await supabase.from("job_posts").update({ status: "closed" }).eq("id", jobPostId);
  if (error) throw new Error(error.message);
}

export async function deleteJobPost(jobPostId) {
  const { error } = await supabase.from("job_posts").delete().eq("id", jobPostId);
  if (error) throw new Error(error.message);
}

export async function applyToJob(params) {
  const row = {
    job_post_id: params.jobPostId,
    applicant_id: params.applicantId,
    message: params.message || null,
    price_quote: params.priceQuote || null
  };
  const { error } = await supabase.from("job_applications").insert(row);
  if (error) {
    if (error.code === "23505") throw new Error("قبلاً برای این آگهی درخواست داده‌اید.");
    throw new Error(error.message);
  }
}

export async function fetchApplicationsForPost(jobPostId) {
  // (join تو در توی قبلی به‌خاطر مشکل schema cache در دیتابیس خطا می‌داد؛
  // اینجا با دو کوئری جدا و اتصال دستی جایگزین شده)
  const { data: apps, error } = await supabase
    .from("job_applications")
    .select("*")
    .eq("job_post_id", jobPostId)
    .order("created_at", { ascending: false });
  if (error) throw new Error(error.message);
  if (!apps || apps.length === 0) return [];

  const applicantIds = [...new Set(apps.map((a) => a.applicant_id).filter(Boolean))];
  let profileById = {};
  if (applicantIds.length > 0) {
    const { data: profs, error: profErr } = await supabase
      .from("profiles")
      .select("id, name, code")
      .in("id", applicantIds);
    if (profErr) throw new Error(profErr.message);
    (profs || []).forEach((p) => { profileById[p.id] = p; });
  }
  return apps.map((a) => ({ ...a, profiles: profileById[a.applicant_id] || null }));
}

export async function fetchMyApplications(userId) {
  const { data, error } = await supabase
    .from("job_applications")
    .select("*, job_posts(id, title, type, status)")
    .eq("applicant_id", userId)
    .order("created_at", { ascending: false });
  if (error) throw new Error(error.message);
  return data || [];
}

export async function updateApplicationStatus(applicationId, status) {
  const { error } = await supabase.from("job_applications").update({ status: status }).eq("id", applicationId);
  if (error) throw new Error(error.message);
}

export async function fetchResume(userId) {
  const { data, error } = await supabase.from("resumes").select("*").eq("user_id", userId).maybeSingle();
  if (error) throw new Error(error.message);
  return data;
}

export async function saveResume(userId, fields) {
  const row = {
    user_id: userId,
    summary: fields.summary || null,
    experience_years: fields.experienceYears || null,
    skills: fields.skills || [],
    portfolio_urls: fields.portfolioUrls || [],
    updated_at: new Date().toISOString()
  };
  const { error } = await supabase.from("resumes").upsert(row, { onConflict: "user_id" });
  if (error) throw new Error(error.message);
}

export async function fetchCompanyProfile(userId) {
  const { data, error } = await supabase.from("company_profiles").select("*").eq("user_id", userId).maybeSingle();
  if (error) throw new Error(error.message);
  return data;
}

export async function saveCompanyProfile(userId, fields) {
  const row = {
    user_id: userId,
    company_name: fields.companyName || null,
    company_intro: fields.companyIntro || null,
    services: fields.services || [],
    updated_at: new Date().toISOString()
  };
  const { error } = await supabase.from("company_profiles").upsert(row, { onConflict: "user_id" });
  if (error) throw new Error(error.message);
}

export async function fetchWorkerProfile(userId) {
  const { data, error } = await supabase.from("worker_profiles").select("*").eq("user_id", userId).maybeSingle();
  if (error) throw new Error(error.message);
  return data;
}

export async function saveWorkerProfile(userId, fields) {
  const row = {
    user_id: userId,
    trade: fields.trade || null,
    daily_rate: fields.dailyRate || null,
    experience_years: fields.experienceYears || null,
    updated_at: new Date().toISOString()
  };
  const { error } = await supabase.from("worker_profiles").upsert(row, { onConflict: "user_id" });
  if (error) throw new Error(error.message);
}
