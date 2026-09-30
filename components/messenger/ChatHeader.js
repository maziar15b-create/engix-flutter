"use client";
import { useState } from "react";
import OnlineStatus from "./OnlineStatus";
import { formatLastSeen } from "../../services/presenceService";
import { blockUser, unblockUser, fetchIsBlocked } from "../../services/socialService";

const GOLD_LIGHT = "#FF3D63";
const GOLD = "#C50337";

export default function ChatHeader(props) {
  const conversation = props.conversation;
  const title = props.title;
  const otherUser = props.otherUser;
  const members = props.members;
  const presence = props.presence;
  const onBack = props.onBack;
  const onOpenMembers = props.onOpenMembers;
  const onOpenSearch = props.onOpenSearch;
  const onClearChat = props.onClearChat;
  const onDeleteConversation = props.onDeleteConversation;
  const currentUserId = props.currentUserId;

  const [menuOpen, setMenuOpen] = useState(false);
  const [blocked, setBlocked] = useState(null);

  const isDirect = conversation && conversation.type === "direct";
  const isGroupOrChannel = conversation && (conversation.type === "group" || conversation.type === "channel");

  useState(() => {
    if (isDirect && otherUser && currentUserId) {
      fetchIsBlocked(currentUserId, otherUser.id).then(setBlocked).catch(() => setBlocked(false));
    }
  });

  const toggleBlock = async () => {
    if (!otherUser || !currentUserId) return;
    const next = !blocked;
    setBlocked(next);
    setMenuOpen(false);
    try {
      if (next) await blockUser(currentUserId, otherUser.id);
      else await unblockUser(currentUserId, otherUser.id);
    } catch (e) {
      setBlocked(!next);
    }
  };

  function getSubtitle() {
    if (isDirect && otherUser) {
      if (blocked) return "مسدود شده";
      const online = presence.isOnline(otherUser.id);
      if (online) return "آنلاین";
      return "آخرین بازدید " + formatLastSeen(presence.getLastSeen(otherUser.id));
    }
    if (isGroupOrChannel) {
      const onlineCount = members.filter(function (m) { return presence.isOnline(m.user_id); }).length;
      var text = members.length + " عضو";
      if (onlineCount > 0) text = text + " · " + onlineCount + " آنلاین";
      return text;
    }
    return "";
  }

  const subtitle = getSubtitle();
  const avatarUrl = isDirect ? (otherUser && otherUser.avatar_url) : (conversation && conversation.avatar_url);

  return (
    <div
      style={{
        display: "flex", alignItems: "center", justifyContent: "space-between",
        paddingBottom: 14, marginBottom: 14, borderBottom: "1px solid rgba(197,3,55,0.2)",
      }}
    >
      <div style={{ display: "flex", alignItems: "center", gap: 10, minWidth: 0 }}>
        <button data-native-back="true" className="btn-ghost" style={{ padding: "7px 11px", flexShrink: 0 }} onClick={onBack}>→</button>

        <div
          style={{ display: "flex", alignItems: "center", gap: 9, cursor: isGroupOrChannel ? "pointer" : "default", minWidth: 0 }}
          onClick={isGroupOrChannel ? onOpenMembers : undefined}
        >
          <div
            style={{
              width: 36, height: 36, borderRadius: "50%", flexShrink: 0, overflow: "hidden",
              background: "linear-gradient(155deg, #26232C, #0B0A0D)",
              border: "1px solid rgba(197,3,55,0.3)",
              display: "flex", alignItems: "center", justifyContent: "center",
            }}
          >
            {avatarUrl ? (
              <img loading="lazy" decoding="async" src={avatarUrl} alt="" style={{ width: "100%", height: "100%", objectFit: "cover" }} />
            ) : (
              <span style={{ fontSize: 15 }}>
                {isGroupOrChannel ? (conversation.type === "channel" ? "📣" : "👥") : "👤"}
              </span>
            )}
          </div>

          <div style={{ minWidth: 0 }}>
            <div style={{ display: "flex", alignItems: "center", gap: 6, minWidth: 0 }}>
              {isDirect && otherUser && !blocked && <OnlineStatus isOnline={presence.isOnline(otherUser.id)} size={8} />}
              <div style={{ fontWeight: 700, fontSize: 14.5, color: "#F2ECDD", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
                {title}
              </div>
            </div>
            {subtitle && <div style={{ fontSize: 11.5, color: blocked ? "#E5484D" : "#5E5748", marginTop: 1 }}>{subtitle}</div>}
          </div>
        </div>
      </div>

      <div style={{ display: "flex", gap: 6, flexShrink: 0 }}>
        <button className="btn-ghost" style={{ padding: "7px 11px" }} onClick={onOpenSearch} title="جستجوی پیام">🔍</button>
        {isGroupOrChannel && (
          <button className="btn-ghost" style={{ padding: "7px 11px" }} onClick={onOpenMembers} title="اعضا">👥</button>
        )}

        {isDirect && (
          <div style={{ position: "relative" }}>
            <button className="btn-ghost" style={{ padding: "7px 11px" }} onClick={() => setMenuOpen((o) => !o)} title="بیشتر">⋮</button>
            {menuOpen && (
              <>
                <div onClick={() => setMenuOpen(false)} style={{ position: "fixed", inset: 0, zIndex: 15 }} />
                <div
                  style={{
                    position: "absolute", top: "110%", left: 0, zIndex: 20, minWidth: 200, overflow: "hidden",
                    background: "linear-gradient(160deg, #26232C, #141318)",
                    border: "1px solid rgba(197,3,55,0.3)", borderRadius: 10,
                    boxShadow: "0 20px 40px -14px rgba(0,0,0,0.85)",
                  }}
                >
                  <div onClick={() => { setMenuOpen(false); onClearChat && onClearChat(); }} style={{ padding: "12px 14px", fontSize: 13, cursor: "pointer", color: "#E7E1D2" }}>
                    پاک کردن پیام‌ها (فقط برای من)
                  </div>
                  <div onClick={toggleBlock} style={{ padding: "12px 14px", fontSize: 13, cursor: "pointer", color: blocked ? "#94A3B8" : "#E5484D", borderTop: "1px solid rgba(197,3,55,0.15)" }}>
                    {blocked ? "رفع مسدودیت" : "مسدود کردن این کاربر"}
                  </div>
                  <div onClick={() => { setMenuOpen(false); onDeleteConversation && onDeleteConversation(); }} style={{ padding: "12px 14px", fontSize: 13, cursor: "pointer", color: "#E5484D", borderTop: "1px solid rgba(197,3,55,0.15)" }}>
                    حذف گفتگو
                  </div>
                </div>
              </>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
