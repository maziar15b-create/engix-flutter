"use client";
import { useState, useEffect, useCallback } from "react";
import { supabase } from "../lib/supabaseClient";
import AdBanner from "../components/AdBanner";
import JobBoardPanel from "../components/JobBoardPanel";

function AcademyShortcut({ onNavigate }) {
  return (
    <div
      onClick={() => onNavigate("education")}
      style={{
        background: "linear-gradient(160deg, #26232C 0%, #1D1B22 55%, #141318 100%)",
        border: "1px solid rgba(197,3,55,0.35)",
        borderRadius: 12,
        padding: "18px 20px",
        marginBottom: 20,
        display: "flex",
        justifyContent: "space-between",
        alignItems: "center",
        cursor: "pointer",
        position: "relative",
        overflow: "hidden",
        boxShadow: "0 22px 40px -18px rgba(0,0,0,0.85), 0 1px 0 rgba(255,255,255,0.05) inset",
      }}
    >
      <div
        style={{
          position: "absolute", inset: 0,
          backgroundImage:
            "linear-gradient(rgba(197,3,55,0.05) 1px, transparent 1px), linear-gradient(90deg, rgba(197,3,55,0.05) 1px, transparent 1px)",
          backgroundSize: "16px 16px",
          pointerEvents: "none",
        }}
      />
      <div style={{ position: "relative" }}>
        <div style={{ fontWeight: 800, fontSize: 15.5, color: "#F2ECDD" }}>EngiX Academy</div>
        <div style={{ fontSize: 12, color: "#948C78", marginTop: 4 }}>دوره‌ها، آزمون آزمایشی، بانک سوالات و گواهینامه</div>
      </div>
      <span
        style={{
          position: "relative",
          background: "linear-gradient(135deg, #FF3D63, #C50337 60%, #7A0224)",
          color: "#14110A",
          fontWeight: 700,
          fontSize: 11.5,
          borderRadius: 5,
          padding: "5px 10px",
          boxShadow: "0 8px 16px -6px rgba(197,3,55,0.5)",
        }}
      >
        ورود ›
      </span>
    </div>
  );
}

function NewsSection() {
  const [news, setNews] = useState(null);

  const refresh = useCallback(async () => {
    const { data } = await supabase
      .from("news")
      .select("id, title, summary, importance, published_at, created_at, news_categories(label)")
      .order("created_at", { ascending: false })
      .limit(6);
    setNews(data || []);
  }, []);

  useEffect(() => { refresh(); }, [refresh]);

  return (
    <div>
      <div style={{ fontSize: 10.5, fontWeight: 700, marginBottom: 10, color: "#FF3D63", letterSpacing: 2, textTransform: "uppercase", display: "flex", alignItems: "center", gap: 10 }}>
        <span style={{ width: 5, height: 5, borderRadius: "50%", background: "#C50337", boxShadow: "0 0 8px #C50337" }} />
        اخبار مهندسی
        <span style={{ flex: 1, height: 1, background: "linear-gradient(90deg, rgba(197,3,55,0.3), transparent)" }} />
      </div>

      {news === null && <div style={{ color: "#948C78", fontSize: 13 }}>در حال بارگذاری...</div>}

      {news && news.length === 0 && (
        <div style={{ background: "linear-gradient(160deg, #1D1B22, #141318)", border: "1px solid rgba(197,3,55,0.15)", borderRadius: 10, padding: 14 }}>
          <div style={{ fontSize: 13 }}>هنوز خبری همگام‌سازی نشده است.</div>
          <p style={{ fontSize: 10.5, color: "#5E5748", marginTop: 6 }}>سیستم اخبار خودکار هر روز اجرا می‌شود؛ اولین اجرا نیاز به فعال‌سازی دارد.</p>
        </div>
      )}

      {news && news.map((n) => (
        <div
          key={n.id}
          style={{
            background: "linear-gradient(160deg, #1D1B22 0%, #141318 100%)",
            border: "1px solid rgba(197,3,55,0.16)",
            borderRight: "3px solid #C50337",
            borderRadius: 8,
            padding: "12px 14px",
            marginBottom: 8,
            boxShadow: "0 12px 24px -14px rgba(0,0,0,0.7)",
          }}
        >
          <div style={{ fontSize: 13, fontWeight: 700, color: "#F2ECDD" }}>{n.title}</div>
          {n.summary && <div style={{ fontSize: 12, color: "#948C78", marginTop: 4 }}>{n.summary}</div>}
          {n.news_categories?.label && (
            <span
              style={{
                marginTop: 8, display: "inline-block", fontSize: 11,
                color: "#FF3D63", background: "rgba(197,3,55,0.15)",
                border: "1px solid rgba(197,3,55,0.35)", borderRadius: 4, padding: "2px 8px",
              }}
            >
              {n.news_categories.label}
            </span>
          )}
        </div>
      ))}
    </div>
  );
}

export default function HomePanel({ onNavigate, profile }) {
  return (
    <div>
      <div className="section-title">خانه</div>
      <div className="section-sub">خلاصه‌ای از پروژه‌ها و اخبار مهندسی.</div>

      <AdBanner profile={profile} />

      <div style={{ marginBottom: 20 }}>
        <JobBoardPanel profile={profile} compact onOpenChat={(conversationId) => onNavigate("messages")} />
      </div>

      <NotificationsSection profile={profile} />

      <div style={{ marginTop: 20 }}><AcademyShortcut onNavigate={onNavigate} /></div>

      <NewsSection />
    </div>
  );
}

function NotificationsSection({ profile }) {
  const [list, setList] = useState(null);

  const refresh = useCallback(async () => {
    const { data } = await supabase.from("notifications").select("*").eq("user_id", profile.id).order("created_at", { ascending: false }).limit(15);
    setList(data || []);
  }, [profile.id]);
  useEffect(() => { refresh(); }, [refresh]);

  const markRead = async (id) => {
    await supabase.from("notifications").update({ is_read: true }).eq("id", id);
    refresh();
  };

  const unreadCount = (list || []).filter((n) => !n.is_read).length;

  return (
    <div>
      <div style={{ fontSize: 10.5, fontWeight: 700, color: "#FF3D63", letterSpacing: 2, textTransform: "uppercase", marginBottom: 10, display: "flex", alignItems: "center", gap: 8 }}>
        اعلان‌ها
        {unreadCount > 0 && (
          <span
            style={{
              background: "linear-gradient(135deg, #FF3D63, #C50337)",
              color: "#14110A", borderRadius: 10, padding: "2px 8px", fontSize: 10.5, fontWeight: 800,
            }}
          >
            {unreadCount} جدید
          </span>
        )}
      </div>

      {list === null && <div style={{ color: "#948C78", fontSize: 13 }}>در حال بارگذاری...</div>}
      {list && list.length === 0 && (
        <div style={{ background: "linear-gradient(160deg, #1D1B22, #141318)", border: "1px solid rgba(197,3,55,0.15)", borderRadius: 10, padding: 14 }}>
          <div style={{ fontSize: 13 }}>به EngiX خوش آمدید — اولین پروژه خود را بسازید یا با کد به یکی بپیوندید.</div>
        </div>
      )}
      {list && list.map((n) => (
        <div
          key={n.id}
          onClick={() => !n.is_read && markRead(n.id)}
          style={{
            background: n.is_read
              ? "linear-gradient(160deg, #1D1B22, #141318)"
              : "linear-gradient(160deg, rgba(197,3,55,0.14), rgba(122,2,36,0.08))",
            border: n.is_read ? "1px solid rgba(197,3,55,0.12)" : "1px solid rgba(197,3,55,0.45)",
            borderRadius: 8,
            padding: "12px 14px",
            marginBottom: 8,
            cursor: n.is_read ? "default" : "pointer",
            boxShadow: "0 12px 24px -14px rgba(0,0,0,0.7)",
          }}
        >
          <div style={{ fontSize: 13, fontWeight: 700, color: "#F2ECDD" }}>{n.title}</div>
          {n.body && <div style={{ fontSize: 12.5, color: "#948C78", marginTop: 3 }}>{n.body}</div>}
        </div>
      ))}
    </div>
  );
}
