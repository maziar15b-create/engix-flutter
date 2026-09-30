export async function logError({ message, stack, url, userId, extra, level = "error" }) {
  const payload = {
    level,
    source: typeof window === "undefined" ? "server" : "client",
    message: String(message ?? ""),
    stack: stack ? String(stack) : null,
    url: url ?? (typeof window !== "undefined" ? window.location.href : null),
    user_id: userId ?? null,
    extra: extra ?? null,
  };
  console.error("[LOG]", payload);
  try {
    if (typeof window !== "undefined") {
      await fetch("/api/log", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
        keepalive: true,
      });
    } else {
      const { getSupabaseAdmin } = await import("./supabaseAdmin");
      const supabaseAdmin = getSupabaseAdmin();
      await supabaseAdmin.from("app_logs").insert(payload);
    }
  } catch (e) {
    console.error("logError failed:", e);
  }
}
