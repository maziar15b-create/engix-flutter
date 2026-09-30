"use client";
import { useState, useEffect, useMemo } from "react";
import { useChats } from "../../hooks/useChats";
import OnlineStatus from "./OnlineStatus";

const GOLD_LIGHT = "#FF3D63";
const GOLD = "#C50337";
const AVATAR_COLORS = ["#FF3D63", "#C50337", "#7A0224", "#B8860B", "#3D7BFF", "#2FAE60"];

function avatarColorFor(id) {
  if (!id) return AVATAR_COLORS[0];
  let sum = 0;
  for (let i = 0; i < id.length; i++) sum += id.charCodeAt(i);
  return AVATAR_COLORS[sum % AVATAR_COLORS.length];
}

function formatTime(dateStr) {
  if (!dateStr) return "";
  const d = new Date(dateStr);
  const now = new Date();
  const sameDay = d.toDateString() === now.toDateString();
  if (sameDay) return d.toLocaleTimeString("fa-IR", { hour: "2-digit", minute: "2-digit" });
  return d.toLocaleDateString("fa-IR", { month: "short", day: "numeric" });
}

function Avatar({ chat }) {
  const color = avatarColorFor(chat.id);
  const initial = (chat.displayName || "؟").trim().charAt(0);
  return (
    <div
      style={{
        width: 48, height: 48, borderRadius: "50%", flexShrink: 0,
        background: chat.avatar_url ? undefined : `linear-gradient(150deg, ${color}, #141318)`,
        display: "flex", alignItems: "center", justifyContent: "center",
        fontSize: 18, fontWeight: 700, color: "#F2ECDD", overflow: "hidden",
        boxShadow: "0 6px 14px -6px rgba(0,0,0,0.6)",
      }}
    >
      {chat.avatar_url ? (
        <img loading="lazy" decoding="async" src={chat.avatar_url} alt="" style={{ width: "100%", height: "100%", objectFit: "cover" }} />
      ) : (
        initial
      )}
    </div>
  );
}

export default function ChatsList({ profile, presence, onOpenThread }) {
  const { pinned, active, archived, loading, error, togglePin, toggleMute, toggleArchive } =
    useChats(profile.id);
  const [showArchived, setShowArchived] = useState(false);
  const [openMenuFor, setOpenMenuFor] = useState(null);

  // برای نشون‌دادن وضعیت آنلاین کنار هر گفتگوی مستقیم، باید صراحتاً presence
  // طرف‌های مقابل را لود کنیم (مدل presence دیگر سراسری نیست، فقط شناسه‌هایی
  // که با loadPresenceFor خواسته شوند poll می‌شوند)
  const directOtherIds = useMemo(() => {
    const all = [...pinned, ...active, ...archived];
    return [...new Set(all.filter((c) => c.type === "direct" && c._otherUserId).map((c) => c._otherUserId))];
  }, [pinned, active, archived]);

  const { loadPresenceFor } = presence;
  useEffect(() => {
    if (directOtherIds.length > 0) loadPresenceFor(directOtherIds);
    // loadPresenceFor خودش با useCallback بدون وابستگی ساخته شده (رفرنس پایدار)
    // پس وابسته‌کردن افکت به کل شیء presence (که هر رندر شیء جدیدی است) باعث
    // اجرای مکرر/حلقه‌ی بی‌مورد می‌شد؛ فقط به تابع و به رشته‌ی پایدار id ها وابسته‌ایم.
  }, [directOtherIds, loadPresenceFor]);

  const renderChatRow = (chat) => {
    // فیلدهای پیش‌فرض احتیاطی‌اند تا اگر useChats این‌ها را برنگرداند، UI نشکند
    const lastText = chat.lastMessage?.content || chat.last_message?.content || "";
    const lastAt = chat.lastMessage?.created_at || chat.last_message?.created_at || chat.updated_at;
    const unread = chat.unread_count || 0;

    return (
      <div key={chat.id} style={{ position: "relative" }}>
        <div
          onClick={() => onOpenThread(chat.id)}
          className="pressable"
          style={{
            display: "flex", alignItems: "center", gap: 12, cursor: "pointer",
            padding: "10px 4px", borderBottom: "1px solid rgba(197,3,55,0.08)",
          }}
        >
          <div style={{ position: "relative", flexShrink: 0 }}>
            <Avatar chat={chat} />
            {chat.type === "direct" && chat._otherUserId && (
              <span style={{ position: "absolute", bottom: 1, left: 1 }}>
                <OnlineStatus isOnline={presence.isOnline(chat._otherUserId)} size={10} />
              </span>
            )}
          </div>

          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 8 }}>
              <div style={{ fontWeight: 700, fontSize: 14.5, color: "#F2ECDD", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", display: "flex", alignItems: "center", gap: 4 }}>
                {chat.is_pinned && <span style={{ fontSize: 11 }}>📌</span>}
                {chat.displayName}
              </div>
              <span style={{ fontSize: 11, color: unread > 0 ? GOLD_LIGHT : "#5E5748", flexShrink: 0, fontWeight: unread > 0 ? 700 : 400 }}>
                {formatTime(lastAt)}
              </span>
            </div>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 8, marginTop: 3 }}>
              <div style={{ fontSize: 12.5, color: "#8C8474", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", flex: 1 }}>
                {chat.is_muted && "🔕 "}
                {lastText || "هنوز پیامی نیست"}
              </div>
              {unread > 0 && (
                <span
                  style={{
                    minWidth: 19, height: 19, borderRadius: 10, padding: "0 5px", flexShrink: 0,
                    background: `linear-gradient(135deg, ${GOLD_LIGHT}, ${GOLD})`,
                    color: "#14110A", fontSize: 10.5, fontWeight: 800,
                    display: "flex", alignItems: "center", justifyContent: "center",
                  }}
                >
                  {unread > 99 ? "99+" : unread}
                </span>
              )}
            </div>
          </div>

          <button
            className="btn-ghost"
            style={{ padding: "4px 6px", fontSize: 14, flexShrink: 0, color: "#5E5748", border: "none", background: "none" }}
            onClick={(e) => {
              e.stopPropagation();
              setOpenMenuFor(openMenuFor === chat.id ? null : chat.id);
            }}
          >
            ⋮
          </button>
        </div>

        {openMenuFor === chat.id && (
          <div
            style={{
              position: "absolute", left: 8, top: "100%", zIndex: 10,
              background: "linear-gradient(160deg, #26232C, #141318)",
              border: "1px solid rgba(197,3,55,0.3)", borderRadius: 10, padding: 6, minWidth: 170,
              boxShadow: "0 20px 40px -16px rgba(0,0,0,0.8)",
            }}
          >
            <MenuAction
              label={chat.is_pinned ? "برداشتن پین" : "پین کردن"}
              onClick={() => { togglePin(chat.id, chat.is_pinned); setOpenMenuFor(null); }}
            />
            <MenuAction
              label={chat.is_muted ? "فعال کردن اعلان" : "بی‌صدا کردن"}
              onClick={() => { toggleMute(chat.id, chat.is_muted); setOpenMenuFor(null); }}
            />
            <MenuAction
              label={chat.is_archived ? "خروج از آرشیو" : "آرشیو کردن"}
              onClick={() => { toggleArchive(chat.id, chat.is_archived); setOpenMenuFor(null); }}
            />
          </div>
        )}
      </div>
    );
  };

  if (loading) {
    return (
      <div style={{ padding: "4px 4px" }}>
        {[0, 1, 2, 3, 4].map((i) => (
          <div key={i} style={{ display: "flex", alignItems: "center", gap: 12, padding: "10px 4px" }}>
            <div className="skeleton" style={{ width: 48, height: 48, borderRadius: "50%", flexShrink: 0 }} />
            <div style={{ flex: 1 }}>
              <div className="skeleton" style={{ height: 13, width: "45%", borderRadius: 4, marginBottom: 8 }} />
              <div className="skeleton" style={{ height: 11, width: "70%", borderRadius: 4 }} />
            </div>
          </div>
        ))}
      </div>
    );
  }
  if (error) return <div style={{ color: "#E5484D", fontSize: 13, padding: "12px 4px" }}>خطا: {error}</div>;

  const noChatsAtAll = pinned.length === 0 && active.length === 0 && archived.length === 0;

  return (
    <div onClick={() => openMenuFor && setOpenMenuFor(null)}>
      {noChatsAtAll && (
        <div style={{ color: "#5E5748", fontSize: 13, padding: "20px 4px", textAlign: "center" }}>
          هنوز گفتگویی ندارید. از تب «مخاطبین» شروع کنید.
        </div>
      )}

      {pinned.length > 0 && <>{pinned.map(renderChatRow)}</>}
      {active.length > 0 && <>{active.map(renderChatRow)}</>}

      {archived.length > 0 && (
        <div style={{ marginTop: 10 }}>
          <div
            style={{ fontSize: 11.5, color: "#8C8474", fontWeight: 700, letterSpacing: 1, cursor: "pointer", padding: "10px 4px" }}
            onClick={() => setShowArchived((v) => !v)}
          >
            {showArchived ? "▾" : "▸"} آرشیو ({archived.length})
          </div>
          {showArchived && <div>{archived.map(renderChatRow)}</div>}
        </div>
      )}
    </div>
  );
}

function MenuAction({ label, onClick }) {
  return (
    <div
      onClick={onClick}
      style={{ padding: "9px 11px", fontSize: 12.5, cursor: "pointer", borderRadius: 7, color: "#E7E1D2" }}
      onMouseEnter={(e) => (e.currentTarget.style.background = "rgba(197,3,55,0.12)")}
      onMouseLeave={(e) => (e.currentTarget.style.background = "transparent")}
    >
      {label}
    </div>
  );
}
