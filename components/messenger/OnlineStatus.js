"use client";

/**
 * Small colored dot indicating online/offline state. Reusable in
 * ChatsList (next to a direct chat name), ChatHeader (thread top bar),
 * and MembersPanel (each member row).
 */
export default function OnlineStatus({ isOnline, size = 10, showLabel = false, lastSeenLabel = null }) {
  const dot = (
    <span
      style={{
        display: "inline-block",
        width: size,
        height: size,
        borderRadius: "50%",
        background: isOnline ? "#22C55E" : "#3F4E63",
        flexShrink: 0,
      }}
    />
  );

  if (!showLabel) return dot;

  return (
    <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
      {dot}
      <span style={{ fontSize: 12, color: isOnline ? "#22C55E" : "#6B7F99" }}>
        {isOnline ? "آنلاین" : lastSeenLabel || "آفلاین"}
      </span>
    </div>
  );
}
