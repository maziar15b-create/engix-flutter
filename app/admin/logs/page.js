"use client";
import { useEffect, useState } from "react";
import { supabase } from "../../../lib/supabaseClient";

const LEVEL_COLORS = { fatal: "#7f1d1d", error: "#dc2626", warning: "#d97706", info: "#2563eb" };

export default function LogsPage() {
  const [logs, setLogs] = useState([]);
  const [level, setLevel] = useState("all");
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState(null);

  async function fetchLogs(l) {
    setLoading(true);
    setErr(null);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      const token = session?.access_token;
      const res = await fetch(`/api/admin/logs?level=${l}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      const json = await res.json();
      if (!res.ok) throw new Error(json.error || "خطا در دریافت لاگ‌ها");
      setLogs(json.logs || []);
    } catch (e) {
      setErr(e.message);
    } finally {
      setLoading(false);
    }
  }

  async function clearLogs() {
    const { data: { session } } = await supabase.auth.getSession();
    const token = session?.access_token;
    await fetch("/api/admin/logs", {
      method: "DELETE",
      headers: { Authorization: `Bearer ${token}` },
    });
    fetchLogs(level);
  }

  useEffect(() => {
    fetchLogs(level);
  }, [level]);

  return (
    <div dir="rtl" style={{ padding: 16, fontFamily: "sans-serif", maxWidth: 900, margin: "0 auto" }}>
      <h1 style={{ fontSize: 20, marginBottom: 12 }}>لاگ‌های اپلیکیشن ({logs.length})</h1>

      <div style={{ display: "flex", gap: 8, marginBottom: 16, flexWrap: "wrap" }}>
        {["all", "fatal", "error", "warning", "info"].map((l) => (
          <button
            key={l}
            onClick={() => setLevel(l)}
            style={{
              padding: "4px 12px",
              borderRadius: 6,
              fontSize: 13,
              border: "none",
              cursor: "pointer",
              color: level === l ? "#fff" : "#333",
              background: level === l ? "#111" : "#eee",
            }}
          >
            {l}
          </button>
        ))}
        <button
          onClick={clearLogs}
          style={{ marginRight: "auto", padding: "4px 12px", borderRadius: 6, fontSize: 13, background: "#dc2626", color: "#fff", border: "none", cursor: "pointer" }}
        >
          پاک کردن همه
        </button>
      </div>

      {loading && <p>در حال بارگذاری...</p>}
      {err && <p style={{ color: "red" }}>{err}</p>}
      {!loading && logs.length === 0 && <p style={{ color: "#888" }}>لاگی ثبت نشده.</p>}

      <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
        {logs.map((log) => (
          <div key={log.id} style={{ border: `1px solid ${LEVEL_COLORS[log.level] || "#ccc"}`, borderRight: `4px solid ${LEVEL_COLORS[log.level] || "#ccc"}`, borderRadius: 6, padding: 10, fontSize: 13 }}>
            <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 4 }}>
              <strong style={{ color: LEVEL_COLORS[log.level] || "#333" }}>{log.level?.toUpperCase()} · {log.source}</strong>
              <span style={{ color: "#888", fontSize: 11, direction: "ltr" }}>{new Date(log.created_at).toLocaleString("fa-IR")}</span>
            </div>
            <div style={{ marginBottom: 4 }}>{log.message}</div>
            {log.url && <div style={{ color: "#666", fontSize: 11, direction: "ltr", textAlign: "left" }}>{log.url}</div>}
            {log.stack && (
              <details style={{ marginTop: 6 }}>
                <summary style={{ cursor: "pointer", color: "#666" }}>جزئیات فنی</summary>
                <pre style={{ whiteSpace: "pre-wrap", fontSize: 11, direction: "ltr", textAlign: "left", background: "#f5f5f5", padding: 8, borderRadius: 4, marginTop: 4 }}>{log.stack}</pre>
              </details>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
