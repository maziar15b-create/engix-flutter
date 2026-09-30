"use client";
import { useState, useCallback } from "react";
import { searchMessagesInConversation } from "../../services/messengerService";

/**
 * Search messages within the currently open conversation. Simple
 * query-and-list UI — tapping a result closes the panel and returns
 * to the thread (jump-to-message scrolling can be added later once
 * MessageList exposes a scroll-to-id API).
 */
export default function SearchPanel({ conversationId, onBack, onJumpToMessage }) {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const runSearch = useCallback(async () => {
    const trimmed = query.trim();
    if (!trimmed) {
      setResults(null);
      return;
    }
    setLoading(true);
    setError("");
    try {
      const data = await searchMessagesInConversation(conversationId, trimmed);
      setResults(data);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, [conversationId, query]);

  const handleKeyDown = (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      runSearch();
    }
  };

  const formatDate = (iso) =>
    new Date(iso).toLocaleString("fa-IR", { dateStyle: "short", timeStyle: "short" });

  return (
    <div>
      <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 18 }}>
        <button data-native-back="true" className="btn-ghost" style={{ padding: "6px 12px" }} onClick={onBack}>
          ←
        </button>
        <div className="section-title" style={{ marginBottom: 0 }}>
          جستجوی پیام
        </div>
      </div>

      <div style={{ display: "flex", gap: 8, marginBottom: 16 }}>
        <input
          className="field-input"
          placeholder="متن پیام را جستجو کنید..."
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={handleKeyDown}
          style={{ flex: 1 }}
          autoFocus
        />
        <button className="btn-primary" onClick={runSearch} disabled={loading}>
          {loading ? "..." : "جستجو"}
        </button>
      </div>

      {error && <div className="error-text">{error}</div>}

      {results === null && !loading && (
        <div style={{ color: "#6B7F99", fontSize: 13 }}>
          عبارتی وارد کنید تا در پیام‌های این گفتگو جستجو شود.
        </div>
      )}

      {results && results.length === 0 && (
        <div style={{ color: "#6B7F99", fontSize: 13 }}>نتیجه‌ای پیدا نشد.</div>
      )}

      {results &&
        results.map((msg) => (
          <div
            key={msg.id}
            className="list-row"
            onClick={() => onJumpToMessage(msg.id)}
            style={{ marginBottom: 8 }}
          >
            <div style={{ fontSize: 13, marginBottom: 4, whiteSpace: "pre-wrap", wordBreak: "break-word" }}>
              {highlightMatch(msg.content, query)}
            </div>
            <div style={{ fontSize: 11, color: "#6B7F99" }}>{formatDate(msg.created_at)}</div>
          </div>
        ))}
    </div>
  );
}

function highlightMatch(content, query) {
  if (!content || !query) return content;
  const idx = content.toLowerCase().indexOf(query.toLowerCase());
  if (idx === -1) return content;
  return (
    <>
      {content.slice(0, idx)}
      <span style={{ background: "rgba(255,107,53,0.35)", borderRadius: 2 }}>
        {content.slice(idx, idx + query.length)}
      </span>
      {content.slice(idx + query.length)}
    </>
  );
}
