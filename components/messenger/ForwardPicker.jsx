"use client";
import { useChats } from "../../hooks/useChats";

const GOLD_LIGHT = "#FF3D63";
const GOLD = "#C50337";

export default function ForwardPicker({ profile, onPick, onClose }) {
  const { pinned, active, loading } = useChats(profile.id);
  const list = [...pinned, ...active];

  const typeLabel = (t) => (t === "direct" ? "پیام خصوصی" : t === "group" ? "گروه" : "کانال");

  return (
    <>
      <div onClick={onClose} style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,0.6)", zIndex: 60 }} />
      <div
        style={{
          position: "fixed", bottom: 0, left: 0, right: 0, zIndex: 61,
          background: "linear-gradient(160deg, #1D1B22, #0B0A0D)",
          border: "1px solid rgba(197,3,55,0.3)", borderBottom: "none",
          borderRadius: "16px 16px 0 0", padding: "18px 16px 26px",
          maxHeight: "70vh", overflowY: "auto",
          boxShadow: "0 -20px 50px -20px rgba(0,0,0,0.9)",
        }}
      >
        <div style={{ fontSize: 14, fontWeight: 700, marginBottom: 14, textAlign: "center", color: GOLD_LIGHT }}>
          فوروارد به...
        </div>

        {loading && <div style={{ color: "#8C8474", fontSize: 13, textAlign: "center" }}>در حال بارگذاری...</div>}
        {!loading && list.length === 0 && (
          <div style={{ color: "#5E5748", fontSize: 13, textAlign: "center" }}>گفتگویی برای فوروارد وجود ندارد.</div>
        )}

        {list.map((chat) => (
          <div
            key={chat.id}
            onClick={() => onPick(chat.id)}
            className="pressable"
            style={{
              display: "flex", justifyContent: "space-between", alignItems: "center", cursor: "pointer",
              padding: "11px 12px", borderRadius: 9, marginBottom: 6,
              background: "#141318", border: "1px solid rgba(197,3,55,0.14)",
            }}
          >
            <span style={{ fontSize: 13.5, color: "#F2ECDD" }}>{chat.displayName}</span>
            <span
              style={{
                fontSize: 10.5, color: GOLD_LIGHT, background: "rgba(197,3,55,0.15)",
                border: "1px solid rgba(197,3,55,0.35)", borderRadius: 4, padding: "2px 7px",
              }}
            >
              {typeLabel(chat.type)}
            </span>
          </div>
        ))}

        <button className="btn-ghost" style={{ width: "100%", marginTop: 10 }} onClick={onClose}>
          انصراف
        </button>
      </div>
    </>
  );
}
