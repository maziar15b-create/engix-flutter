"use client";
import { useState, useMemo, useEffect, useRef } from "react";
import { Reply, Forward, Pencil, Trash2 } from "lucide-react";

const GOLD_LIGHT = "#FF3D63";

/**
 * لیست کامل پیام‌های یک گفتگو: اسکرول، دکمه‌ی «بارگذاری بیشتر»، نشانگر
 * تایپ‌کردن، و رندر هر پیام (متن/عکس/فایل/صوت) به همراه منوی پاسخ/فوروارد/
 * ویرایش/حذف.
 *
 * نکته: پیش از این، این فایل به‌اشتباه فقط کد رندر یک «پیام تکی» را داشت
 * (با props مفرد مثل message به‌جای messages)، درحالی‌که ThreadView.js این
 * کامپوننت را با props جمع (messages, loading, hasMore, ...) صدا می‌زد.
 * نتیجه این بود که در همان اولین رندر، «message» تعریف‌نشده بود و خط
 * message.content بلافاصله کرش می‌کرد — همان اروری که با باز کردن هر
 * گفتگویی رخ می‌داد. این فایل اکنون واقعاً یک «لیست» است.
 */
export default function MessageList({
  messages,
  loading,
  loadingMore,
  hasMore,
  onLoadMore,
  currentUserId,
  members,
  showSenderInfo,
  readMessageIds,
  typingLabel,
  onReply,
  onEdit,
  onDelete,
  onForward,
}) {
  const list = messages || [];
  const bottomRef = useRef(null);
  const containerRef = useRef(null);
  const prevLenRef = useRef(0);

  const memberById = useMemo(() => {
    const map = {};
    (members || []).forEach((m) => {
      if (m && m.user_id) map[m.user_id] = m.profiles || null;
    });
    return map;
  }, [members]);

  const messageById = useMemo(() => {
    const map = {};
    list.forEach((m) => { if (m && m.id) map[m.id] = m; });
    return map;
  }, [list]);

  // اسکرول خودکار به پایین وقتی پیام جدیدی اضافه می‌شود (نه وقتی صفحه‌ی
  // قدیمی‌تر از بالا لود می‌شود)
  useEffect(() => {
    if (list.length > prevLenRef.current) {
      bottomRef.current?.scrollIntoView({ behavior: "smooth", block: "end" });
    }
    prevLenRef.current = list.length;
  }, [list.length]);

  return (
    <div
      ref={containerRef}
      style={{ flex: 1, minHeight: 0, overflowY: "auto", display: "flex", flexDirection: "column", padding: "12px 10px" }}
    >
      {hasMore && (
        <div style={{ textAlign: "center", marginBottom: 10 }}>
          <button
            className="btn-ghost"
            style={{ padding: "6px 14px", fontSize: 12 }}
            onClick={onLoadMore}
            disabled={loadingMore}
          >
            {loadingMore ? "در حال بارگذاری…" : "پیام‌های قدیمی‌تر"}
          </button>
        </div>
      )}

      {loading && list.length === 0 && (
        <div style={{ textAlign: "center", color: "#6B7F99", fontSize: 13, marginTop: 30 }}>
          در حال بارگذاری پیام‌ها…
        </div>
      )}

      {!loading && list.length === 0 && (
        <div style={{ textAlign: "center", color: "#6B7F99", fontSize: 13, marginTop: 30 }}>
          هنوز پیامی ارسال نشده است
        </div>
      )}

      {list.map((message) => {
        if (!message) return null;
        const isOwn = message.sender_id === currentUserId;
        const senderProfile = memberById[message.sender_id];
        const replyToMessage = message.reply_to ? messageById[message.reply_to] : null;
        const isRead = isOwn && readMessageIds ? readMessageIds.has(message.id) : false;

        return (
          <MessageBubble
            key={message.id}
            message={message}
            isOwn={isOwn}
            isRead={isRead}
            senderName={showSenderInfo && !isOwn ? (senderProfile?.name || "") : null}
            senderAvatar={showSenderInfo && !isOwn ? (senderProfile?.avatar_url || null) : null}
            replyToMessage={replyToMessage}
            onReply={() => onReply && onReply(message)}
            onEdit={(newContent) => onEdit && onEdit(message.id, newContent)}
            onDelete={() => onDelete && onDelete(message.id)}
            onForward={() => onForward && onForward(message)}
          />
        );
      })}

      {typingLabel ? (
        <div style={{ fontSize: 11.5, color: GOLD_LIGHT, marginTop: 6, marginRight: 4 }}>
          {typingLabel} در حال تایپ است…
        </div>
      ) : null}

      <div ref={bottomRef} />
    </div>
  );
}

function MessageBubble({
  message,
  isOwn,
  isRead,
  senderName,
  senderAvatar,
  replyToMessage,
  onReply,
  onEdit,
  onDelete,
  onForward,
}) {
  if (!message) return null; // جلوگیری از کرش وقتی پیام نامعتبر/ناقص باشد

  const [menuOpen, setMenuOpen] = useState(false);
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(message.content || "");

  const time = new Date(message.created_at).toLocaleTimeString("fa-IR", {
    hour: "2-digit",
    minute: "2-digit",
  });

  const bubbleStyle = {
    alignSelf: isOwn ? "flex-end" : "flex-start",
    maxWidth: "78%",
    background: isOwn ? "#C50337" : "#101826",
    color: isOwn ? "#fff" : "#E5EDF5",
    borderRadius: 14,
    padding: "8px 12px",
    marginBottom: 6,
    position: "relative",
  };

  const saveEdit = () => {
    const trimmed = draft.trim();
    if (trimmed && trimmed !== message.content) {
      onEdit(trimmed);
    }
    setEditing(false);
  };

  if (message.is_deleted) {
    return (
      <div style={{ ...bubbleStyle, fontStyle: "italic", color: "#6B7F99", background: "transparent", border: "1px solid rgba(255,255,255,0.1)" }}>
        این پیام حذف شد
      </div>
    );
  }

  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: isOwn ? "flex-end" : "flex-start" }}>
      {!isOwn && senderName && (
        <div style={{ display: "flex", alignItems: "center", gap: 5, marginBottom: 3, marginRight: 4 }}>
          {senderAvatar ? (
            <img loading="lazy" decoding="async"
              src={senderAvatar}
              alt=""
              style={{ width: 18, height: 18, borderRadius: "50%", objectFit: "cover", flexShrink: 0 }}
            />
          ) : (
            <span
              style={{
                width: 18, height: 18, borderRadius: "50%", background: "#26232C", flexShrink: 0,
                display: "inline-flex", alignItems: "center", justifyContent: "center",
                fontSize: 9, color: "#94A3B8",
              }}
            >
              {senderName.charAt(0)}
            </span>
          )}
          <span style={{ fontSize: 11, color: "#94A3B8" }}>{senderName}</span>
        </div>
      )}

      <div style={bubbleStyle} onDoubleClick={() => setMenuOpen((v) => !v)}>
        {message.forwarded_from && (
          <div style={{ fontSize: 11, opacity: 0.75, marginBottom: 4 }}>↪ فوروارد شده</div>
        )}

        {replyToMessage ? (
          <div
            style={{
              borderRight: isOwn ? "2px solid rgba(255,255,255,0.6)" : "2px solid #C50337",
              paddingRight: 8,
              marginBottom: 6,
              fontSize: 12,
              opacity: 0.8,
              maxHeight: 40,
              overflow: "hidden",
            }}
          >
            {replyToMessage.content || attachmentLabel(replyToMessage.type)}
          </div>
        ) : message.reply_to ? (
          <div style={{ fontSize: 11, opacity: 0.6, marginBottom: 6 }}>در پاسخ به پیامی قدیمی‌تر</div>
        ) : null}

        {editing ? (
          <div>
            <textarea
              className="field-input"
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              style={{ width: "100%", minHeight: 60, color: "#111", marginBottom: 6 }}
            />
            <div style={{ display: "flex", gap: 6 }}>
              <button className="btn-primary" style={{ padding: "4px 10px", fontSize: 12 }} onClick={saveEdit}>
                ذخیره
              </button>
              <button className="btn-ghost" style={{ padding: "4px 10px", fontSize: 12 }} onClick={() => setEditing(false)}>
                لغو
              </button>
            </div>
          </div>
        ) : (
          <MessageContent message={message} />
        )}

        <div style={{ display: "flex", alignItems: "center", gap: 4, marginTop: 4, justifyContent: "flex-end" }}>
          {message.is_edited && <span style={{ fontSize: 10, opacity: 0.65 }}>ویرایش‌شده</span>}
          <span style={{ fontSize: 10, opacity: 0.65 }}>{time}</span>
          {isOwn && (
            <svg width="14" height="10" viewBox="0 0 16 11" fill="none" style={{ flexShrink: 0 }}>
              {/* یک تیک = ارسال شده؛ دو تیک آبی فقط وقتی نمایش داده می‌شود که
                  طرف مقابل واقعاً پیام را خوانده باشد (isRead) */}
              <path
                d="M1 5.5 4 8.5 9 2"
                stroke={isRead ? "#4FC3F7" : "currentColor"}
                strokeOpacity={isRead ? 1 : 0.75}
                strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"
              />
              {isRead && (
                <path
                  d="M6 5.5 9 8.5 15 1.5"
                  stroke="#4FC3F7"
                  strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"
                />
              )}
            </svg>
          )}
        </div>
      </div>

      {menuOpen && !editing && (
        <div
          style={{
            display: "flex",
            gap: 4,
            marginTop: 4,
            background: "#101826",
            border: "1px solid rgba(255,255,255,0.1)",
            borderRadius: 8, padding: 4,
          }}
        >
          <MenuBtn icon={Reply} label="پاسخ" onClick={() => { onReply(); setMenuOpen(false); }} />
          <MenuBtn icon={Forward} label="فوروارد" onClick={() => { onForward(); setMenuOpen(false); }} />
          {isOwn && message.type === "text" && (
            <MenuBtn icon={Pencil} label="ویرایش" onClick={() => { setEditing(true); setMenuOpen(false); }} />
          )}
          {isOwn && (
            <MenuBtn
              icon={Trash2}
              label="حذف"
              danger
              onClick={() => {
                onDelete();
                setMenuOpen(false);
              }}
            />
          )}
        </div>
      )}
    </div>
  );
}

function MessageContent({ message }) {
  switch (message.type) {
    case "image":
      return (
        <img loading="lazy" decoding="async"
          src={message.file_url}
          alt={message.file_meta?.name || "image"}
          style={{ maxWidth: "100%", borderRadius: 8, display: "block" }}
        />
      );
    case "pdf":
    case "word":
    case "excel":
      return (
        <a
          href={message.file_url}
          target="_blank"
          rel="noopener noreferrer"
          style={{ display: "flex", alignItems: "center", gap: 8, color: "inherit", textDecoration: "none" }}
        >
          <span style={{ fontSize: 20 }}>{message.type === "pdf" ? "📄" : message.type === "excel" ? "📊" : "📝"}</span>
          <span style={{ fontSize: 13, textDecoration: "underline" }}>
            {message.file_meta?.name || "دانلود فایل"}
          </span>
        </a>
      );
    case "voice":
      return <audio controls src={message.file_url} style={{ maxWidth: 220 }} />;
    default:
      return <div className="selectable-text" style={{ fontSize: 13.5, whiteSpace: "pre-wrap", wordBreak: "break-word" }}>{message.content}</div>;
  }
}

function attachmentLabel(type) {
  if (type === "image") return "📷 عکس";
  if (type === "pdf") return "📄 PDF";
  if (type === "word") return "📝 فایل Word";
  if (type === "excel") return "📊 فایل اکسل";
  if (type === "voice") return "🎙 پیام صوتی";
  return "";
}

function MenuBtn({ icon: Icon, label, onClick, danger }) {
  return (
    <button
      className="btn-ghost"
      title={label}
      aria-label={label}
      style={{
        display: "flex", alignItems: "center", justifyContent: "center",
        padding: 8, color: danger ? "#F87171" : undefined,
      }}
      onClick={onClick}
    >
      {Icon ? <Icon size={16} /> : label}
    </button>
  );
}
