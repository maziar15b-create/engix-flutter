"use client";
import { useState, useEffect } from "react";
import { ChevronRight, Search } from "lucide-react";
import ChatsList from "./ChatsList";
import ContactsView from "./ContactsView";
import NewGroupView from "./NewGroupView";
import ThreadView from "./ThreadView";

const GOLD_LIGHT = "#FF3D63";
const GOLD = "#C50337";

export default function MessengerPanel({ profile, presence, onThreadOpenChange, onExit, onOpenProfile }) {
  const [view, setView] = useState("chats");
  const [activeConversationId, setActiveConversationId] = useState(null);

  useEffect(() => {
    if (onThreadOpenChange) onThreadOpenChange(view === "thread");
  }, [view, onThreadOpenChange]);

  const openThread = (conversationId) => {
    setActiveConversationId(conversationId);
    setView("thread");
  };

  const closeThread = () => {
    setActiveConversationId(null);
    setView("chats");
  };

  if (view === "newGroup") {
    return (
      <NewGroupView
        profile={profile}
        onCancel={() => setView("contacts")}
        onCreated={(conversationId) => openThread(conversationId)}
      />
    );
  }

  const isThread = view === "thread" && !!activeConversationId;

  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%", position: "relative" }}>
      {/* ===== لیست گفتگو / مخاطبین — همیشه mount می‌ماند، حتی وقتی یک چت
          خاص باز است. فقط با display مخفی/نمایان می‌شود، تا برگشت به لیست
          نیازی به لود مجدد از سرور نداشته باشد. ===== */}
      <div style={{ display: isThread ? "none" : "flex", flexDirection: "column", height: "100%" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10, padding: "14px 0 10px", flexShrink: 0 }}>
          {onExit && (
            <button
              onClick={onExit}
              className="pressable"
              aria-label="بازگشت به خانه"
              style={{
                width: 34, height: 34, borderRadius: "50%", flexShrink: 0,
                background: "linear-gradient(160deg, #1D1B22, #141318)",
                border: "1px solid rgba(197,3,55,0.3)",
                display: "flex", alignItems: "center", justifyContent: "center",
                color: GOLD_LIGHT, cursor: "pointer",
              }}
            >
              <ChevronRight size={19} />
            </button>
          )}
          <div style={{ fontSize: 17, fontWeight: 800, color: "#F2ECDD", flex: 1 }}>پیام‌رسان</div>
          <button
            className="pressable"
            aria-label="جستجو"
            style={{
              width: 34, height: 34, borderRadius: "50%", flexShrink: 0,
              background: "linear-gradient(160deg, #1D1B22, #141318)",
              border: "1px solid rgba(197,3,55,0.3)",
              display: "flex", alignItems: "center", justifyContent: "center",
              color: "#8C8474", cursor: "pointer",
            }}
          >
            <Search size={16} />
          </button>
        </div>

        <div style={{ display: "flex", gap: 6, marginBottom: 12, flexShrink: 0 }}>
          {[["chats", "گفتگوها"], ["contacts", "مخاطبین"]].map(([key, label]) => (
            <div
              key={key}
              onClick={() => setView(key)}
              className="pressable"
              style={{
                fontSize: 12.5, padding: "8px 16px", borderRadius: 9, cursor: "pointer",
                background: view === key ? "linear-gradient(135deg, rgba(255,61,99,0.18), rgba(122,2,36,0.24))" : "#141318",
                border: view === key ? `1px solid ${GOLD}` : "1px solid rgba(255,255,255,0.1)",
                color: view === key ? GOLD_LIGHT : "#8C8474",
                fontWeight: view === key ? 700 : 500,
              }}
            >
              {label}
            </div>
          ))}
        </div>

        <div style={{ flex: 1, overflowY: "auto", minHeight: 0 }}>
          {/* هر دو همیشه mount هستن، فقط یکی نمایش داده میشه — چون سبک‌اند
              (فقط لیست چت‌ها و مخاطبین)، هزینه‌ی حافظه‌ی اضافه ناچیزه */}
          <div style={{ display: view === "chats" ? "block" : "none" }}>
            <ChatsList profile={profile} presence={presence} onOpenThread={openThread} />
          </div>
          <div style={{ display: view === "contacts" ? "block" : "none" }}>
            <ContactsView
              profile={profile}
              onStartDirectChat={(conversationId) => openThread(conversationId)}
              onNewGroup={() => setView("newGroup")}
            />
          </div>
        </div>
      </div>

      {/* ===== گفتگوی باز — روی لیست به‌صورت overlay نمایش داده می‌شود =====
          نکته: prop مربوط به key عمداً روی activeConversationId ست شده تا
          هر بار که گفتگو عوض می‌شود یا بسته می‌شود، React کل ThreadView را
          کاملاً unmount/mount کند (نه فقط آپدیت)، و از باقی‌ماندن هر state
          یا محتوای قدیمی (از جمله محتوای portal شده) جلوگیری شود. */}
      {isThread && (
        <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column" }}>
          <ThreadView
            key={activeConversationId}
            profile={profile}
            conversationId={activeConversationId}
            presence={presence}
            onBack={closeThread}
            onOpenProfile={onOpenProfile}
          />
        </div>
      )}
    </div>
  );
}
